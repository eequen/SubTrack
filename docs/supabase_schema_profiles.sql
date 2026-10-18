-- Username profiles for SubTrack (AGENTS.md Phase 5, requested change).
--
-- Run this once in the Supabase SQL editor AFTER the base schema
-- (supabase_schema.sql). It is safe to run again (idempotent).
--
-- What it does:
--   1. Adds a `profiles` table mapping each auth user to a unique public
--      username (readable by anyone, because login-by-username must work
--      BEFORE a user is signed in; no secrets are stored here).
--   2. Adds a trigger so every NEW signup gets a profile row
--      automatically, from the `username` value the app passes during
--      sign-up (stored in user metadata).
--   3. Back-fills profile rows for accounts that already exist, using
--      their metadata username or, if absent, the prefix of their email.
--
-- The row for the user's own data is still protected by the existing
-- per-user policies; profiles only expose ids, usernames, and emails.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null,
  email text not null,
  created_at timestamptz not null default now()
);

create unique index if not exists profiles_username_unique
  on public.profiles (lower (username));

alter table public.profiles enable row level security;

-- Anyone (including a signed-out user) may look a username up so the
-- login screen can turn "name123" into the account it belongs to.
drop policy if exists "anyone can read profiles" on public.profiles;
create policy "anyone can read profiles"
  on public.profiles
  for select
  to anon, authenticated
  using (true);

-- New signups: copy the username the app passed in sign-up metadata.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, email)
  values (
    new.id,
    lower(coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'username'), ''),
      split_part(new.email, '@', 1)
    )),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();

-- Back-fill rows for the accounts that already exist. Skip username
-- collisions (two accounts cannot share a username; the later one falls
-- back to its email prefix would clash too, so it is simply skipped).
with candidates as (
  select
    u.id,
    lower(coalesce(
      nullif(btrim(u.raw_user_meta_data ->> 'username'), ''),
      split_part(u.email, '@', 1)
    )) as username,
    u.email
  from auth.users u
)
insert into public.profiles (id, username, email)
select c.id, c.username, c.email
from candidates c
where not exists (
  select 1 from public.profiles p
  where lower(p.username) = lower(c.username)
)
on conflict (id) do nothing;
