import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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
import 'package:subtrack/features/edit/edit_providers.dart';
import 'package:subtrack/features/edit/editor_service.dart';
import 'package:subtrack/features/files/file_providers.dart';

import 'helpers.dart';

class _FakeEditor implements EditorService {
  final List<String> opened = [];

  @override
  Future<void> openForEdit({
    required String path,
    required String mimeType,
  }) async {
    opened.add(path);
  }
}

class _Setup {
  const _Setup({
    required this.db,
    required this.activityId,
    required this.fileId,
    required this.prefs,
    required this.tmp,
    required this.editor,
  });

  final AppDatabase db;
  final int activityId;
  final int fileId;
  final SharedPreferences prefs;
  final Directory tmp;
  final _FakeEditor editor;
}

Future<_Setup> _setup(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final editor = _FakeEditor();
  final setup = await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = FakeAuthService(prefs: prefs);
    await auth.signIn(identifier: 'maria@school.edu', password: 'secret');
    final db = AppDatabase.memory();
    final tmp = await Directory.systemTemp.createTemp('subtrack_edit_page');
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
    final fileId = await FileRepo(db, BlobStore(Future.value(tmp))).upload(
      activityId: activityId,
      bytes: Uint8List.fromList('v1 content'.codeUnits),
      displayName: 'thesis.txt',
    );
    await prefs.setInt('selected_semester:maria@school.edu', semesterId);

    return _Setup(
      db: db,
      activityId: activityId,
      fileId: fileId,
      prefs: prefs,
      tmp: tmp,
      editor: editor,
    );
  });
  if (setup == null) fail('runAsync prep did not complete');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(setup.prefs),
        authServiceProvider.overrideWithValue(
          FakeAuthService(prefs: setup.prefs),
        ),
        databaseProvider.overrideWithValue(setup.db),
        blobStoreProvider.overrideWithValue(BlobStore(Future.value(setup.tmp))),
        editorServiceProvider.overrideWithValue(setup.editor),
        initialLocationProvider.overrideWithValue(
          '/activities/${setup.activityId}',
        ),
      ],
      child: const SubTrackApp(),
    ),
  );
  await _settle(tester);
  return setup;
}

/// Real file I/O and the database run outside the fake widget-test zone, so
/// alternate real event-loop turns with fake pumps.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('edits the latest version and commits the result as v2', (
    tester,
  ) async {
    final setup = await _setup(tester);

    // Screen 6 now has an Edit action on the file card.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await _settle(tester);

    // The working copy was opened externally and the page shows its base.
    expect(find.text('Edit in another app'), findsOneWidget);
    expect(find.text('Editing v1'), findsOneWidget);
    expect(setup.editor.opened, hasLength(1));
    expect(p.basename(setup.editor.opened.single), 'thesis.txt');

    // Simulate Word/WPS changing the working copy, then the app resuming.
    final edited = Uint8List.fromList('v1 content edited in Word'.codeUnits);
    final session = await tester.runAsync(() async {
      final rows = await setup.db.select(setup.db.editSessions).get();
      expect(rows, hasLength(1));
      await File(rows.single.workingPath).writeAsBytes(edited, flush: true);
      return rows.single;
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);

    // Screen 8, opened from the edit: prefill and change banner.
    expect(find.text('Changes detected from your edit of v1.'), findsOneWidget);
    expect(find.text('Next version v2'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Edited from v1',
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Commit as v2'));
    await _settle(tester);

    // Back on the files screen with the new version.
    expect(find.text('Committed as v2.'), findsOneWidget);
    expect(find.text('v2'), findsOneWidget);
    expect(find.textContaining('Edited from v1'), findsOneWidget);

    await tester.runAsync(() async {
      final commits = await CommitRepo(setup.db)
          .watchByFile(setup.fileId)
          .first;
      expect(commits, hasLength(2));
      final v2 = commits.first;
      final v1 = commits.last;
      expect(v2.versionNo, 2);
      expect(v2.kind, 'edit');
      expect(v2.basedOnCommitId, v1.id);
      expect(v2.blobHash, sha256Hex(edited));
      expect(v1.message, 'Initial version');
      // The session and its folder are gone after a successful commit.
      expect(await setup.db.select(setup.db.editSessions).get(), isEmpty);
      expect(await File(session!.workingPath).exists(), isFalse);
    });

    await closeDatabase(tester, setup.db);
  });

  testWidgets('an unfinished edit shows the Editing badge on the file card', (
    tester,
  ) async {
    final setup = await _setup(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await _settle(tester);

    // Leave the edit without committing (Back), then look at the file card.
    await tester.tap(find.byTooltip('Back'));
    await _settle(tester);

    expect(find.text('Editing'), findsOneWidget);
    expect(find.text('thesis.txt'), findsOneWidget);

    await closeDatabase(tester, setup.db);
  });
}
