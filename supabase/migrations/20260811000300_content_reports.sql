-- In-app reporting for AI-generated content.
--
-- Google Play's generative-AI policy requires apps that generate content to let
-- users flag offensive output without leaving the app. Cher generates images of
-- people, so this applies to every try-on result even though the app has no
-- social feed and no user-to-user visibility.
--
-- Reports are write-only from the client's point of view: you can file one and
-- see your own, but never read anyone else's. Triage happens in the Supabase
-- dashboard with the service role.

create table if not exists public.content_reports (
  id           uuid primary key default gen_random_uuid(),
  reporter_id  uuid        not null references auth.users (id) on delete cascade,
  content_type text        not null check (content_type in ('tryon_result', 'post')),
  -- Post id, or the generated image URL for a try-on result. Also the dedupe
  -- key, so one user cannot file the same report repeatedly.
  content_ref  text        not null,
  content_url  text,
  reason       text        not null check (
                   reason in ('sexual', 'minor', 'violent',
                              'hateful', 'likeness', 'other')),
  details      text,
  status       text        not null default 'open' check (
                   status in ('open', 'reviewed', 'actioned', 'dismissed')),
  created_at   timestamptz not null default now()
);

-- Triage queue: oldest open reports first.
create index if not exists content_reports_open_idx
  on public.content_reports (created_at)
  where status = 'open';

create unique index if not exists content_reports_dedupe_idx
  on public.content_reports (reporter_id, content_ref);

alter table public.content_reports enable row level security;

-- Users may file reports as themselves and read back their own. No UPDATE or
-- DELETE policy exists, so a reporter cannot retract or alter a report and
-- cannot see how it was triaged.
drop policy if exists "file own reports" on public.content_reports;
create policy "file own reports" on public.content_reports
  for insert to authenticated
  with check (auth.uid() = reporter_id);

drop policy if exists "read own reports" on public.content_reports;
create policy "read own reports" on public.content_reports
  for select to authenticated
  using (auth.uid() = reporter_id);
