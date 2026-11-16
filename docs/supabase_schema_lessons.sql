-- SubTrack v5: subject lessons share the cloud activities table.
-- Run ONCE in the Supabase dashboard: SQL Editor > New query > paste > Run.
--
-- Flashcards stay local-only and are intentionally not added to Supabase.
-- Existing rows default to 'activity'; lessons are 'lesson'.

alter table public.activities
  add column if not exists kind text not null default 'activity';

-- Keep the original schema file in sync for new projects.
comment on column public.activities.kind is
  'activity or lesson; lessons are subject-level file folders';
