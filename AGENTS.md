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
- Students can tap **Edit** on any version. The app opens a working copy in an external editor (Word, WPS, and so on), detects the changes when the student returns, and saves them as a new version.
- The student **logs in first** with a username and password and lands on the **Home dashboard**. A new student sees the Semesters icon highlighted and is prompted to add a semester; after that they create subjects, activities, and files. Returning students open Home with their last chosen semester.
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
11. **Editing happens in external apps.** Never build an in-app document editor. The only allowed exception is an optional plain-text editor for `.txt` and `.md`.
12. **Accounts are username-based.** Keep the account implementation already in the codebase and do not change how usernames map to Supabase Auth without asking.
13. **One home for each action.** Sign out, theme, notifications, and account actions live only on the Profile screen. Do not duplicate them elsewhere.

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
| Open a file in an external editor | Android `ACTION_EDIT` intent through a MethodChannel with a FileProvider (`open_filex` is view-only; test first) |

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
    dashboard/         # home dashboard, all activities, calendar
    profile/           # profile, edit profile, appearance, notifications, account
    edit/              # edit-in-external-app flow and edit sessions
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

**semesters**: `id`, `term` (`first`, `second`, `summer`), `school_year` (e.g. `2026-2027`, chosen with a year picker), `start_date`, `end_date`, `created_at`

**subjects**: `id`, `semester_id`, `name`, `color`, `icon`, `is_archived`, `created_at`

**activities**: `id`, `subject_id`, `title`, `notes`, `deadline` (nullable), `status` (`draft`, `in_progress`, `final`, `submitted`), `is_archived`, `created_at`

**files**: `id`, `activity_id`, `display_name`, `current_commit_id`, `created_at`

**commits**: `id`, `file_id`, `version_no`, `message`, `blob_hash` (SHA-256), `size_bytes`, `mime_type`, `kind` (`upload`, `edit`, `restore`), `based_on_commit_id` (nullable; the version that was restored or edited), `created_at`

**edit_sessions**: `id`, `file_id`, `base_commit_id`, `working_path`, `started_at`

**profiles**: `user_id`, `username` (unique, case-insensitive, 3-20 characters: letters, numbers, underscore), `display_name`, `avatar_path` (nullable, local only), `theme_mode` (`light`, `dark`, `system`), `accent_key` (`indigo`, `teal`, `orange`, `purple`), `remind_deadlines`, `remind_backup_weekly`, `wifi_only_backup`, `include_old_versions`

**Blob storage on disk:** files are saved in the app documents folder under `blobs/<sha256>` (extension kept in the commits table). If a hash already exists, do not store it again; just create a new commit pointing to the same hash.

**Rules**
- `version_no` increases by 1 per file.
- `files.current_commit_id` always points to the latest commit.
- Deleting a blob is only allowed when no commit references its hash.
- The username cannot be changed after sign-up. The display name and profile photo can be changed. The photo is stored on the device only and is not backed up.
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
2. Set up `app/` with the theme (Material 3, colors from section 14), `go_router` with the routes in section 14, and the bottom navigation (Search, Home, Profile, with Home in the middle).
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

1. Login and Create account screens (display name, username, password, confirm password; validation and error text) wired to `AuthService`. Sign out lives only on the Profile screen.
2. Semesters: list (latest marked Current), create (term, school year from a year picker, start and end date pickers; end must be after start), delete with confirmation. Remember the last chosen semester. After login go to Home. If no semester exists, Home shows the new-user state with the Semesters icon highlighted.
3. Subjects scoped to the chosen semester: list, create, rename, archive, delete (confirm), color and icon.
4. Activities per subject: list, create, rename, archive, delete, with deadline and status.
5. `BlobStore`: save a file by SHA-256 hash, reuse if it already exists.
6. File upload from storage (`file_picker`) and camera (`image_picker`). If behind schedule, move the camera to Phase 4.
7. Show files inside an activity with name, size, and date. Open a file with `open_filex`.
8. Unit tests for hashing, `BlobStore` (same file twice stores one blob), and semester deletion removing its subjects.

Done when:

