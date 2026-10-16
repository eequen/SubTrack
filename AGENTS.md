# SubTrack: Agent Workflow

Instructions for opencode (and any AI coding agent) working on this repo.
Read this whole file before doing anything. Follow the phases in order.

---

## 1. Project summary

**SubTrack** is an Android app (Flutter/Dart) that works like "Git for school work."

- A **semester** groups one term's subjects (for example, 1st Semester, SY 2026-2027).
- A **subject** is like a repository inside a semester.
- An **activity** is a subfolder inside a subject.
- A **file** lives in an activity. Each update is saved as a **commit** (message + timestamp).
- Students can view version history and **restore** any earlier version.
- The student **logs in first**, then **creates or chooses a semester**, then creates subjects, activities, and files.
- The app is **offline-first** after the first sign-in (the session is saved on the device). A student presses **Back up now** to push data to the cloud, and **Restore from cloud** on a new phone.

Team: 3 students. Deadline: first week of December. Time is short, so scope discipline matters more than extra features.

---

## 2. Hard constraints (never break these)

1. **Platform:** Android only. Do not add iOS, web, or desktop code.
2. **Offline-first after first sign-in:** the first login needs internet, but the saved session must let the app open and work offline afterwards. Cloud is backup only.
3. **Restore is non-destructive:** restoring version N creates a NEW commit that copies version N. Never delete or rewrite existing commits.
4. **Commits are immutable.** No editing a commit's file or hash after creation.
5. **Manual cloud sync only.** No background or automatic sync.
6. **Single-device assumption.** No multi-device conflict handling.
7. **Free tier only.** Supabase free plan. Per-account cloud quota: 100 MB. Back up latest versions only by default.
8. **No secrets in git.** Never commit API keys, `.env` files, or keystores. Use `--dart-define` for Supabase URL and anon key. Never use the Supabase service-role key in the app.
9. **No out-of-scope features** (see section 12). If a task seems to need one, stop and ask.
10. **Do not change the database schema** without asking, and always add a migration.

---

## 3. Working rules for the agent

- Work on **one small task at a time**. Finish, test, commit, then move on.
- Before editing, read the relevant files. Do not guess at existing code.
- After every task, run:
  ```bash
  dart format .
  flutter analyze
  flutter test
  ```
  Fix everything before committing. Do not commit failing code.
- Make small commits using the convention in section 5.
- Never force-push. Never rewrite shared history. Never commit directly to `main`.
- Do not add a new dependency without saying why. Prefer the packages listed in section 6.
- Keep UI and logic separate: widgets must not talk to the database directly. Use repositories.
- Write unit tests for all logic in `data/` and `core/` (hashing, commit, restore, search).
- If requirements are unclear, ask one short question instead of inventing behavior.
- At the end of each task, summarize: what changed, files touched, how to test it, anything left undone.

---

## 4. Phase 0: Repository setup (do this first)

Run once, by one team member. Replace `<org>` and `<github-user>`.

```bash
# 1. Check tools
flutter doctor
git --version
gh --version        # GitHub CLI; run `gh auth login` if needed

# 2. Create the project folder and Flutter app (Android only)
mkdir subtrack && cd subtrack
flutter create --org com.<org> --project-name subtrack --platforms android .

# 3. Initialize git on the main branch
git init -b main

# 4. Make sure secrets and build output are ignored
cat >> .gitignore << 'EOF'

# Secrets
.env
*.env
android/key.properties
*.jks
*.keystore

# Generated
*.g.dart
*.freezed.dart
EOF
# NOTE: if you prefer to commit generated drift files, remove `*.g.dart` above.

# 5. First commit
git add .
git commit -m "chore: initial Flutter project"

# 6. Create the GitHub repo and push (use --private until the defense)
gh repo create <github-user>/subtrack --private --source=. --remote=origin --push

# 7. Create the integration branch
git switch -c develop
git push -u origin develop
```

Then, in GitHub: add the other two teammates as collaborators, and set `main` as protected (require a pull request).

Add this file to the repo root as `AGENTS.md`, and commit:

```bash
git add AGENTS.md
git commit -m "docs: add agent workflow"
git push
```

---

## 5. Git workflow

**Branches**

