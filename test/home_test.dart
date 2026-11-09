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
  String initialLocation = '/home',
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
        initialLocationProvider.overrideWithValue(initialLocation),
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
      expect(find.text('Quick access'), findsNothing);
      expect(
        tester
            .widgetList<NavigationDestination>(
              find.byType(NavigationDestination),
            )
            .map((destination) => destination.label)
            .toList(),
        ['Cloud', 'Subjects', 'Home', 'Calendar', 'Profile'],
      );
      await tester.tap(find.text('Add your first semester'));
      await tester.pumpAndSettle();
      expect(find.text('Choose semester'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // The Subjects tab stays visible but is disabled until a semester exists.
      expect(find.text('Subjects'), findsOneWidget);
      await tester.tap(find.text('Subjects'));
      await tester.pump();
      expect(find.text('Welcome,'), findsOneWidget);
      await db.close();
    },
  );

  testWidgets('semester pill opens a chooser sheet and keeps the home route', (
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
    final secondId = await db
        .into(db.semesters)
        .insert(
          SemestersCompanion.insert(
            term: 'second',
            schoolYear: '2026-2027',
            startDate: DateTime(2027, 1, 10),
            endDate: DateTime(2027, 5, 20),
          ),
        );
    expect(secondId, 2);
    await tester.pumpAndSettle();

    await tester.tap(find.text('1st Semester - SY 2026-2027'));
    await tester.pumpAndSettle();
    expect(find.text('Choose semester'), findsOneWidget);

    await tester.tap(find.text('2nd Semester · SY 2026-2027'));
    await tester.pumpAndSettle();
    expect(find.text('Choose semester'), findsNothing);
    expect(find.text('2nd Semester - SY 2026-2027'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await db.close();
  });

  testWidgets('new semester form steps school year and previews changes', (
    tester,
  ) async {
    _tallView(tester);
    final db = await _pumpApp(
      tester,
      prefsInitial: {'subtrack_fake_auth_email': 'kent@gmail.com'},
      initialLocation: '/semesters/new',
    );

    final year = DateTime.now().year;
    expect(find.text('School year'), findsOneWidget);
    expect(find.text('$year – ${year + 1}'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    await tester.tap(find.byTooltip('Next school year'));
    await tester.pump();
    expect(find.text('${year + 1} – ${year + 2}'), findsOneWidget);
    expect(find.textContaining('SY ${year + 1}-${year + 2}'), findsOneWidget);
    await db.close();
  });

  testWidgets('semesters deep link shows chooser content', (tester) async {
    _tallView(tester);
    final db = await _pumpApp(
      tester,
      prefsInitial: {'subtrack_fake_auth_email': 'kent@gmail.com'},
      initialLocation: '/semesters',
    );

    expect(find.text('Choose semester'), findsOneWidget);
    expect(find.text('No semesters yet'), findsOneWidget);
    expect(
      find.text('Add a semester to start organizing your subjects.'),
      findsOneWidget,
    );
    expect(find.text('New semester'), findsOneWidget);
    await db.close();
  });

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
