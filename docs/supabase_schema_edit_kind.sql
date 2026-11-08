-- Phase 5B cloud migration: replace `restored_from_commit_id` with
-- `kind` + `based_on_commit_id` (AGENTS.md Phase 5B, task 1).
--
-- Run ONCE in the Supabase dashboard before installing the Phase 5B build:
-- SQL Editor > New query > paste > Run.
--
-- Existing restore rows keep their link: `based_on_commit_id` is copied from
-- `restored_from_commit_id`, and their kind becomes 'restore'. Every other
-- commit is an upload. The script is safe to run twice.

alter table public.commits
  add column if not exists kind text not null default 'upload';
alter table public.commits
  add column if not exists based_on_commit_id bigint;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'commits'
      and column_name = 'restored_from_commit_id'
  ) then
    update public.commits
    set kind = 'restore',
        based_on_commit_id = restored_from_commit_id
    where restored_from_commit_id is not null;

    alter table public.commits drop column restored_from_commit_id;
  end if;
end $$;
