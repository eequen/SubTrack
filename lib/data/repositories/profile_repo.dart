import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/data/db/app_database.dart';

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
}
