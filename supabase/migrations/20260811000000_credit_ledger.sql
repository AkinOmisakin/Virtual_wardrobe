-- Credit ledger for paid AI features (currently try-on).
--
-- Design notes:
--   * `user_credits` is the fast-read balance; `credit_transactions` is the
--     append-only audit trail. The balance is derived state kept in sync by the
--     functions below — never written directly by clients.
--   * RLS grants SELECT to owners and nothing else. Every mutation goes through
--     a SECURITY DEFINER function called by the edge function with the service
--     role key, so a compromised client cannot mint credits.
--   * Refunds are idempotent via a unique index on (user_id, reason, ref): the
--     client polls a failed prediction repeatedly and must only ever be
--     refunded once.

-- Free credits handed to every new account. Each credit buys one garment
-- application, and a typical outfit is 2 garments, so 3 is roughly one full
-- outfit plus a retry. Raising this raises cost-per-signup linearly.
-- Keep in sync with SIGNUP_GRANT in supabase/functions/try-on/index.ts.

create table if not exists public.user_credits (
  user_id          uuid primary key references auth.users (id) on delete cascade,
  balance          integer     not null default 0 check (balance >= 0),
  lifetime_granted integer     not null default 0,
  lifetime_spent   integer     not null default 0,
  updated_at       timestamptz not null default now()
);

create table if not exists public.credit_transactions (
  id         bigint generated always as identity primary key,
  user_id    uuid        not null references auth.users (id) on delete cascade,
  delta      integer     not null,
  reason     text        not null check (
                 reason in ('signup_grant', 'tryon_spend', 'tryon_refund',
                            'purchase', 'admin_adjust')),
  -- Idempotency key. For try-on rows this is the tryon_jobs.id; for purchases
  -- it is the store purchase token.
  ref        text,
  created_at timestamptz not null default now()
);

create index if not exists credit_transactions_user_time_idx
  on public.credit_transactions (user_id, created_at desc);

-- One transaction per (user, reason, ref). This is what makes refunds and
-- purchase grants safe to retry.
create unique index if not exists credit_transactions_dedupe_idx
  on public.credit_transactions (user_id, reason, ref)
  where ref is not null;

-- One row per garment application. Also the join table that lets `poll` prove a
-- prediction belongs to the caller before refunding or returning its output.
create table if not exists public.tryon_jobs (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid        not null references auth.users (id) on delete cascade,
  prediction_id   text unique,
  status          text        not null default 'pending',
  credits_charged integer     not null default 1,
  refunded        boolean     not null default false,
  created_at      timestamptz not null default now(),
  completed_at    timestamptz
);

create index if not exists tryon_jobs_user_time_idx
  on public.tryon_jobs (user_id, created_at desc);

-- Supports the global daily spend cap counted in the edge function.
create index if not exists tryon_jobs_created_at_idx
  on public.tryon_jobs (created_at desc);

-- ── row level security ──────────────────────────────────────────────────────
-- SELECT-only for owners. The absence of INSERT/UPDATE/DELETE policies means
-- those are denied for everyone except the service role, which bypasses RLS.

alter table public.user_credits        enable row level security;
alter table public.credit_transactions enable row level security;
alter table public.tryon_jobs          enable row level security;

drop policy if exists "own credits readable" on public.user_credits;
create policy "own credits readable" on public.user_credits
  for select using (auth.uid() = user_id);

drop policy if exists "own transactions readable" on public.credit_transactions;
create policy "own transactions readable" on public.credit_transactions
  for select using (auth.uid() = user_id);

drop policy if exists "own jobs readable" on public.tryon_jobs;
create policy "own jobs readable" on public.tryon_jobs
  for select using (auth.uid() = user_id);

-- ── mutations ───────────────────────────────────────────────────────────────

