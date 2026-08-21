-- Account deletion, required by both Google Play and the App Store.
--
-- All row deletion happens here in one transaction rather than as a series of
-- PostgREST calls, so a failure part-way through cannot leave an account
-- half-erased. Storage objects and the auth user itself are handled by the
-- delete-account edge function, which calls this first.

create or replace function public.delete_account_data(p_user_id uuid)
  returns void
  language plpgsql
  security definer
  set search_path = public
as $$
begin
  -- Children before parents. Deleting rows that a cascade already removed is a
  -- no-op, so this is correct whether or not the FKs cascade.
  delete from public.outfit_items
   where outfit_id in (select id from public.outfits where user_id = p_user_id);

  delete from public.outfits            where user_id = p_user_id;
  delete from public.posts              where user_id = p_user_id;
  delete from public.clothing_items     where user_id = p_user_id;

  -- The ledger goes too. Erasure wins over keeping the audit trail: a refund
  -- arriving after deletion finds no purchase row and revoke_credits no-ops,
  -- which is the correct outcome for an account that no longer exists.
  delete from public.tryon_jobs         where user_id = p_user_id;
  delete from public.credit_transactions where user_id = p_user_id;
  delete from public.user_credits       where user_id = p_user_id;

  delete from public.profiles           where id = p_user_id;
end;
$$;

revoke execute on function public.delete_account_data(uuid) from public, anon, authenticated;
grant  execute on function public.delete_account_data(uuid) to service_role;
