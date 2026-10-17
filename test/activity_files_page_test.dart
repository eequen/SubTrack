import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/app.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/file_repo.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';
import 'package:subtrack/data/storage/blob_store.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/features/files/file_providers.dart';
import 'package:subtrack/shared/chips.dart';

class _Setup {
  const _Setup({
    required this.db,
    required this.activityId,
    required this.prefs,
    required this.auth,
    required this.tmp,
  });

  final AppDatabase db;
  final int activityId;
  final SharedPreferences prefs;
  final FakeAuthService auth;
  final Directory tmp;
}

/// Real file I/O (temp dirs, blob writes) never completes inside the fake
/// widget-test zone, so all prep runs via [WidgetTester.runAsync].
Future<_Setup> _setup(WidgetTester tester, {bool withFile = true}) async {
  final setup = await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = FakeAuthService(prefs: prefs);
    await auth.signIn(email: 'maria@school.edu', password: 'secret');
    final db = AppDatabase.memory();
    final tmp = await Directory.systemTemp.createTemp('subtrack_blobs_page');
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
          ActivitiesCompanion.insert(
            subjectId: subjectId,
            title: 'Lab report',
            notes: const Value('Bring the handout'),
            deadline: Value(DateTime(2026, 11, 3)),
            status: const Value('final'),
          ),
        );
    if (withFile) {
      await FileRepo(db, BlobStore(Future.value(tmp))).upload(
        activityId: activityId,
        bytes: Uint8List.fromList('hello world'.codeUnits),
        displayName: 'lab1.txt',
      );
    }
    await prefs.setInt('selected_semester:maria@school.edu', semesterId);

    return _Setup(
      db: db,
      activityId: activityId,
      prefs: prefs,
      auth: auth,
      tmp: tmp,
    );
  });
  if (setup == null) {
    fail('runAsync prep did not complete');
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(setup.prefs),
        authServiceProvider.overrideWithValue(setup.auth),
        databaseProvider.overrideWithValue(setup.db),
        blobStoreProvider.overrideWithValue(BlobStore(Future.value(setup.tmp))),
        initialLocationProvider.overrideWithValue(
          '/activities/${setup.activityId}',
        ),
      ],
      child: const SubTrackApp(),
    ),
  );
  // Bounded pumps: a regression fails with a real assertion instead of a
  // silent hang the way pumpAndSettle would.
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return setup;
}

void main() {
  testWidgets('shows activity details and the uploaded file card', (
    tester,
  ) async {
    final setup = await _setup(tester);

    // Header: title, status chip, deadline, notes (screen 6, AGENTS.md 14).
    expect(find.text('Lab report'), findsOneWidget);
    expect(find.byType(StatusChip), findsOneWidget);
    expect(find.text('Final'), findsOneWidget);
    expect(find.byType(DeadlineChip), findsOneWidget);
    expect(find.text('Bring the handout'), findsOneWidget);

    // File card: name, version, message, size, actions.
    expect(find.text('lab1.txt'), findsOneWidget);
    expect(find.text('v1'), findsOneWidget);
    expect(find.textContaining('Initial version'), findsOneWidget);
    expect(find.text('11 B'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Open'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'History'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Commit'), findsOneWidget);

    expect(find.widgetWithText(ElevatedButton, '+ Add file'), findsOneWidget);

    await setup.db.close();
    await tester.pump();
  });

  testWidgets('empty activity shows the empty state', (tester) async {
    final setup = await _setup(tester, withFile: false);

    expect(find.text('No files yet.'), findsOneWidget);
    expect(find.text('lab1.txt'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, '+ Add file'), findsOneWidget);

    await setup.db.close();
    await tester.pump();
  });
}
