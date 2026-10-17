import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/app.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/commit_repo.dart';
import 'package:subtrack/data/repositories/file_repo.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';
import 'package:subtrack/data/storage/blob_store.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/features/files/file_providers.dart';
import 'package:subtrack/shared/chips.dart';

import 'helpers.dart';

class _Setup {
  const _Setup({
    required this.db,
    required this.fileId,
    required this.prefs,
    required this.tmp,
  });

  final AppDatabase db;
  final int fileId;
  final SharedPreferences prefs;
  final Directory tmp;
}

/// Real file I/O (temp dirs, blob writes) never completes inside the fake
/// widget-test zone, so all prep runs via [WidgetTester.runAsync].
Future<_Setup> _setup(WidgetTester tester) async {
  final setup = await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = FakeAuthService(prefs: prefs);
    await auth.signIn(email: 'maria@school.edu', password: 'secret');
    final db = AppDatabase.memory();
    final tmp = await Directory.systemTemp.createTemp('subtrack_history_page');
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
          ActivitiesCompanion.insert(subjectId: subjectId, title: 'Thesis'),
        );

    // A file with three versions: v1 Initial, v2 Second draft, v3 Third.
    final store = BlobStore(Future.value(tmp));
    final fileId = await FileRepo(db, store).upload(
      activityId: activityId,
      bytes: Uint8List.fromList('v1 content'.codeUnits),
      displayName: 'thesis.txt',
    );
    final commits = CommitRepo(db);
    for (final (versionNo, message, content) in [
      (2, 'Second draft', 'v2 content'),
      (3, 'Third draft', 'v3 content'),
    ]) {
      final hash = await store.saveBytes(Uint8List.fromList(content.codeUnits));
      await commits.create(
        fileId: fileId,
        versionNo: versionNo,
        message: message,
        blobHash: hash,
        sizeBytes: content.length,
        mimeType: 'text/plain',
      );
    }

    return _Setup(db: db, fileId: fileId, prefs: prefs, tmp: tmp);
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
        initialLocationProvider.overrideWithValue(
          '/files/${setup.fileId}/history',
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

void main() {
  testWidgets('lists versions newest first with Current chip and restore', (
    tester,
  ) async {
    final setup = await _setup(tester);

    // Header, banner (screen 7, AGENTS.md 14).
    expect(find.text('thesis.txt'), findsOneWidget);
    expect(find.text('Version history'), findsOneWidget);
    expect(
      find.text('Restoring creates a new version. Nothing is deleted.'),
      findsOneWidget,
    );

    // Cards newest first, Current on v3 only.
    expect(find.text('v3 - Third draft'), findsOneWidget);
    expect(find.text('v2 - Second draft'), findsOneWidget);
    expect(find.text('v1 - Initial version'), findsOneWidget);
    expect(find.byType(CurrentChip), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Open'), findsNWidgets(3));
    // No Restore on the current version: v2 and v1 only.
    expect(find.widgetWithText(OutlinedButton, 'Restore'), findsNWidgets(2));

    // Restore v2 -> confirmation -> v4.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Restore').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Restore v2?'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Restore'));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    // v4 is a new commit copying v2; nothing was deleted.
    expect(find.text('v4 - Restored from v2'), findsOneWidget);
    expect(find.text('v3 - Third draft'), findsOneWidget);
    expect(find.text('v2 - Second draft'), findsOneWidget);
    expect(find.text('v1 - Initial version'), findsOneWidget);
    expect(find.byType(CurrentChip), findsOneWidget);
    // v3 and v2 can now be restored; v4 (current) cannot.
    expect(find.widgetWithText(OutlinedButton, 'Restore'), findsNWidgets(3));

    // Database agrees: 4 commits, current points at v4, v4 copies v2.
    await tester.runAsync(() async {
      final commits = await CommitRepo(setup.db)
          .watchByFile(setup.fileId)
          .first;
      expect(commits, hasLength(4));
      final v4 = commits.first;
      expect(v4.versionNo, 4);
      expect(v4.message, 'Restored from v2');
      final v2 = commits.firstWhere((c) => c.versionNo == 2);
      expect(v4.blobHash, v2.blobHash);
      expect(v4.restoredFromCommitId, v2.id);
      final item = await FileRepo(
        setup.db,
        BlobStore(Future.value(setup.tmp)),
      ).watchById(setup.fileId).first;
      expect(item!.file.currentCommitId, v4.id);
    });

    await closeDatabase(tester, setup.db);
  });
}
