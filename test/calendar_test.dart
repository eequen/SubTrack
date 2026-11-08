import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/app.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/activity_repo.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/features/dashboard/calendar_page.dart';

/// Screen 10: Calendar. The month grid marks days with deadlines, tapping
/// a day lists its activities, and past months navigate with the arrows.
/// Deadline days stay visible for submitted and past activities; archived
/// ones never appear.
void main() {
  test(
    'the deadlines query keeps past and submitted but not archived',
    () async {
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final now = DateTime.now();
      final semesterId = await db
          .into(db.semesters)
          .insert(
            SemestersCompanion.insert(
              term: 'first',
              schoolYear: '2026-2027',
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 12, 31),
            ),
          );
      final otherSemesterId = await db
          .into(db.semesters)
          .insert(
            SemestersCompanion.insert(
              term: 'second',
              schoolYear: '2026-2027',
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 12, 31),
            ),
          );
      final subjectId = await db
          .into(db.subjects)
          .insert(
            SubjectsCompanion.insert(
              semesterId: semesterId,
              name: 'Chemistry',
              color: 0xFF3B4BDB,
            ),
          );
      final otherSubjectId = await db
          .into(db.subjects)
          .insert(
            SubjectsCompanion.insert(
              semesterId: otherSemesterId,
              name: 'History',
              color: 0xFF0B7A6B,
            ),
          );

      await db
          .into(db.activities)
          .insert(
            ActivitiesCompanion.insert(
              subjectId: subjectId,
              title: 'Past Quiz',
              deadline: Value(now.subtract(const Duration(days: 3))),
            ),
          );
      await db
          .into(db.activities)
          .insert(
            ActivitiesCompanion.insert(
              subjectId: subjectId,
              title: 'Next Essay',
              deadline: Value(now.add(const Duration(days: 3))),
              status: const Value('submitted'),
            ),
          );
      await db
          .into(db.activities)
          .insert(
            ActivitiesCompanion.insert(
              subjectId: subjectId,
              title: 'No deadline',
            ),
          );
      await db
          .into(db.activities)
          .insert(
            ActivitiesCompanion.insert(
              subjectId: subjectId,
              title: 'Archived thing',
              deadline: Value(now.add(const Duration(days: 1))),
              isArchived: const Value(true),
            ),
          );
      await db
          .into(db.activities)
          .insert(
            ActivitiesCompanion.insert(
              subjectId: otherSubjectId,
              title: 'Other semester',
              deadline: Value(now.add(const Duration(days: 2))),
            ),
          );

      final items = await ActivityRepo(db)
          .watchDeadlinesInSemester(semesterId)
          .first;

      expect(items.map((item) => item.activity.title).toList(), [
        'Past Quiz',
        'Next Essay',
      ]);
      expect(items.map((item) => item.subjectName).toSet(), {'Chemistry'});
    },
  );

  testWidgets('marks deadline days and lists the chosen day', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'subtrack_fake_auth_email': 'kent@gmail.com',
      'selected_semester:kent@gmail.com': 1,
    });
    final prefs = await SharedPreferences.getInstance();
    final auth = FakeAuthService(prefs: prefs);
    final db = AppDatabase.memory();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authServiceProvider.overrideWithValue(auth),
          databaseProvider.overrideWithValue(db),
          initialLocationProvider.overrideWithValue('/calendar'),
        ],
        child: const SubTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final thisMonthDay = DateTime(now.year, now.month, 15, 9);
    final nextMonthDay = DateTime(now.year, now.month + 1, 10, 9);

    final semesterId = await db
        .into(db.semesters)
        .insert(
          SemestersCompanion.insert(
            term: 'first',
            schoolYear: '2026-2027',
            startDate: DateTime(now.year, 1, 1),
            endDate: DateTime(now.year, 12, 31),
          ),
        );
    final subjectId = await db
        .into(db.subjects)
        .insert(
          SubjectsCompanion.insert(
            semesterId: semesterId,
            name: 'Chemistry',
            color: 0xFF3B4BDB,
          ),
        );
    await db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(
            subjectId: subjectId,
            title: 'Problem Set 3',
            deadline: Value(thisMonthDay),
            status: const Value('final'),
          ),
        );
    await db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(
            subjectId: subjectId,
            title: 'Lab Report',
            deadline: Value(nextMonthDay),
          ),
        );
    await db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(
            subjectId: subjectId,
            title: 'No deadline draft',
          ),
        );
    await db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(
            subjectId: subjectId,
            title: 'Archived thing',
            deadline: Value(DateTime(now.year, now.month, 15, 10)),
            isArchived: const Value(true),
          ),
        );
    await tester.pumpAndSettle();

    // The current month, its deadline marker, and the bottom bar.
    expect(find.text(DateFormat('MMMM yyyy').format(now)), findsOneWidget);
    expect(find.text('2 deadlines'), findsOneWidget);
    expect(find.byKey(ValueKey(calendarDayKey(thisMonthDay))), findsOneWidget);
    expect(find.byKey(calendarMarkerKey(thisMonthDay)), findsOneWidget);
    expect(find.byKey(calendarMarkerKey(nextMonthDay)), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);

    // A chosen day lists only that day's activity, with its subject and
    // status; archived activities never show.
    await tester.tap(find.byKey(ValueKey(calendarDayKey(thisMonthDay))));
    await tester.pumpAndSettle();
    expect(find.text('Problem Set 3'), findsOneWidget);
    expect(find.text('Chemistry'), findsOneWidget);
    expect(find.text('Final'), findsOneWidget);
    expect(find.text('Lab Report'), findsNothing);
    expect(find.text('Archived thing'), findsNothing);
    expect(find.text('No deadline draft'), findsNothing);

    // Away from a month with no selection, the hint shows; the next month
    // carries its own marker and day list.
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(
      find.text(DateFormat('MMMM yyyy').format(nextMonthDay)),
      findsOneWidget,
    );
    expect(find.text('Tap a day to see its deadlines.'), findsOneWidget);
    expect(find.byKey(calendarMarkerKey(nextMonthDay)), findsOneWidget);

    await tester.tap(find.byKey(ValueKey(calendarDayKey(nextMonthDay))));
    await tester.pumpAndSettle();
    expect(find.text('Lab Report'), findsOneWidget);
    expect(find.text('Problem Set 3'), findsNothing);

    await db.close();
  });
}
