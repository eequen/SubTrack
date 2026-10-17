import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/app.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/core/hashing.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/commit_repo.dart';
import 'package:subtrack/data/repositories/file_repo.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';
import 'package:subtrack/data/storage/blob_store.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/features/files/file_pick.dart';
import 'package:subtrack/features/files/file_providers.dart';

import 'helpers.dart';

class _Setup {
  const _Setup({
    required this.db,
    required this.activityId,
    required this.fileId,
    required this.tmp,
    required this.prefs,
  });

  final AppDatabase db;
  final int activityId;
  final int fileId;
  final Directory tmp;
  final SharedPreferences prefs;
}

/// Real file I/O (temp dirs, blob writes) never completes inside the fake
/// widget-test zone, so all prep runs via [WidgetTester.runAsync].
Future<_Setup> _setup(
  WidgetTester tester, {
  required PickedUpload? Function(BuildContext) pick,
}) async {
  final setup = await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = FakeAuthService(prefs: prefs);
    await auth.signIn(email: 'maria@school.edu', password: 'secret');
    final db = AppDatabase.memory();
    final tmp = await Directory.systemTemp.createTemp('subtrack_commit_page');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    final semesterId = await SemesterRepo(db).create(
      term: 'first',
      schoolYear: '2026-2027',
      startDate: DateTime(2026, 8, 18),
      endDate: DateTime(2026, 12, 19),
    );
    final subjectId = await SubjectRepo(db)
        .create(semesterId: semesterId, name: 'CP1', color: 0xFF3B4BDB);
    final activityId = await db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(subjectId: subjectId, title: 'Lab report'),
        );
    final fileId = await FileRepo(db, BlobStore(Future.value(tmp))).upload(
      activityId: activityId,
      bytes: Uint8List.fromList('hello world'.codeUnits),
      displayName: 'lab1.txt',
    );

    return _Setup(
      db: db,
      activityId: activityId,
      fileId: fileId,
      tmp: tmp,
      prefs: prefs,
    );
  });
  if (setup == null) {
    fail('runAsync prep did not complete');
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(setup.prefs),
        authServiceProvider.overrideWithValue(
          FakeAuthService(prefs: setup.prefs),
        ),
        databaseProvider.overrideWithValue(setup.db),
        blobStoreProvider.overrideWithValue(BlobStore(Future.value(setup.tmp))),
        filePickerProvider.overrideWithValue((context) async => pick(context)),
        initialLocationProvider.overrideWithValue(
          '/activities/${setup.activityId}',
        ),
      ],
      child: const SubTrackApp(),
    ),
  );
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return setup;
}

/// The commit handler saves a blob (real file I/O) and writes the commit
/// (database), so real event-loop time and fake pumps must alternate.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('commits an updated file as v2 and returns to the files page', (
    tester,
  ) async {
    final updated = PickedUpload(
      bytes: Uint8List.fromList(utf8.encode('updated content')),
      name: 'lab1_v2.txt',
    );
    final setup = await _setup(tester, pick: (_) => updated);

    // Open the commit screen from the file card.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Commit'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Screen 8: next version, no file picked yet, disabled primary.
    expect(find.text('Commit new version'), findsOneWidget);
    expect(find.text('Next version v2'), findsOneWidget);
    expect(find.text('No file picked yet.'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Commit as v2'),
          )
          .enabled,
      isFalse,
    );

    // Pick the updated file: shows name, size, and the new-content hash.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Choose file'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('lab1_v2.txt'), findsOneWidget);
    expect(find.text('15 B'), findsOneWidget);
    final hash = sha256Hex(updated.bytes);
    expect(
      find.textContaining(
        'New content detected — SHA-256 ${hash.substring(0, 12)}',
      ),
      findsOneWidget,
    );

    // A message is required before committing.
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Commit as v2'),
          )
          .enabled,
      isFalse,
    );
    await tester.enterText(find.byType(TextField), 'Fixed the intro');
    await tester.pump();

    // Commit: blob saved, v2 created, pop back to the files page.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Commit as v2'));
    await _settle(tester);

    expect(find.text('Committed as v2.'), findsOneWidget);
    expect(find.text('v2'), findsOneWidget);
    expect(find.textContaining('Fixed the intro'), findsOneWidget);
    expect(find.text('Commit new version'), findsNothing);

    // Database: v2 exists, is current, and points at the new blob.
    await tester.runAsync(() async {
      final commits = await CommitRepo(setup.db)
          .watchByFile(setup.fileId)
          .first;
      expect(commits, hasLength(2));
      final v2 = commits.first;
      expect(v2.versionNo, 2);
      expect(v2.message, 'Fixed the intro');
      expect(v2.blobHash, hash);
      expect(v2.sizeBytes, updated.bytes.length);
      final item = await FileRepo(
        setup.db,
        BlobStore(Future.value(setup.tmp)),
      ).watchById(setup.fileId).first;
      expect(item!.file.currentCommitId, v2.id);
      // Original v1 is untouched.
      expect(commits.last.message, 'Initial version');
    });

    await closeDatabase(tester, setup.db);
  });

  testWidgets(
    'warns when the picked file is identical to the current version',
    (tester) async {
      // Same bytes as the uploaded original.
      final same = PickedUpload(
        bytes: Uint8List.fromList('hello world'.codeUnits),
        name: 'lab1.txt',
      );
      final setup = await _setup(tester, pick: (_) => same);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Commit'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.widgetWithText(OutlinedButton, 'Choose file'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('identical to the current version (v1)'),
        findsOneWidget,
      );
      expect(find.textContaining('New content detected'), findsNothing);

      await closeDatabase(tester, setup.db);
    },
  );
}
