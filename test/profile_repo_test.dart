import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/profile_repo.dart';

void main() {
  late AppDatabase db;
  late ProfileRepo repo;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    repo = ProfileRepo(db, prefs);
  });

  tearDown(() async {
    await db.close();
  });

  test('ensure creates the row once and saves keep it unique', () async {
    final first = await repo.ensure(
      userId: 'u1',
      username: 'ikwinuzzz',
      displayName: 'Kent',
    );
    expect(first.username, 'ikwinuzzz');
    expect(first.displayName, 'Kent');
    expect(first.themeMode, 'system');
    expect(first.accentKey, 'indigo');
    expect(first.wifiOnlyBackup, isTrue);
    expect(first.includeOlderVersions, isFalse);
    expect(first.remindDeadlines, isTrue);
    expect(first.remindBackupWeekly, isTrue);

    // Saving and re-ensuring must not duplicate rows.
    await repo.save(first.copyWith(wifiOnlyBackup: false));
    final again = await repo.ensure(userId: 'u1', username: 'ikwinuzzz');
    expect(again.wifiOnlyBackup, isFalse);
    final rows = await db.select(db.profiles).get();
    expect(rows, hasLength(1));
  });

  test(
    'ensure seeds the backup check boxes from the old checkbox prefs',
    () async {
      await prefs.setBool('subtrack_backup_wifi_only', false);
      await prefs.setBool('subtrack_include_older_versions', true);

      final row = await repo.ensure(userId: 'u2', username: 'maria_01');
      expect(row.wifiOnlyBackup, isFalse);
      expect(row.includeOlderVersions, isTrue);
    },
  );

  test('watch reflects saves for the account', () async {
    final stream = repo.watch('u3');
    expect(await stream.first, isNull);

    await repo.ensure(userId: 'u3', username: 'paolo_09');
    final afterEnsure = await stream.first;
    expect(afterEnsure?.username, 'paolo_09');

    await repo.save(
      afterEnsure!.copyWith(themeMode: 'dark', accentKey: 'teal'),
    );
    final afterSave = await stream.first;
    expect(afterSave?.themeMode, 'dark');
    expect(afterSave?.accentKey, 'teal');
  });
}
