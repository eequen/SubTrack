import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/app.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/backup_repo.dart';
import 'package:subtrack/data/repositories/commit_repo.dart';
import 'package:subtrack/data/repositories/file_repo.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';
import 'package:subtrack/data/storage/blob_store.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/features/backup/backup_providers.dart';
import 'package:subtrack/features/files/file_pick.dart';
import 'package:subtrack/features/files/file_providers.dart';

import 'helpers.dart';

class _Setup {
  const _Setup({
    required this.db,
    required this.prefs,
    required this.tmp,
    required this.zipBytes,
  });

  final AppDatabase db;
  final SharedPreferences prefs;
  final Directory tmp;
  final Uint8List zipBytes;
}

/// Real file I/O (temp dirs, blob writes, zip export) never completes inside
/// the fake widget-test zone, so all prep runs via [WidgetTester.runAsync].
Future<_Setup> _setup(WidgetTester tester) async {
  final setup = await tester.runAsync(() async {
    final db = AppDatabase.memory();
    final tmp = await Directory.systemTemp.createTemp('subtrack_cloud_page');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    final semesterId = await SemesterRepo(db).create(
      term: 'first',
      schoolYear: '2026-2027',
      startDate: DateTime(2026, 8, 18),
      endDate: DateTime(2026, 12, 19),
    );
    SharedPreferences.setMockInitialValues({
      'selected_semester:maria@school.edu': semesterId,
    });
    final prefs = await SharedPreferences.getInstance();
    await FakeAuthService(prefs: prefs)
        .signIn(email: 'maria@school.edu', password: 'secret');

    final subjectId = await SubjectRepo(db)
        .create(semesterId: semesterId, name: 'CP1', color: 0xFF3B4BDB);
    final activityId = await db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(subjectId: subjectId, title: 'Thesis'),
        );
    final store = BlobStore(Future.value(tmp));
    final fileId = await FileRepo(db, store).upload(
      activityId: activityId,
      bytes: Uint8List.fromList('v1 content'.codeUnits),
      displayName: 'thesis.txt',
    );
    final hash = await store.saveBytes(
      Uint8List.fromList('v2 content'.codeUnits),
    );
    await CommitRepo(db).create(
      fileId: fileId,
      versionNo: 2,
      message: 'Second draft',
      blobHash: hash,
      sizeBytes: 10,
      mimeType: 'text/plain',
    );

    // A backup of this data, taken before the wipe below.
    final repo = BackupRepo(db, store, Future.value(tmp));
    final zipBytes = await repo.export().then((file) => file.readAsBytes());

    // Simulate a lost phone: no rows left, only the backup.
    await db.delete(db.commits).go();
    await db.delete(db.files).go();
    await db.delete(db.activities).go();
    await db.delete(db.subjects).go();
    await db.delete(db.semesters).go();

    return _Setup(db: db, prefs: prefs, tmp: tmp, zipBytes: zipBytes);
  });
  if (setup == null) {
    fail('runAsync prep did not complete');
  }
  return setup;
}

Future<void> _pump(WidgetTester tester, _Setup setup) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(setup.prefs),
        authServiceProvider.overrideWithValue(
          FakeAuthService(prefs: setup.prefs),
        ),
        databaseProvider.overrideWithValue(setup.db),
        blobStoreProvider.overrideWithValue(BlobStore(Future.value(setup.tmp))),
        backupRepoProvider.overrideWithValue(
          BackupRepo(
            setup.db,
            BlobStore(Future.value(setup.tmp)),
            Future.value(setup.tmp),
          ),
        ),
        backupPickerProvider.overrideWithValue(
          () async => PickedUpload(bytes: setup.zipBytes, name: 'backup.zip'),
        ),
        initialLocationProvider.overrideWithValue('/cloud'),
      ],
      child: const SubTrackApp(),
    ),
  );
  await _settle(tester);
}

/// Drift queries and file I/O complete on the real event loop while the
/// widget test itself runs in a fake zone, so alternate both.
Future<void> _settle(WidgetTester tester, {int turns = 30}) async {
  for (var i = 0; i < turns; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('export produces a zip; import confirms and replaces', (
    tester,
  ) async {
    final setup = await _setup(tester);
    await _pump(tester, setup);

    // Screen 10 (Phase 4 portion): email and the two local backup buttons.
    expect(find.text('Signed in as maria@school.edu'), findsOneWidget);
    expect(find.text('Export local backup (.zip)'), findsOneWidget);
    expect(find.text('Import local backup (.zip)'), findsOneWidget);

    // Export writes the .zip under the app's backups folder; the share
    // sheet itself is a platform channel and is not asserted here.
    await tester.tap(find.text('Export local backup (.zip)'));
    await _settle(tester);
    final zips = await tester.runAsync(() async {
      final dir = Directory(p.join(setup.tmp.path, 'backups'));
      if (!await dir.exists()) return <File>[];
      return (await dir.list().toList())
          .whereType<File>()
          .where((file) => file.path.endsWith('.zip'))
          .toList();
    });
    expect(zips, isNotEmpty);

    // Import asks for confirmation first; cancelling changes nothing.
    await tester.tap(find.text('Import local backup (.zip)'));
    await _settle(tester);
    expect(find.text('Import backup?'), findsOneWidget);
    expect(find.textContaining('Semesters: 1'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(
      await tester.runAsync(() => setup.db.select(setup.db.commits).get()),
      isEmpty,
    );

    // Confirming replaces the data: the lost phone is restored.
    await tester.tap(find.text('Import local backup (.zip)'));
    await _settle(tester);
    await tester.tap(find.text('Import'));
    await _settle(tester, turns: 40);
    expect(
      find.text('Backup imported. Choose a semester to see it.'),
      findsOneWidget,
    );
    expect(
      await tester.runAsync(() => setup.db.select(setup.db.commits).get()),
      hasLength(2),
    );

    // The chosen semester was reset (the backup brings its own ids).
    expect(setup.prefs.getInt('selected_semester:maria@school.edu'), isNull);

    await closeDatabase(tester, setup.db);
  });
}
