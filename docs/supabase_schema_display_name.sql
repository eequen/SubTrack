-- Display name for SubTrack profiles (AGENTS.md section 8, Phase 5A).
-- Run this once in the Supabase SQL editor AFTER
-- supabase_schema.sql and supabase_schema_profiles.sql.
-- Safe to run again (idempotent).
--
-- What it does:
--   1. Adds display_name to the profiles table, so the display name is
--      backed up to the cloud and survives Restore from cloud on a new
--      phone (the profile photo stays device-local on purpose).
--   2. Fills existing rows with their username as a starting display name
--      (each user can change it in the app later).
--   3. Lets a signed-in user update ONLY their own profile row.
--   4. Prevents changing the username, even from a client
--      (AGENTS.md section 8: the username cannot be changed after sign-up).

alter table public.profiles
  add column if not exists display_name text;

update public.profiles
set display_name = username
where display_name is null or display_name = '';

drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

create or replace function public.prevent_username_change()
returns trigger
language plpgsql
as $$
begin
  if lower(old.username) <> lower(new.username) then
    raise exception 'username cannot be changed';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_no_username_change on public.profiles;
create trigger profiles_no_username_change
  before update on public.profiles
  for each row
  execute function public.prevent_username_change();
