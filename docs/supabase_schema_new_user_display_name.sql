-- Step 2 for display names (AGENTS.md section 8, Phase 5A).
-- Run this once in the Supabase SQL editor AFTER
-- supabase_schema_display_name.sql. Safe to run again (idempotent).
--
-- display_name ran as a backfill earlier, but the signup trigger only
-- copied the username. This replaces the trigger function so every NEW
-- signup also receives the display name the app passes at sign-up
-- (falling back to the username default when it is missing).

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, email, display_name)
  values (
    new.id,
    lower(coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'username'), ''),
      split_part(new.email, '@', 1)
    )),
    new.email,
    coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''),
      lower(coalesce(
        nullif(btrim(new.raw_user_meta_data ->> 'username'), ''),
        split_part(new.email, '@', 1)
      ))
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- The ON_AUTH_USER_CREATED trigger from supabase_schema_profiles.sql
-- still fires this function; recreating it keeps things explicit.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();