| Branch | Purpose |
|---|---|
| `main` | Stable, demo-ready only. Merge from `develop` at the end of each phase. |
| `develop` | Integration branch. All feature branches merge here. |
| `feature/<short-name>` | One task or feature. Example: `feature/commit-history`. |
| `fix/<short-name>` | Bug fixes. |

**Per task**

```bash
git switch develop
git pull
git switch -c feature/<short-name>
# ... work, test ...
git add -A
git commit -m "feat(commits): add restore as new commit"
git push -u origin feature/<short-name>
# open a pull request into develop
```

**Commit message format:** `type(scope): short description`

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`.
Example scopes: `subjects`, `activities`, `files`, `commits`, `search`, `reminders`, `backup`, `cloud`, `ui`.

**Pull requests:** small, one feature each, with a description of what changed and how to test it. At least one teammate reviews before merging.

---

## 6. Tech stack and packages

Use these unless told otherwise.

| Need | Package |
|---|---|
| State management | `flutter_riverpod` |
| Navigation | `go_router` |
| Local database | `drift`, `drift_flutter` (dev: `drift_dev`, `build_runner`) |
| App folders | `path_provider`, `path` |
| Pick files / photos | `file_picker`, `image_picker` |
| Open and share files | `open_filex`, `share_plus` |
| Hashing | `crypto` (SHA-256) |
| Reminders | `flutter_local_notifications`, `timezone`, `permission_handler` |
| Backup zip | `archive` |
| Cloud | `supabase_flutter` |
| Date formatting | `intl` |
| Small settings (last chosen semester) | `shared_preferences` |

Install in one go:

```bash
flutter pub add flutter_riverpod go_router drift drift_flutter path_provider path \
  file_picker image_picker open_filex share_plus crypto \
  flutter_local_notifications timezone permission_handler archive \
  supabase_flutter intl shared_preferences
flutter pub add dev:drift_dev dev:build_runner
```

Generate drift code after schema changes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 7. Folder structure

```
lib/
  main.dart
  app/                 # app widget, router, theme
  core/                # constants, utils (hashing, file helpers, date helpers)
  data/
    db/                # drift database, tables, migrations
    repositories/      # SemesterRepo, SubjectRepo, ActivityRepo, FileRepo, CommitRepo, BackupRepo, CloudRepo
    storage/           # BlobStore (hash-named files on disk)
  features/
    auth/              # login, create account, session, AuthService
    semesters/         # choose and create semester
    subjects/
    activities/
    files/             # upload, list, open
    history/           # version history, restore
    search/
    reminders/
    backup/            # local export/import
    cloud/             # login, back up now, restore from cloud
  shared/              # reusable widgets
