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
import 'package:subtrack/shared/chips.dart';
import 'package:subtrack/shared/status_sheet.dart';

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
  final addButton = find.widgetWithText(TextButton, 'New activity');
  if (addButton.evaluate().isNotEmpty) {
    await tester.tap(addButton);
  } else {
    await tester.tap(find.text('Add your first activity'));
  }
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
    expect(find.text('Add your first activity'), findsOneWidget);

    await _createActivity(tester, title: 'Lab report', statusLabel: 'Final');
    expect(find.text('Lab report'), findsOneWidget);
    expect(find.text('1 activity'), findsOneWidget);
    expect(find.text('Recent changes haven’t been backed up'), findsOneWidget);
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

    await tester.tap(find.text('Add your first activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create activity'));
    await tester.pumpAndSettle();

    expect(find.text('Activity title is required.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('New activity'),
      ),
      findsOneWidget,
    );

    await db.close();
    await tester.pump();
  });

  testWidgets('delete warns when recent activity changes are unbacked', (
    tester,
  ) async {
    final db = await _pumpActivities(tester);
    await _createActivity(tester, title: 'Lab report');

    await tester.tap(find.byTooltip('Activity actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Recent changes have not been backed up.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await db.close();
    await tester.pump();
  });

  testWidgets('status chip opens the status sheet and updates immediately', (
    tester,
  ) async {
    final db = await _pumpActivities(tester);
    await _createActivity(tester, title: 'Lab report');

    expect(tester.getSize(find.byType(StatusChip)).height, lessThan(44));
    await tester.tap(find.byType(StatusChip));
    await tester.pumpAndSettle();
    expect(find.text('Set status'), findsOneWidget);

    final sheet = find.byType(StatusSheet);
    await tester.tap(find.descendant(of: sheet, matching: find.text('Final')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(StatusChip, 'Final'), findsOneWidget);
    await db.close();
    await tester.pump();
  });
}
