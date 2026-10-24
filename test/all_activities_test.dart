import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/app.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';

/// Screen 9: All activities. Chips filter across subjects; due soon keeps
/// overdue items; the list sorts by deadline with no-deadline last.
void main() {
  late AppDatabase db;

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'subtrack_fake_auth_email': 'kent@gmail.com',
      'selected_semester:kent@gmail.com': 1,
    });
    final prefs = await SharedPreferences.getInstance();
    final auth = FakeAuthService(prefs: prefs);
    db = AppDatabase.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authServiceProvider.overrideWithValue(auth),
          databaseProvider.overrideWithValue(db),
          initialLocationProvider.overrideWithValue('/activities'),
        ],
        child: const SubTrackApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> seedData() async {
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
            name: 'Filipino',
            color: 0xFF0B7A6B,
          ),
        );
    final dueNext = DateTime.now().add(const Duration(days: 2));
    final overdue = DateTime.now().subtract(const Duration(days: 1));
    await db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(
            subjectId: subjectId,
            title: 'Essay Next Week',
            deadline: Value(dueNext),
          ),
        );
    await db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(
            subjectId: subjectId,
            title: 'Overdue Worksheet',
            deadline: Value(overdue),
          ),
        );
    await db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(
            subjectId: subjectId,
            title: 'Submitted Report',
            status: Value('submitted'),
          ),
        );
  }

  testWidgets('lists every activity with each subject name', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester);
    await seedData();
    await tester.pumpAndSettle();

    expect(find.text('3 activities'), findsOneWidget);
    expect(find.text('Filipino'), findsNWidgets(3));
    expect(find.text('Essay Next Week'), findsOneWidget);
    expect(find.text('Overdue Worksheet'), findsOneWidget);
    expect(find.text('Submitted Report'), findsOneWidget);
    await db.close();
  });

  testWidgets('the Due soon chip excludes submitted activities', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester);
    await seedData();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Due soon'));
    await tester.pumpAndSettle();

    expect(find.text('Essay Next Week'), findsOneWidget);
    expect(find.text('Overdue Worksheet'), findsOneWidget);
    expect(find.text('Submitted Report'), findsNothing);
    await db.close();
  });

  testWidgets('the Draft chip shows only drafts', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester);
    await seedData();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Draft'));
    await tester.pumpAndSettle();

    expect(find.text('Essay Next Week'), findsOneWidget);
    expect(find.text('Overdue Worksheet'), findsOneWidget);
    expect(find.text('Submitted Report'), findsNothing);
    await db.close();
  });
}
