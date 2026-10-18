import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/app.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';

Future<AppDatabase> _pumpActivities(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthService(prefs: prefs);
  await auth.signIn(identifier: 'maria@school.edu', password: 'secret');
  final db = AppDatabase.memory();
  final semesterId = await SemesterRepo(db).create(
    term: 'first',
    schoolYear: '2026-2027',
    startDate: DateTime(2026, 8, 18),
    endDate: DateTime(2026, 12, 19),
  );
  final subjectId = await SubjectRepo(db)
      .create(semesterId: semesterId, name: 'CP1', color: 0xFF3B4BDB);
  await prefs.setInt('selected_semester:maria@school.edu', semesterId);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(auth),
        databaseProvider.overrideWithValue(db),
        initialLocationProvider.overrideWithValue(
          '/subjects/$subjectId/activities',
        ),
      ],
      child: const SubTrackApp(),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

Future<void> _createActivity(
  WidgetTester tester, {
  required String title,
  String? statusLabel,
}) async {
  await tester.tap(find.widgetWithText(ElevatedButton, '+ New activity'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, title);
  if (statusLabel != null) {
    await tester.tap(find.widgetWithText(ChoiceChip, statusLabel));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.widgetWithText(ElevatedButton, 'Create activity'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('create activities and filter by status', (tester) async {
    final db = await _pumpActivities(tester);

    expect(find.text('CP1'), findsOneWidget);
    expect(find.text('0 activities'), findsOneWidget);
    expect(find.text('No activities yet.'), findsOneWidget);

    await _createActivity(tester, title: 'Lab report', statusLabel: 'Final');
    expect(find.text('Lab report'), findsOneWidget);
    expect(find.text('1 activity'), findsOneWidget);
    expect(find.text('No files yet.'), findsOneWidget);

    await _createActivity(tester, title: 'Quiz');
    expect(find.text('Quiz'), findsOneWidget);
    expect(find.text('2 activities'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Final'));
    await tester.pumpAndSettle();
    expect(find.text('Lab report'), findsOneWidget);
    expect(find.text('Quiz'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.text('Quiz'), findsOneWidget);

    await db.close();
    await tester.pump();
  });

  testWidgets('empty title in the dialog shows an error and stays open', (
    tester,
  ) async {
    final db = await _pumpActivities(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, '+ New activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create activity'));
    await tester.pumpAndSettle();

    expect(find.text('Activity title is required.'), findsOneWidget);
    expect(find.text('New activity'), findsOneWidget);

    await db.close();
    await tester.pump();
  });
}
