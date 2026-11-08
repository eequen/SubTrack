import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/app.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/storage/blob_store.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/features/files/file_providers.dart';

/// The Home dashboard is tall; make room like the create-account tests do.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<AppDatabase> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefsInitial = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefsInitial);
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthService(prefs: prefs);
  final db = AppDatabase.memory();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(auth),
        databaseProvider.overrideWithValue(db),
      ],
      child: const SubTrackApp(),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

Future<int> _seedSemester(AppDatabase db) {
  return db
      .into(db.semesters)
      .insert(
        SemestersCompanion.insert(
          term: 'first',
          schoolYear: '2026-2027',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 12, 15),
        ),
      );
}

Future<void> _seedSubjectAndActivity(
  AppDatabase db, {
  required int semesterId,
  required DateTime deadline,
  required String status,
}) async {
  final subjectId = await db
      .into(db.subjects)
      .insert(
        SubjectsCompanion.insert(
          semesterId: semesterId,
          name: 'Math 101',
          color: 0xFF3B4BDB,
        ),
      );
  await db
      .into(db.activities)
      .insert(
        ActivitiesCompanion.insert(
          subjectId: subjectId,
          title: 'Sample Essay',
          deadline: Value(deadline),
          status: Value(status),
        ),
      );
}

void main() {
  testWidgets(
    'a signed-in session without a chosen semester shows the new-user home',
    (tester) async {
      _tallView(tester);
      final db = await _pumpApp(
        tester,
        prefsInitial: {'subtrack_fake_auth_email': 'kent@gmail.com'},
      );

      expect(find.text('Welcome,'), findsOneWidget);
      expect(find.text('kent'), findsOneWidget);
      expect(find.text('No semester yet'), findsOneWidget);
      expect(find.text('Add your first semester'), findsOneWidget);
      expect(find.text('Start here'), findsOneWidget);
      // The subjects icon is disabled for brand-new students.
      expect(find.text('Subjects'), findsOneWidget);
      await db.close();
    },
  );

  testWidgets('the chosen semester shows the pill, due card, and progress', (
    tester,
  ) async {
    _tallView(tester);
    final db = await _pumpApp(
      tester,
      prefsInitial: {
        'subtrack_fake_auth_email': 'kent@gmail.com',
        'selected_semester:kent@gmail.com': 1,
      },
    );
    final semesterId = await _seedSemester(db);
    expect(semesterId, 1);
    await _seedSubjectAndActivity(
      db,
      semesterId: semesterId,
      deadline: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      status: 'draft',
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back,'), findsOneWidget);
    expect(find.text('1st Semester - SY 2026-2027'), findsOneWidget);
    expect(find.text('Sample Essay'), findsOneWidget);
    expect(find.textContaining('Overdue'), findsOneWidget);
    expect(find.text('This semester'), findsOneWidget);
    expect(find.text('1 activity'), findsOneWidget);
    await db.close();
  });

  testWidgets('activity files open inside the nav shell', (tester) async {
    _tallView(tester);
    // Prep (prefs, db rows, temp dirs) runs via runAsync because real file
    // I/O does not complete inside the fake widget-test zone; bounded
    // pumps replace pumpAndSettle, which can hang (the pattern used by
    // activity_files_page_test).
    final prepared = await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({
        'subtrack_fake_auth_email': 'kent@gmail.com',
        'selected_semester:kent@gmail.com': 1,
      });
      final prefs = await SharedPreferences.getInstance();
      final auth = FakeAuthService(prefs: prefs);
      final db = AppDatabase.memory();
      final tmp = await Directory.systemTemp.createTemp('subtrack_home_tap');
      addTearDown(() async {
        if (await tmp.exists()) {
          await tmp.delete(recursive: true);
        }
      });

      final semesterId = await db
          .into(db.semesters)
          .insert(
            SemestersCompanion.insert(
              term: 'first',
              schoolYear: '2026-2027',
              startDate: DateTime(2026, 8, 1),
              endDate: DateTime(2026, 12, 15),
            ),
          );
      final subjectId = await db
          .into(db.subjects)
          .insert(
            SubjectsCompanion.insert(
              semesterId: semesterId,
              name: 'Math 101',
              color: 0xFF3B4BDB,
            ),
          );
      final activityId = await db
          .into(db.activities)
          .insert(
            ActivitiesCompanion.insert(
              subjectId: subjectId,
              title: 'Sample Essay',
              deadline: Value(DateTime.now().add(const Duration(days: 2))),
            ),
          );
      return (
        db: db,
        tmp: tmp,
        prefs: prefs,
        auth: auth,
        activityId: activityId,
      );
    });
    if (prepared == null) {
      fail('runAsync prep did not complete');
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prepared.prefs),
          authServiceProvider.overrideWithValue(prepared.auth),
          databaseProvider.overrideWithValue(prepared.db),
          blobStoreProvider.overrideWithValue(
            BlobStore(Future.value(prepared.tmp)),
          ),
          initialLocationProvider.overrideWithValue(
            '/activities/${prepared.activityId}',
          ),
        ],
        child: const SubTrackApp(),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Header and files render, and the bottom bar stays visible because
    // the route lives in the home branch of the navigation shell.
    expect(find.text('Sample Essay'), findsOneWidget);
    expect(find.text('No files yet.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await prepared.db.close();
    await tester.pump();
  });
}