- [ ] Flow works: Login, Home, Semesters, New semester, Subjects, Activities, Files.
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
5. **Restore:** create a new commit copying the chosen old version, with `kind = restore`, `based_on_commit_id` set, and a message like "Restored from v2".
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
2. Replace `FakeAuthService` with a Supabase-backed `AuthService`: sign up, log in, log out (username + password, using the existing account approach), with error messages. Keep the session saved so the app opens offline.
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

### Phase 5A: Dashboard, profile, and settings (Oct 25 - Nov 1)

**Goal:** the Home dashboard, navigation, profile, and settings match section 14.

Tasks:

1. Bottom navigation: Search, Home (middle), Profile. Hide it on the screens listed in section 14.
2. Home dashboard: welcome with the display name and a semester pill; Due very soon (next 3 not-submitted activities with deadlines, overdue first); Quick access icons (Semesters, Subjects, Activities, Calendar); This semester progress bar (counts per status). New-user state when no semester exists: Semesters icon highlighted, other icons disabled.
3. All activities (`/activities`): every activity in the chosen semester with filter chips (All, Due soon, Draft, In progress, Final, Submitted). Home's See all opens it on Due soon.
4. Calendar (`/calendar`): month view with markers on deadline days; tapping a day lists that day's activities.
5. Profile and Edit profile: display name, username (read-only), photo (camera, gallery, or remove). Create the `profiles` table.
6. Settings on the Profile screen: theme (Light, Dark, System) and accent (indigo, teal, orange, purple), applied immediately and saved; deadline reminders and weekly backup reminder toggles wired to `flutter_local_notifications`; Cloud backup and restore row opens `/cloud`; Change password; Sign out; Delete cloud data (confirm by typing the username); app version.
7. Remove the old Sign out buttons from Semesters and Cloud, and the Change button from Subjects (section 14, rule 13).

Done when:

- [ ] A new account sees the new-user Home, creates a semester, and returns to Home with that semester.
- [ ] Theme and accent changes apply to every screen and survive a restart.
- [ ] Sign out appears only on the Profile screen.
- [ ] Merge `develop` into `main` and tag `v0.5-dashboard`.

### Phase 5B: Edit flow (Nov 2 - Nov 8)

**Goal:** a student can edit any version in an external app and save the result as a new version.

Tasks:

1. Migration: add `kind` and `based_on_commit_id` to `commits` (existing restore commits become `kind = restore` with `based_on_commit_id` copied from `restored_from_commit_id`; all others `upload`), remove `restored_from_commit_id`, and create `edit_sessions`.
2. Edit button on each file card (edits the latest version) and on every row of Version history (edits that version).
3. Start an edit: copy the blob to `edits/<sessionId>/<fileName>` in the app-private folder, insert an `edit_sessions` row, and open the copy with an `ACTION_EDIT` intent through a FileProvider with write permission. Test with Word, WPS, and one more editor on a real phone.
4. When the app resumes (`WidgetsBindingObserver`), hash the working copy. If it changed, open Commit new version with the banner "Changes detected from your edit of vN" and the message prefilled "Edited from vN". If not, offer Keep editing or Discard.
5. Committing always creates a NEW commit: `kind = edit`, `based_on_commit_id` = the edited version, `version_no` = latest + 1, even when editing an old version (no branching). Never overwrite an existing commit.
6. Unfinished sessions show an Editing badge on the file card and are checked on app start. Discard deletes the working copy and the session.
7. Fallback button "I saved it elsewhere, pick the file" (`file_picker`) for editors that save a copy.
8. Tests: editing v1 of a 3-version file creates v4 with `based_on_commit_id` = v1; discard leaves history unchanged; sessions are cleaned up.

Done when:

- [ ] The edit loop works with at least two real editor apps.
- [ ] No existing commit is changed by an edit.
- [ ] Merge `develop` into `main` and tag `v0.6-edit`.

### Phase 6: Polish and user testing (Week 6, Nov 18-24)

**Goal:** stable and pleasant to use.

Tasks:

