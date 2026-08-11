-- Clawback path for refunded credit packs.
--
-- Google refunds are reported by RevenueCat as CANCELLATION events long after
-- the purchase, by which point the credits may already be spent. We reverse
-- what we can and eat the rest — see the clamp in revoke_credits.

alter table public.credit_transactions
  drop constraint if exists credit_transactions_reason_check;

alter table public.credit_transactions
  add constraint credit_transactions_reason_check check (
    reason in ('signup_grant', 'tryon_spend', 'tryon_refund',
               'purchase', 'purchase_revoked', 'admin_adjust')
  );

-- Reverses the grant recorded for `p_ref` (the store transaction id). Safe to
-- call for an unknown ref and safe to call twice.
create or replace function public.revoke_credits(
  p_user_id uuid,
  p_ref     text
) returns integer
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_granted integer;
  v_balance integer;
begin
  -- How many credits this transaction actually bought. Reading it back from the
  -- ledger means a later change to the product→credits map cannot cause us to
  -- claw back a different number than we gave.
  select delta into v_granted
    from public.credit_transactions
   where user_id = p_user_id
     and reason  = 'purchase'
     and ref     = p_ref;

  if v_granted is null then
    select balance into v_balance
      from public.user_credits where user_id = p_user_id;
    return coalesce(v_balance, 0);
  end if;

  insert into public.credit_transactions (user_id, delta, reason, ref)
  values (p_user_id, -v_granted, 'purchase_revoked', p_ref)
  on conflict do nothing;

  if not found then
    select balance into v_balance
      from public.user_credits where user_id = p_user_id;
    return coalesce(v_balance, 0);
  end if;

  -- Clamped at zero. If the user already spent the credits we have already paid
  -- Replicate for that inference; chasing a negative balance would just block
  -- them from ever using the app again. The loss is capped at one pack.
  update public.user_credits
     set balance    = greatest(balance - v_granted, 0),
         updated_at = now()
   where user_id = p_user_id
  returning balance into v_balance;

  return coalesce(v_balance, 0);
end;
$$;

revoke execute on function public.revoke_credits(uuid, text) from public, anon, authenticated;
grant  execute on function public.revoke_credits(uuid, text) to service_role;