test/
```

---

## 8. Data model (agree on this in Phase 1, then keep it stable)

**semesters**: `id`, `term` (`first`, `second`, `summer`), `school_year` (e.g. `2026-2027`), `start_date`, `end_date`, `created_at`

**subjects**: `id`, `semester_id`, `name`, `color`, `icon`, `is_archived`, `created_at`

**activities**: `id`, `subject_id`, `title`, `notes`, `deadline` (nullable), `status` (`draft`, `in_progress`, `final`, `submitted`), `is_archived`, `created_at`

**files**: `id`, `activity_id`, `display_name`, `current_commit_id`, `created_at`

**commits**: `id`, `file_id`, `version_no`, `message`, `blob_hash` (SHA-256), `size_bytes`, `mime_type`, `restored_from_commit_id` (nullable), `created_at`

**Blob storage on disk:** files are saved in the app documents folder under `blobs/<sha256>` (extension kept in the commits table). If a hash already exists, do not store it again; just create a new commit pointing to the same hash.

**Rules**

- `version_no` increases by 1 per file.
- `files.current_commit_id` always points to the latest commit.
- Deleting a blob is only allowed when no commit references its hash.
- Hierarchy: semester > subject > activity > file > commit. Deleting a semester deletes its subjects, activities, files, and commits (confirm first, then clean up unreferenced blobs).
- The local database file is named per user id (`subtrack_<userId>.sqlite`). Signing out does not delete local data; signing in as another account shows that account's data.
- The last chosen semester id is kept in `shared_preferences`.

---

## 9. Phases

Each phase has a goal, tasks, and a "done when" checklist. Do not start a phase until the previous one is done. Dates assume a start of Oct 14 and a defense in the first week of December. Adjust if needed.

### Phase 1: Foundation (Week 1, Oct 14-20)

**Goal:** project runs, theme and navigation exist, schema agreed.

Tasks:

1. Complete Phase 0 (repo, branches, packages).
2. Set up `app/` with the theme (Material 3, colors from section 14), `go_router` with the routes in section 14, and the bottom navigation (Subjects, Search, Cloud) that appears only after a semester is chosen.
3. Create an `AuthService` interface (`signIn`, `signUp`, `signOut`, `currentUser`) and a `FakeAuthService` that accepts any email and password. A router redirect sends signed-out users to `/login`. The real Supabase version comes in Phase 5; until then the screens and flow are built against the fake.
4. Create the drift database with the tables in section 8 (including `semesters`) and a first migration. Name the database file per user id.
5. Create empty repository classes with method signatures only.
6. Add a minimal test that opens an in-memory database.
7. Create a Supabase project (free), a private storage bucket named `backups`, and note the URL and anon key (do NOT commit them).

Done when:

- [ ] `flutter run` opens the app on a real Android phone and shows the Login screen first.
- [ ] `flutter analyze` and `flutter test` pass.
- [ ] Schema is reviewed and approved by all three teammates.

### Phase 2: Login screens, semesters, subjects, activities, upload (Week 2, Oct 21-27)

**Goal:** a student can log in (fake auth), choose or create a semester, then organize and add files.

Tasks:

1. Login and Create account screens (validation and error text) wired to `AuthService`. Sign out from the Choose semester and Cloud screens.
2. Semesters: list (latest marked Current), create (term, school year, start and end date; end must be after start), delete with confirmation. Remember the last chosen semester. After login always show Choose semester; if none exist, show an empty state with New semester.
3. Subjects scoped to the chosen semester: list, create, rename, archive, delete (confirm), color and icon. The Change button returns to the semester list.
4. Activities per subject: list, create, rename, archive, delete, with deadline and status.
5. `BlobStore`: save a file by SHA-256 hash, reuse if it already exists.
6. File upload from storage (`file_picker`) and camera (`image_picker`). If behind schedule, move the camera to Phase 4.
7. Show files inside an activity with name, size, and date. Open a file with `open_filex`.
8. Unit tests for hashing, `BlobStore` (same file twice stores one blob), and semester deletion removing its subjects.

Done when:

- [ ] Flow works: Login, Choose semester, New semester, Subjects, Activities, Files.
- [ ] Data survives closing and reopening the app.
- [ ] Uploading the same file twice does not duplicate it on disk.
- [ ] Works with airplane mode on.

### Phase 3: Commits, history, restore (Week 3, Oct 28-Nov 3)

**Goal:** the core feature works correctly.

Tasks:

1. Uploading a file creates commit v1 with a message.
2. "Commit new version" on an existing file: pick the updated file, enter a message, create the next version.
3. Version history screen: list of commits with version number, message, date, size.
4. Open or share any old version.
5. **Restore:** create a new commit copying the chosen old version, with `restored_from_commit_id` set and a message like "Restored from v2".
6. Unit tests: version numbers increment, restore never deletes history, `current_commit_id` is correct.

Done when:

- [ ] Restoring v2 of a file with 3 versions results in 4 versions, and v4 matches v2.
- [ ] No existing commit is ever modified or deleted by restore.
- [ ] All tests pass.

### Phase 4: Search, deadlines, status, local backup (Week 4, Nov 4-10)

**Goal:** the offline app is complete and demo-ready. **This is the safety checkpoint.**

Tasks:

1. Search by subject, activity, file name, and commit message, within the chosen semester.
2. Status labels with filter chips (Draft, In Progress, Final, Submitted).
3. Deadlines with local notifications (request notification permission; handle Android 13+; test on a real device).
4. Local backup: export database + blobs as one `.zip` (`archive`), share it with `share_plus`.
5. Local restore: import a `.zip`, validate it first, ask for confirmation, and fail safely if the zip is invalid.
6. Tests for backup and restore round-trip.

Done when:

- [ ] Export, wipe app data, import: everything returns intact.
- [ ] A reminder fires on a real phone.
- [ ] Merge `develop` into `main` and tag `v0.1-offline`.

> If the project is behind schedule, stop adding features after this phase and focus on bug fixing and the cloud backup.

### Phase 5: Cloud login and manual backup (Week 5, Nov 11-17)

**Goal:** sign in and back up or restore with buttons.

Tasks:

1. Initialize Supabase using `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.
2. Replace `FakeAuthService` with a Supabase-backed `AuthService`: sign up, log in, log out (email + password), with error messages. Keep the session saved so the app opens offline.
3. Cloud tables: `semesters`, `subjects`, `activities`, `files`, `commits` with a `user_id` column. Enable **Row Level Security** so each user only sees their own rows.
4. Storage bucket policy: private, and users only access paths starting with their own `user_id/`.
5. **Back up now:** upload the latest commit's blob per file (skip blobs whose hash already exists), plus metadata. Show progress and allow cancel.
6. Enforce the **100 MB per-account quota** and show usage.
7. **Restore from cloud:** after login on a fresh install, download semesters, subjects, activities, files, commits, and the latest blobs.
8. Wi-Fi-only setting for backup (default on).
9. Handle failures: no internet, upload interrupted, quota exceeded. Show clear messages and allow retry.