1. Fix bugs found in testing. Test with large PDFs, many photos, and interrupted connections.
2. Empty states, loading indicators, error messages, confirmation dialogs.
3. Test on at least two different Android versions or phones, and every screen in light mode, dark mode, and each accent color.
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
- [ ] Screens are readable in both light and dark theme

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
- Password reset by email (accounts are username-based; there is no Forgot password link)
- Account deletion (only Delete cloud data is provided)
- Cloud backup of profile photos
- An in-app document editor (optional plain-text editor for `.txt` and `.md` only)

If something seems needed that is on this list, stop and ask the team.

---

## 13. Security notes

- Never commit `.env`, keystores, or keys. If one is committed by mistake, rotate it immediately.
- Row Level Security must be enabled on every cloud table.
- Validate zip files before importing a backup (reject unexpected paths such as `../`).
- Ask for the minimum Android permissions needed.
- Delete cloud data removes the user's own rows and files through RLS-protected calls. Deleting the auth account needs a server-side function and is out of scope.
- Working copies for editing live in the app's private folder and are shared with the editor only through a FileProvider. Delete them after commit or discard.

---

## 14. Screens and routes

The app was designed as phone mockups (390 x 844) on a design canvas. Export them as PNGs into `docs/design/` (for example `01-login.png`). If you can view images, look at them. **This section is the source of truth for behavior.** If an image and this text disagree, ask before building. Calendar and All activities have no mockup yet; follow the text.

**Flow:** Login (or Create account) > Home. A new student has no semester, so Home highlights the Semesters icon > Semesters > New semester > Home. After that: Home > Subjects > Activities > Activity files > Version history, Edit, or Commit new version. Search and Profile are bottom tabs next to Home.

**Bottom navigation:** Search, Home (middle), Profile. Visible on Home, Subjects, Activities, All activities, Calendar, Activity files, Version history, Search, Profile, and Cloud backup. Hidden on Login, Create account, Semesters, New semester, Commit new version, and Edit profile.

| Route | Screen |
|---|---|
| `/login` | Login |
| `/signup` | Create account |
| `/home` | Home dashboard (returning and new-user states) |
| `/semesters` | Choose semester |
| `/semesters/new` | New semester |
| `/subjects` | Subjects |
| `/subjects/:id/activities` | Activities of one subject |
| `/activities` | All activities (`?filter=due` for Due soon) |
| `/calendar` | Calendar |
| `/activities/:id` | Activity files |
| `/files/:id/history` | Version history |
| `/files/:id/commit` | Commit new version |
| `/files/:id/edit` | Edit flow (opens the external editor, then returns to Commit) |
| `/search` | Search |
| `/profile` | Profile and settings |
| `/profile/edit` | Edit profile |
| `/cloud` | Cloud backup |

Redirects: signed-out users go to `/login`; signed-in users go to `/home`. Subjects, Activities, Calendar, and Search need a chosen semester; without one, those icons are disabled and Home shows the new-user state.

### Screen details

