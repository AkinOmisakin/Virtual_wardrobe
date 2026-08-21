-- Storage bucket for profile photos.
--
-- Public, unlike `user-models`. Avatars are shown wherever a user appears — the
-- home top bar, the profile card, anywhere a post is attributed — so signed
-- URLs would mean re-signing on every render and expiring inside cached image
-- widgets. Nothing private belongs here; the full-body try-on photo stays in
-- the private `user-models` bucket.
--
-- The app uploads to `<uid>/<timestamp>.<ext>` and deletes the previous file
-- afterwards, so a changed photo always gets a new URL. That is deliberate: a
-- fixed path would keep the URL identical and the CDN would go on serving the
-- old image.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880, -- 5 MB; the client already downscales to 1024px before upload
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Anyone may read. Only the owner may write, and only inside the folder named
-- after their own uid — the first path segment is the whole check, which is why
-- the client's path scheme starts with it.

drop policy if exists "avatars are publicly readable" on storage.objects;
create policy "avatars are publicly readable" on storage.objects
  for select
  using (bucket_id = 'avatars');

drop policy if exists "users upload own avatar" on storage.objects;
create policy "users upload own avatar" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users update own avatar" on storage.objects;
create policy "users update own avatar" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Delete matters more than it looks: replacing a photo prunes the old file, so
-- without this every change would leave the previous avatar behind forever.
drop policy if exists "users delete own avatar" on storage.objects;
create policy "users delete own avatar" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