Done when:

- [ ] Back up, uninstall the app, reinstall, log in, restore: data returns.
- [ ] Another user cannot read the first user's data (test it).
- [ ] Log in, close the app, turn on airplane mode, reopen: the app opens without asking to log in again.
- [ ] No keys appear in the git history.

### Phase 6: Polish and user testing (Week 6, Nov 18-24)

**Goal:** stable and pleasant to use.

Tasks:

1. Fix bugs found in testing. Test with large PDFs, many photos, and interrupted connections.
2. Empty states, loading indicators, error messages, confirmation dialogs.
3. Test on at least two different Android versions or phones.
4. Let 5 to 10 real students try it. Record feedback and a short survey.
5. Only if time remains: share-sheet import, app lock (`local_auth`), storage manager, in-app preview.

Done when:

- [ ] No crashes in the main flows (upload, commit, history, restore, backup).
- [ ] Feedback is recorded for the paper.

### Phase 7: Final (Week 7, Nov 25-Dec 1, buffer to Dec 5)

**Goal:** ready to defend.

Tasks:

1. Freeze features. Bug fixes only.
2. Build a release APK: `flutter build apk --release`.
3. Write a README: description, features, setup, screenshots.
4. Prepare a demo script and a backup demo plan (a recorded video in case of no internet).
5. **Open the Supabase project a few days before the defense**, because free projects can pause after inactivity. Test again the day before.
6. Merge to `main` and tag `v1.0`.

---

## 10. Testing checklist (run before every merge to develop)

- [ ] `dart format .` produces no changes
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] App launches on a real Android device
- [ ] The feature works in airplane mode (unless it is a cloud feature)
- [ ] Existing data still loads after the change (migration works)

---

## 11. Prompt templates (copy into opencode)

**Start a task**
> Read AGENTS.md. We are in Phase [N]. Implement: [task]. Follow the constraints and folder structure. Create a branch `feature/[name]`, make small commits, run format/analyze/test, and summarize what changed.

**Fix a bug**
> Read AGENTS.md. Bug: [description and steps to reproduce]. Find the root cause first and explain it. Then fix it with a minimal change and add a test that would have caught it.

**Review**
> Review the current branch against AGENTS.md. Check the hard constraints, test coverage, and anything that touches the schema. List problems by severity. Do not change code yet.

**Before a merge**
> Run the testing checklist from AGENTS.md section 10 and report the results.

---

## 12. Out of scope (do NOT build)

- Branching, merging, or collaboration between users
- Teacher access, school submission, or share links
- Automatic or background sync
- Multi-device simultaneous use and conflict handling
- In-app document editing
- Content diff for Word or PDF (text diff for .txt and .md is a stretch goal only)
- OCR, AI features, or document scanner (stretch only, after Phase 6)
- iOS, web, or desktop builds
- Social login (Google, Facebook) and password-less login

If something seems needed that is on this list, stop and ask the team.

---

## 13. Security notes

- Never commit `.env`, keystores, or keys. If one is committed by mistake, rotate it immediately.
- Row Level Security must be enabled on every cloud table.
- Validate zip files before importing a backup (reject unexpected paths such as `../`).
- Ask for the minimum Android permissions needed.