1. **Login:** app name and tagline "Every subject, every version, safely kept." Username and password fields, Log in (primary), Create account (secondary), and the note "Sign in once. After that, the app works offline." There is no Forgot password link.
2. **Create account:** Display name, Username (3 to 20 characters: letters, numbers, underscore; must be unique), Password (at least 8 characters), Confirm password. Create account (primary) and a Log in link. Success goes to `/home`.
3. **Home (returning):** top row shows "Welcome back," with the display name and a round profile button (opens Profile), then a pill with the chosen semester ("1st Semester - SY 2026-2027"). **Due very soon:** the next 3 not-submitted activities with a deadline in this semester, soonest first, overdue first of all (shown in red as Overdue); each card shows title, subject, and when it is due; See all opens `/activities?filter=due`. **Quick access:** four icons: Semesters, Subjects, Activities, Calendar. **This semester:** a segmented bar and counts of activities per status; tapping it opens `/activities`.
4. **Home (new user):** same top area with "Welcome," and an amber pill "No semester yet". A dashed card "Add your first semester". Due very soon shows an empty message. In Quick access the Semesters icon is highlighted with a ring and labelled "Start here"; the other icons are disabled. Creating a semester returns to the returning state.
5. **Choose semester:** back to Home, one card per semester (term and school year, Current chip on the last chosen one, subject and file counts, date range). Tapping a card makes it current and goes to `/home`. + New semester. Empty state when none exist. No Sign out here.
6. **New semester:** Semester (1st, 2nd, Summer), School year (year picker; shows `2026-2027` style), Start date and End date (date pickers). Create semester and Cancel. After creating, go to `/home`.
7. **Subjects:** header shows "<term> - SY <year>" above "My Subjects" (no Change button; use the Semesters icon). Due soon card, subject cards (colored badge with initials, name, activity and file counts), + New subject.
8. **Activities:** back button, subject name, count, filter chips (All, Draft, In progress, Final, Submitted; the row scrolls sideways), activity cards (title, status chip, due date in amber, files and latest version). + New activity.
9. **All activities:** same cards as Activities but across all subjects in the semester, each showing its subject name, plus the chip Due soon (sorted by deadline).
10. **Calendar:** month view; days with deadlines have a marker; tapping a day lists that day's activities below the grid.
11. **Activity files:** back button, title, status chip, due date with reminder, notes. File cards: name, latest version, last commit message, time, size, buttons Open, Edit, History, Commit. A file with an unfinished edit session shows an Editing badge. + Add file (storage or camera).
12. **Version history:** banner "Restoring creates a new version. Nothing is deleted." Cards newest first: "vN - message", Current chip on the latest, date and size, buttons Open and Edit on every row, plus Restore on every row except the current one. Restore commits read "Restored from vX" and edit commits read "Edited from vX".
13. **Commit new version:** shows the next version number, the picked file with Change file, a hash banner ("New content detected - SHA-256 ..." or a warning when identical to the current version), a required message (max 72 characters, counter), Commit as vN, Cancel. When opened after an edit, the banner reads "Changes detected from your edit of vN" and the message is prefilled.
14. **Search:** search box, chips (All, Files, Activities, Commits), grouped results with type label, title, and path context. Searches only the chosen semester.
15. **Profile and settings:** profile card (photo or initial, display name, @username, Edit). **Appearance:** theme (Light, Dark, System) and accent (indigo, teal, orange, purple). **Notifications:** Deadline reminders (1 day before) and Weekly backup reminder toggles. **Cloud backup and restore** row (shows last backup; opens `/cloud`). **Account:** Change password, Sign out, Delete cloud data (confirm by typing the username). Footer shows the app version.
16. **Edit profile:** photo (Take photo, Choose from gallery, Remove photo), Display name (editable), Username (read-only, "Username can't be changed"), Save changes, Cancel.
17. **Cloud backup:** signed-in username, storage bar "x / 100 MB", last backup time, Back up now, Restore from cloud, Export local backup (.zip), checkboxes "Back up on Wi-Fi only" (default on) and "Include older versions" (default off), and the note that backup is manual. No Sign out here.

### Design tokens

Accent changes primary buttons, links, the active tab, and the avatar background. Status chip colors and the deadline amber and red do not change with the accent.

| Token | Light | Dark |
|---|---|---|
| Background | `#F4F6FB` | `#0F1220` |
| Card (border) | `#FFFFFF` (`#E1E5F0`) | `#1A1F33` (`#2A3050`) |
| Text / muted text | `#14182B` / `#5B6280` | `#EDEFF8` / `#A3AACB` |
| Accent: indigo (default) | `#3B4BDB` | `#8E99FF` for text and links, `#3B4BDB` for button fills |
| Accent: teal / orange / purple | `#0B7A6B` / `#B4530A` / `#7A3FB5` | lighten for text and links; keep fills with white text |
| Deadline amber / overdue red | `#9A5B00` on `#FFF1D6` / `#B42318` | use the same hues at 20% opacity backgrounds with lighter text |
| Status chips (Draft, In progress, Final, Submitted) | `#444B66` on `#ECEEF5`, `#2D3AB5` on `#E8EAFD`, `#0B6B5F` on `#DDF5F0`, `#2F6B16` on `#E4F4DC` | foreground color at 20% opacity as background with a lighter tint for text |
| Radius / sizes | cards 14, buttons 12; primary height 48, secondary 44; minimum touch target 44; side padding 20 | same |
| Font | system font | same |

Check text contrast (at least 4.5:1) in both themes before merging any screen.