-- Atomically debits `p_amount` credits. The `balance >= p_amount` predicate
-- lives in the UPDATE itself, so two concurrent spends can never both succeed
-- against the same last credit.
create or replace function public.spend_credit(
  p_user_id uuid,
  p_ref     text,
  p_amount  integer default 1
) returns integer
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_balance integer;
begin
  if p_amount <= 0 then
    raise exception 'amount_must_be_positive';
  end if;

  -- A user who predates this migration (or whose signup trigger failed) gets a
  -- zero-balance row here rather than a confusing "not found".
  insert into public.user_credits (user_id) values (p_user_id)
  on conflict (user_id) do nothing;

  update public.user_credits
     set balance        = balance - p_amount,
         lifetime_spent = lifetime_spent + p_amount,
         updated_at     = now()
   where user_id = p_user_id
     and balance >= p_amount
  returning balance into v_balance;

  if not found then
    raise exception 'insufficient_credits';
  end if;

  insert into public.credit_transactions (user_id, delta, reason, ref)
  values (p_user_id, -p_amount, 'tryon_spend', p_ref);

  return v_balance;
end;
$$;

-- Idempotent credit-back for a failed prediction. A second call for the same
-- ref hits the dedupe index, inserts nothing, and leaves the balance alone.
create or replace function public.refund_credit(
  p_user_id uuid,
  p_ref     text,
  p_amount  integer default 1
) returns integer
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_balance integer;
begin
  insert into public.credit_transactions (user_id, delta, reason, ref)
  values (p_user_id, p_amount, 'tryon_refund', p_ref)
  on conflict do nothing;

  if not found then
    select balance into v_balance
      from public.user_credits where user_id = p_user_id;
    return coalesce(v_balance, 0);
  end if;

  update public.user_credits
     set balance        = balance + p_amount,
         lifetime_spent = greatest(lifetime_spent - p_amount, 0),
         updated_at     = now()
   where user_id = p_user_id
  returning balance into v_balance;

  return coalesce(v_balance, 0);
end;
$$;

-- Used by the signup trigger and, later, by the store-purchase webhook. `p_ref`
-- makes purchase grants replay-safe against the dedupe index.
create or replace function public.grant_credits(
  p_user_id uuid,
  p_amount  integer,
  p_reason  text,
  p_ref     text default null
) returns integer
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_balance integer;
begin
  if p_amount <= 0 then
    raise exception 'amount_must_be_positive';
  end if;

  insert into public.user_credits (user_id) values (p_user_id)
  on conflict (user_id) do nothing;

  insert into public.credit_transactions (user_id, delta, reason, ref)
  values (p_user_id, p_amount, p_reason, p_ref)
  on conflict do nothing;

  if not found then
    select balance into v_balance
      from public.user_credits where user_id = p_user_id;
    return coalesce(v_balance, 0);
  end if;

  update public.user_credits
     set balance          = balance + p_amount,
         lifetime_granted = lifetime_granted + p_amount,
         updated_at       = now()
   where user_id = p_user_id
  returning balance into v_balance;

  return coalesce(v_balance, 0);
end;
$$;

-- Clients may read their balance but must never call the mutators directly.
revoke execute on function public.spend_credit(uuid, text, integer)          from public, anon, authenticated;
revoke execute on function public.refund_credit(uuid, text, integer)         from public, anon, authenticated;
revoke execute on function public.grant_credits(uuid, integer, text, text)   from public, anon, authenticated;
grant  execute on function public.spend_credit(uuid, text, integer)          to service_role;
grant  execute on function public.refund_credit(uuid, text, integer)         to service_role;
grant  execute on function public.grant_credits(uuid, integer, text, text)   to service_role;

-- ── signup grant ────────────────────────────────────────────────────────────

create or replace function public.handle_new_user_credits()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
begin
  perform public.grant_credits(new.id, 3, 'signup_grant', new.id::text);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_grant_credits on auth.users;
create trigger on_auth_user_created_grant_credits
  after insert on auth.users
  for each row execute function public.handle_new_user_credits();

-- Backfill accounts that existed before this migration with the same grant.
-- The dedupe index keeps this safe if the migration is ever re-run.
do $$
declare
  u record;
begin
  for u in select id from auth.users loop
    perform public.grant_credits(u.id, 3, 'signup_grant', u.id::text);
  end loop;
end;
$$;