---

## 14. Screens and routes

The app was designed as 10 phone mockups (390 x 844). Export them as PNGs into `docs/design/` named `01-login.png`, `02-semesters.png`, and so on. If you can view images, look at them. **This section is the source of truth for behavior.** If an image and this text disagree, ask before building.

**Flow:** Login > Choose semester > (New semester) > Subjects > Activities > Activity files > Version history or Commit new version. Search and Cloud backup are bottom tabs next to Subjects.

| Route | Screen |
|---|---|
| `/login` | Login (also Create account) |
| `/semesters` | Choose semester |
| `/semesters/new` | New semester |
| `/subjects` | Subjects (tab) |
| `/subjects/:id/activities` | Activities |
| `/activities/:id` | Activity files |
| `/files/:id/history` | Version history |
| `/files/:id/commit` | Commit new version |
| `/search` | Search (tab) |
| `/cloud` | Cloud backup (tab) |

Redirect rules: signed-out users go to `/login`. After login, go to `/semesters`. Bottom tabs only show on `/subjects`, `/search`, and `/cloud`.

### Screen details

1. **Login:** app name and tagline "Every subject, every version, safely kept." Email and password fields, "Forgot password?" link, Log in (primary), Create account (secondary), and the note "Sign in once. After that, the app works offline." Signed-in users skip this screen.
2. **Choose semester:** "Signed in as <email>". One card per semester: term and school year, a Current chip on the latest, subject and file counts, date range. Tapping a card opens Subjects. Buttons: + New semester, Sign out. Empty state when none exist.
3. **New semester:** Semester (select: 1st, 2nd, Summer), School year, Start date, End date. Create semester (primary) and Cancel. After creating, go to Subjects with an empty state that prompts New subject.
4. **Subjects:** header shows "<term> - SY <year>" above "My Subjects", with a Change button (back to `/semesters`). A Due soon card lists the nearest deadlines in this semester. Subject cards: colored badge with initials, name, "N activities - N files". + New subject.
5. **Activities:** back button, subject name, activity count, filter chips (All, Draft, In progress, Final, Submitted; the row scrolls sideways). Activity cards: title, status chip, due date in amber, "N files - latest vN". + New activity.
6. **Activity files:** back button, title, status chip, due date with reminder, notes. File cards: name, latest version, last commit message, time, size, and buttons Open, History, Commit. + Add file (storage or camera).
7. **Version history:** banner "Restoring creates a new version. Nothing is deleted." Cards newest first: "vN - message", a Current chip on the latest, date and size, buttons Open and Restore (no Restore on the current one). A restore commit's message reads "Restored from vX".
8. **Commit new version:** shows the next version number, the picked file with Change file, a banner for the hash ("New content detected - SHA-256 ..." or a warning when identical to the current version), a required Commit message field (max 72 characters, with counter), Commit as vN (primary), Cancel.
9. **Search:** search box, chips (All, Files, Activities, Commits), results grouped with a type label, title, and path as context (subject > activity). Searches only the chosen semester.
10. **Cloud backup:** signed-in email with Sign out, storage bar "x / 100 MB", last backup time, Back up now, Restore from cloud, Export local backup (.zip), checkboxes "Back up on Wi-Fi only" (default on) and "Include older versions" (default off), and the note that backup is manual.

### Design tokens

| Token | Value |
|---|---|
| Background | `#F4F6FB` |
| Card | `#FFFFFF`, border `#E1E5F0`, radius 14 |
| Text / muted text | `#14182B` / `#5B6280` |
| Accent (buttons, links, active tab) | `#3B4BDB` |
| Button radius / height | 12 / 48 primary, 44 secondary |
| Deadline text / banner | `#9A5B00` on `#FFF1D6` |
| Draft chip | `#444B66` on `#ECEEF5` |
| In progress chip | `#2D3AB5` on `#E8EAFD` |
| Final chip / Current chip | `#0B6B5F` on `#DDF5F0` |
| Submitted chip | `#2F6B16` on `#E4F4DC` |
| Subject badge colors | `#3B4BDB`, `#0B7A6B`, `#B4530A`, `#7A3FB5` (white text) |
| Font | system font; screen side padding 20; minimum touch target 44 |
