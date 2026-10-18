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
  const _Setup({required this.db, required this.prefs, required this.tmp});

  final AppDatabase db;
  final SharedPreferences prefs;
  final Directory tmp;
}

/// Real file I/O (temp dirs, blob writes) never completes inside the fake
/// widget-test zone, so all prep runs via [WidgetTester.runAsync].
Future<_Setup> _setup(WidgetTester tester) async {
  final setup = await tester.runAsync(() async {
    final db = AppDatabase.memory();
    final tmp = await Directory.systemTemp.createTemp('subtrack_search_page');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    final semesterId = await SemesterRepo(db).create(
      term: 'first',
      schoolYear: '2026-2027',
      startDate: DateTime(2026, 8, 18),
      endDate: DateTime(2026, 12, 19),
    );

    // The last chosen semester is remembered per user (AGENTS.md section 8).
    SharedPreferences.setMockInitialValues({
      'selected_semester:maria@school.edu': semesterId,
    });
    final prefs = await SharedPreferences.getInstance();
    await FakeAuthService(prefs: prefs)
        .signIn(identifier: 'maria@school.edu', password: 'secret');

    final subjects = SubjectRepo(db);
    final store = BlobStore(Future.value(tmp));

    // CP1 > Thesis > thesis.txt (v1 and v2); Math > Problem set 1 > pset1.txt.
    final cp1 = await subjects.create(
      semesterId: semesterId,
      name: 'CP1',
      color: 0xFF3B4BDB,
    );
    final thesis = await db
        .into(db.activities)
        .insert(ActivitiesCompanion.insert(subjectId: cp1, title: 'Thesis'));
    final fileId = await FileRepo(db, store).upload(
      activityId: thesis,
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

    final math = await subjects.create(
      semesterId: semesterId,
      name: 'Math',
      color: 0xFF0B7A6B,
    );
    final pset = await db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(subjectId: math, title: 'Problem set 1'),
        );
    await FileRepo(db, store).upload(
      activityId: pset,
      bytes: Uint8List.fromList('answers'.codeUnits),
      displayName: 'pset1.txt',
      message: 'Answers done',
    );

    return _Setup(db: db, prefs: prefs, tmp: tmp);
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
        initialLocationProvider.overrideWithValue('/search'),
      ],
      child: const SubTrackApp(),
    ),
  );
  await _settle(tester, turns: 30);
  return setup;
}

/// Drift queries complete on the real event loop while the widget test
/// itself runs in a fake zone, so alternate both.
Future<void> _settle(WidgetTester tester, {int turns = 20}) async {
  for (var i = 0; i < turns; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('searches the chosen semester, filters, and clears', (
    tester,
  ) async {
    final setup = await _setup(tester);

    // Screen 9: search box and chips, hint before a query.
    expect(find.text('Search'), findsNWidgets(2)); // page title + tab label
    expect(find.text('Search this semester'), findsOneWidget);
    expect(
      find.text('Search subjects, activities, files, and commit messages.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'thesis');
    await _settle(tester);

    // Results grouped by type, with title and path.
    expect(find.text('Files'), findsNWidgets(2)); // chip + section
    expect(find.text('Activities'), findsNWidgets(2));
    expect(find.text('Commits'), findsNWidgets(2));
    expect(find.text('thesis.txt'), findsOneWidget);
    expect(find.text('CP1 > Thesis'), findsOneWidget);
    expect(find.text('Thesis'), findsOneWidget);
    expect(find.text('v2 - Second draft'), findsOneWidget);
    expect(find.text('v1 - Initial version'), findsOneWidget);
    expect(find.text('CP1 > Thesis > thesis.txt'), findsNWidgets(2));
    // Nothing from other subjects.
    expect(find.text('Problem set 1'), findsNothing);
    expect(find.text('pset1.txt'), findsNothing);

    // The Files chip hides the other sections.
    await tester.tap(find.widgetWithText(FilterChip, 'Files'));
    await tester.pump();
    expect(find.text('Commits'), findsOneWidget); // chip only
    expect(find.text('Thesis'), findsNothing);
    expect(find.text('thesis.txt'), findsOneWidget);

    // No matches, back on All.
    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'zzz');
    await _settle(tester);
    expect(find.text('No results for "zzz".'), findsOneWidget);

    // Clear returns to the hint.
    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    expect(
      find.text('Search subjects, activities, files, and commit messages.'),
      findsOneWidget,
    );

    await closeDatabase(tester, setup.db);
  });

  testWidgets('opening a file result shows its version history', (
    tester,
  ) async {
    final setup = await _setup(tester);

    await tester.enterText(find.byType(TextField), 'thesis');
    await _settle(tester);
    await tester.tap(find.text('thesis.txt'));
    await _settle(tester);

    expect(find.text('Version history'), findsOneWidget);
    expect(find.text('v2 - Second draft'), findsOneWidget);
    expect(find.text('v1 - Initial version'), findsOneWidget);
    expect(find.byType(CurrentChip), findsOneWidget);

    await closeDatabase(tester, setup.db);
  });
}
