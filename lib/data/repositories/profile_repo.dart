import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/data/db/app_database.dart';

/// Accent keys the appearance picker offers. Kept in sync with
/// [accentOptions] in app/theme.dart; a test checks the two lists match.
const profileAccentKeys = ['indigo', 'teal', 'orange', 'purple', 'pink'];

/// Theme modes accepted by the profiles table (AGENTS.md section 8).
const profileThemeModes = ['light', 'dark', 'system'];

/// The local profile row: one per account, inside that account's database
/// file (AGENTS.md section 8). Keeps display name, avatar, theme, and
/// notification/backup settings; the avatar never leaves this device.
class ProfileRepo {
  ProfileRepo(this._db, this._prefs);

  final AppDatabase _db;
  final SharedPreferences _prefs;

  Future<DbProfile?> byId(String userId) {
    final query = _db.select(_db.profiles)
      ..where((tbl) => tbl.userId.equals(userId));
    return query.getSingleOrNull();
  }

  Stream<DbProfile?> watch(String userId) {
    final query = _db.select(_db.profiles)
      ..where((tbl) => tbl.userId.equals(userId));
    return query.watchSingleOrNull();
  }

  /// Returns the account's row, creating it on first run. The two backup
  /// check boxes are seeded from the original settings storage so values
  /// from before Phase 5A survive; afterwards the profile row is the only
  /// source of truth.
  Future<DbProfile> ensure({
    required String userId,
    required String username,
    String displayName = '',
  }) async {
    final query = _db.select(_db.profiles)
      ..where((tbl) => tbl.userId.equals(userId));
    final current = await query.getSingleOrNull();
    if (current != null) return current;

    await _db
        .into(_db.profiles)
        .insert(
          ProfilesCompanion.insert(
            userId: userId,
            username: username,
            displayName: Value(displayName),
            wifiOnlyBackup: Value(
              _prefs.getBool('subtrack_backup_wifi_only') ?? true,
            ),
            includeOlderVersions: Value(
              _prefs.getBool('subtrack_include_older_versions') ?? false,
            ),
          ),
        );
    return query.getSingle();
  }

  Future<DbProfile> save(DbProfile row) async {
    await _db.into(_db.profiles).insertOnConflictUpdate(row);
    return row;
  }

  /// Writes the settings the Profile screen edits. Only the fields passed
  /// change; [clearAvatar] removes the photo path. Values are validated
  /// before touching the row so a bad state never reaches the UI.
  Future<void> update(
    String userId, {
    String? displayName,
    String? avatarPath,
    bool clearAvatar = false,
    String? themeMode,
    String? accentKey,
    bool? remindDeadlines,
    bool? remindBackupWeekly,
  }) async {
    final name = displayName?.trim();
    if (displayName != null && (name!.isEmpty || name.length > 30)) {
      throw ArgumentError('Display names use 1-30 characters.');
    }
    if (themeMode != null && !profileThemeModes.contains(themeMode)) {
      throw ArgumentError('Unknown theme mode: $themeMode');
    }
    if (accentKey != null && !profileAccentKeys.contains(accentKey)) {
      throw ArgumentError('Unknown accent: $accentKey');
    }
    await (_db.update(
      _db.profiles,
    )..where((tbl) => tbl.userId.equals(userId))).write(
      ProfilesCompanion(
        displayName: displayName == null ? const Value.absent() : Value(name!),
        avatarPath: clearAvatar
            ? const Value(null)
            : avatarPath == null
            ? const Value.absent()
            : Value(avatarPath),
        themeMode: themeMode == null ? const Value.absent() : Value(themeMode),
        accentKey: accentKey == null ? const Value.absent() : Value(accentKey),
        remindDeadlines: remindDeadlines == null
            ? const Value.absent()
            : Value(remindDeadlines),
        remindBackupWeekly: remindBackupWeekly == null
            ? const Value.absent()
            : Value(remindBackupWeekly),
      ),
    );
  }
}
