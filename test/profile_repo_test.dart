import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/theme.dart';
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

  test('update writes each settings field and leaves the rest alone', () async {
    await repo.ensure(userId: 'u4', username: 'kent', displayName: 'Kent');

    await repo.update(
      'u4',
      displayName: '  Kent P.  ',
      themeMode: 'dark',
      accentKey: 'pink',
      remindDeadlines: false,
    );
    var row = (await repo.byId('u4'))!;
    expect(row.displayName, 'Kent P.');
    expect(row.themeMode, 'dark');
    expect(row.accentKey, 'pink');
    expect(row.remindDeadlines, isFalse);
    expect(row.remindBackupWeekly, isTrue);
    expect(row.wifiOnlyBackup, isTrue);

    await repo.update('u4', avatarPath: '/tmp/avatar.jpg');
    row = (await repo.byId('u4'))!;
    expect(row.avatarPath, '/tmp/avatar.jpg');

    await repo.update('u4', clearAvatar: true, themeMode: 'system');
    row = (await repo.byId('u4'))!;
    expect(row.avatarPath, isNull);
    expect(row.themeMode, 'system');
    expect(row.displayName, 'Kent P.');
  });

  test('update rejects unknown themes, accents, and blank names', () async {
    await repo.ensure(userId: 'u5', username: 'paolo');
    await expectLater(
      repo.update('u5', themeMode: 'sepia'),
      throwsArgumentError,
    );
    await expectLater(repo.update('u5', accentKey: 'red'), throwsArgumentError);
    await expectLater(
      repo.update('u5', displayName: '   '),
      throwsArgumentError,
    );

    final row = (await repo.byId('u5'))!;
    expect(row.themeMode, 'system');
    expect(row.accentKey, 'indigo');
  });

  test('the accent picker offers exactly the theme accents', () {
    expect(profileAccentKeys, accentOptions.map((option) => option.key));
    expect(profileAccentKeys, contains('pink'));
  });
}
