# SubTrack

**"Git for school work" for Android.** Students organise each term into
**semesters → subjects → activities → files**, and every save becomes an
immutable **commit** they can browse, open, and restore from — the same
version-control mental model, applied to coursework instead of code.

- **Offline-first.** After the first sign-in the app works with no internet;
  the cloud is a manual backup only.
- **Restore is non-destructive.** Restoring an old version creates a *new*
  commit that copies it. Nothing is ever deleted or rewritten.
- **Editing happens in external apps** (Word, WPS, …). SubTrack copies the file
  out, hands it to the editor through a `FileProvider`, detects the change when
  the student returns, and saves it as the next version.

> 📩 **Interested in collaborating on this project, or have questions about
> it? Contact us at
> [kentpatrickilao@gmail.com](mailto:kentpatrickilao@gmail.com)** — just send
> an email and we'll get back to you.

## Download

Grab the prebuilt app here — no Flutter or Android Studio needed:

**[`app-release.apk`](app-release.apk)** (release build, ~66 MB)

1. Download the file on your phone (or copy it over).
2. Open it. Android asks to allow installs from unknown sources — approve it
   for your browser/file manager.
3. Install and open SubTrack.

## How to use SubTrack

**1. Sign in.** The first sign-in needs internet: tap **Create account**
(display name, username, email, password) or **Log in**. The session is saved
on the device, so every later visit opens straight into the app — even in
airplane mode.

**2. Create a semester.** A new account lands on Home with a yellow
*No semester yet* pill. Tap it (or the dashed card) → **+ New semester** →
pick the term (1st / 2nd / Summer), the school year with − and +, and the
start and end dates → **Create semester**. This is the container for one
school term.

**3. Add subjects.** Open **Subjects** from the menu → dashed **New subject**
tile → name, colour, icon. Each subject is its own workspace.

**4. Add activities inside a subject.** Open a subject → **Activities** tab →
**New activity** → title, optional deadline, status. Deadlines show up in the
calendar and can raise a reminder.

**5. Add files.** Open an activity → **+ Add file** (from storage or camera).
The first upload becomes **v1** of the file.

**6. Save new versions.** On any file card tap **Commit** to pick the updated
file, add a message (max 72 characters), and commit it as the next version.
Or tap **Edit**: SubTrack copies the file, opens it in Word/WPS/another
editor, and when you return it detects the change and offers to commit it —
never overwriting the old version.

**7. Browse history and restore.** On a file, open **History** to see every
version newest first (message, date, size). Open or share any old version,
or tap **Restore** — that copies the old version into a *new* commit, so
history only ever grows. Tap **Finish** on the current version to mark the
activity **Final** or **Submitted**.

**8. Study with flashcards.** Menu → **Flashcards** → create a deck by hand,
or use **Import from AI**: copy the in-app prompt, paste it into any chat AI
together with your notes/PDF, paste the JSON back, preview, and save. Study
mode flips cards offline. Decks stay on the phone and are only in the local
backup.

**9. Check the calendar.** Menu → **Calendar** shows a month view with amber
markers for activity deadlines and blue markers for your own events (add,
edit, delete). **Home** lists what is due very soon, overdue first.

**10. Personalise.** Menu → **Profile** changes the display name and photo,
theme (light/dark/system), accent colour, and the two reminder toggles.
Sign out lives here too.

**11. Back up.** Two independent options:
- **Menu → Cloud** → *Back up now* / *Restore from cloud* (Supabase, 100 MB
  per account, always manual — nothing syncs in the background).
- **Menu → Cloud** → *Export local backup (.zip)* / *Import local backup* —
  a full offline copy of your data, including flashcards and calendar events.

Everything except the first sign-in and cloud backup works with no internet.

## Features

- **Login** with a username and password; the session is saved locally, so the
  app opens offline afterwards.
- **Semesters, subjects, activities, and files** with deadlines, status
  (draft / in progress / final / submitted), and search across the semester.
- **Per-subject file manager.** Each subject is a workspace with three tabs —
  **Lessons**, **Flashcards**, and **Activities**. Lessons are versioned
  folders with their own files and history; activities keep the status and
  deadline flow.
- **Version history and restore** for every file, plus *Commit new version*
  and *Edit in external app*. Commits store a SHA-256 hash, size, message, and
  whether they came from an upload, an edit, or a restore.
- **Flashcards** (local only): manual decks, import from an external AI via a
  copy-ready prompt with a strict JSON contract, and a flip-card study mode.
  Decks ship in the local `.zip` backup and are never sent to the cloud.
- **Calendar** with deadlines and standalone events, **deadline reminders**,
  **light/dark theme with accent colours**, and a **local ZIP backup/restore**.
- **Manual cloud backup** (Supabase free tier, 100 MB per account) with
  *Back up now* and *Restore from cloud*. Row Level Security keeps every
  account's rows and files private.

## Navigation

Bottom bar: **Home**, a large centre **Menu** button, and **Cloud**.
The menu sheet opens **Subjects**, **Calendar**, **Profile**, **Flashcards**,
and **File manager**.

## Tech stack

| Layer | Choice |
|---|---|
| UI | Flutter (Material 3, Android only) |
| State | `flutter_riverpod` |
| Routing | `go_router` |
| Local database | `drift` (SQLite), one DB file per user id |
| Blob storage | SHA-256 content-addressed files on disk (deduplicated) |
| Auth + cloud | `supabase_flutter`, keys passed only through `--dart-define` |
| Notifications | `flutter_local_notifications` + `timezone` |
| Backup | `archive` (`.zip`) + `share_plus` |

```
lib/
  app/         app widget, router, theme, navigation shell
  core/        hashing, mime, date and avatar helpers
  data/        drift database, repositories, blob store
  features/    auth, dashboard, semesters, subjects, activities, files,
               history, edit, flashcards, search, reminders, backup, cloud, profile
  shared/      reusable widgets
test/          unit and widget tests
```

## Getting started (contributors)

Full setup — including the one secret step (Supabase keys) — is in
[`DEVELOPING.md`](DEVELOPING.md). Short version:

```bash
git clone https://github.com/eequen/SubTrack.git
cd SubTrack
git switch develop
flutter pub get
flutter run --dart-define-from-file=config.json
```

No cloud values yet? Run the UI with `--dart-define=USE_FAKE_AUTH=true`
(any username/password works, no network).

**No keys live in this repository.** `config.json` is gitignored; only
`config.example.json` with placeholders is tracked, and the real values enter
the binary exclusively via `--dart-define`.

## Testing

```bash
dart format .
flutter analyze
flutter test
```

All three must be clean before every commit (see [`AGENTS.md`](AGENTS.md)).

## Documentation

- [`AGENTS.md`](AGENTS.md) — project scope, hard constraints, data model, and
  the phase-by-phase plan this app was built from.
- [`DEVELOPING.md`](DEVELOPING.md) — local setup and git workflow.

## Status and license

Coursework project by a team of three; features are frozen and only bug fixes
are accepted. The repository is published for review and analysis — no
open-source license is granted, so reuse or redistribution needs the authors'
permission.
