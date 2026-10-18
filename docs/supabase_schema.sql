-- SubTrack cloud schema (AGENTS.md section 9, Phase 5 tasks 3-4).
-- Run ONCE in the Supabase dashboard: SQL Editor > New query > paste > Run.
--
-- Every table mirrors the local drift table (same column names) and adds:
--   user_id  - the account the row belongs to (RLS enforces ownership)
--   id       - the row's id on the phone that backed it up (per-user unique)
-- Restoring inserts rows with these ids, so every reference keeps working.

create table public.semesters (
  user_id uuid not null references auth.users (id) on delete cascade,
  id bigint not null,
  term text not null,
  school_year text not null,
  start_date timestamptz not null,
  end_date timestamptz not null,
  created_at timestamptz not null,
  primary key (user_id, id)
);

create table public.subjects (
  user_id uuid not null references auth.users (id) on delete cascade,
  id bigint not null,
  semester_id bigint not null,
  name text not null,
  color bigint not null,
  icon text not null default '',
  is_archived boolean not null default false,
  created_at timestamptz not null,
  primary key (user_id, id)
);

create table public.activities (
  user_id uuid not null references auth.users (id) on delete cascade,
  id bigint not null,
  subject_id bigint not null,
  title text not null,
  notes text not null default '',
  deadline timestamptz,
  status text not null default 'draft',
  is_archived boolean not null default false,
  created_at timestamptz not null,
  primary key (user_id, id)
);

create table public.files (
  user_id uuid not null references auth.users (id) on delete cascade,
  id bigint not null,
  activity_id bigint not null,
  display_name text not null,
  current_commit_id bigint,
  created_at timestamptz not null,
  primary key (user_id, id)
);

create table public.commits (
  user_id uuid not null references auth.users (id) on delete cascade,
  id bigint not null,
  file_id bigint not null,
  version_no bigint not null,
  message text not null,
  blob_hash text not null,
  size_bytes bigint not null,
  mime_type text not null default '',
  restored_from_commit_id bigint,
  created_at timestamptz not null,
  primary key (user_id, id)
);

-- Row Level Security: each account only ever sees and writes its own rows
-- (AGENTS.md constraint 13 / section 13).
alter table public.semesters enable row level security;
alter table public.subjects enable row level security;
alter table public.activities enable row level security;
alter table public.files enable row level security;
alter table public.commits enable row level security;

create policy "semesters: own rows" on public.semesters
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "subjects: own rows" on public.subjects
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "activities: own rows" on public.activities
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "files: own rows" on public.files
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "commits: own rows" on public.commits
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Storage policies for the private `backups` bucket: an account may only
-- read, upload, or delete objects inside its own `user_id/` folder.
create policy "backups: read own folder" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'backups'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "backups: upload own folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'backups'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "backups: delete own folder" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'backups'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
