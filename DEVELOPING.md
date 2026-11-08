# Developing SubTrack

Get the app running on your own machine in about 5 minutes.

## What you need

1. **Flutter SDK** (stable; `flutter --version` should be 3.x, close to 3.47)
2. **Git**
3. **VS Code** (recommended, because of the included launch config) or any editor
4. A phone with **USB debugging on** (or an Android emulator)

If `flutter doctor` shows anything red in the Android toolchain section, follow its hints first (Android Studio installs the SDK for you).

## One-time setup

```bash
git clone https://github.com/eequen/SubTrack.git
cd SubTrack
git switch develop        # newest work lives here, never on main
flutter pub get
flutter doctor            # fix anything it flags
```

## The one secret step (Supabase keys)

The Supabase URL and key are **not stored in the repo** (AGENTS.md rule 8).
Ask for the two cloud values in the group chat, then:

1. Copy `docs/config.example.json` to `config.json` in the repo root
2. Paste the two values in

`config.json` is gitignored — it will never be committed. Only the example file with placeholders is in the repo.

## Run the app

- **VS Code:** pick a device in the status bar (bottom right), press **F5**
  — this uses `.vscode/launch.json`, which points at your `config.json`
- **Terminal:** `flutter run --dart-define-from-file=config.json`

No `config.json` yet? The app still opens in **FakeAuth mode** (any
username/password works, no cloud) — fine for UI work, useless for cloud
backups.

## Just want to test, not code?

You don't need Flutter at all — install the APK straight from the group
chat (shared as `app-debug.apk` on Drive). Uninstall/reinstall freely;
that is exactly what the backup/restore flow is for.

## Cloud tables stay in one place

All `docs/supabase_schema*.sql` scripts are applied by the project owner
in the Supabase dashboard. Teammates do **not** run them.

## Git workflow (short version)

```bash
git switch develop
git pull
git switch -c feature/my-feature

# ... code, then before every commit:

dart format .
flutter analyze
flutter test

git add -A
git commit -m "feat(scope): short description"
git push -u origin feature/my-feature
```

Then open a pull request into `develop` on GitHub. One feature per branch,
small commits, never commit directly to `main`, never force-push.
