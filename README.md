# SubTrack

"Git for school work" for Android. Students organise each term into
**semesters → subjects → activities → files**, and every save is an
immutable **commit** they can browse, open, and restore from.

- **Offline-first.** After the first sign-in the app works with no
  internet; the cloud is a manual backup only.
- **Restore is non-destructive.** Restoring an old version creates a new
  commit that copies it. Nothing is ever deleted or rewritten.
- **Editing happens in external apps** (Word, WPS, …). SubTrack detects the
  change on return and saves it as the next version.

## Features

- **Login** with a username and password; the session is saved so the app
  opens offline afterwards.
- **Semesters, subjects, activities, and files** with deadlines, status
  (draft / in progress / final / submitted), and search.
- **Per-subject file manager.** Each subject is a workspace with three
  tabs: **Lessons**, **Flashcards**, and **Activities**. Lessons are
  versioned folders with their own files and history; activities keep the
  status and deadline flow.
- **Version history and restore** for every file, plus *Commit new
  version* and *Edit in external app*.
- **Flashcards** (local only): manual decks, import from an external AI
  via a copy-ready prompt and JSON preview, and a flip-card study mode.
  Decks are included in the local `.zip` backup and are never sent to the
  cloud.
- **Calendar** with deadlines and standalone events, **reminders**,
  **light/dark theme with accent colours**, and a **local ZIP
  backup/restore**.
- **Manual cloud backup** (Supabase, 100 MB per account) with *Back up
  now* and *Restore from cloud*.

## Navigation

Bottom bar: **Home**, a large centre **Menu** button, and **Cloud**.
The menu sheet opens **Subjects**, **Calendar**, **Profile**,
**Flashcards**, and **File manager**.

## Getting started

See [`DEVELOPING.md`](DEVELOPING.md) for setup, the Supabase key step, and
the git workflow. Supabase schema scripts live in `docs/supabase_schema*.sql`
and are applied by the project owner only.

## Testing

```bash
dart format .
flutter analyze
flutter test
```

All three must be clean before every commit (see `AGENTS.md`).
