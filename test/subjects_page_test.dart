import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/app.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';

Future<AppDatabase> _pumpSubjects(WidgetTester tester) async {
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
  await prefs.setInt('selected_semester:maria@school.edu', semesterId);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(auth),
        databaseProvider.overrideWithValue(db),
        initialLocationProvider.overrideWithValue('/subjects'),
      ],
      child: const SubTrackApp(),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

void main() {
  testWidgets('create a subject and rename it from the subject card', (
    tester,
  ) async {
    final db = await _pumpSubjects(tester);

    expect(
      find.text('1st Semester - SY 2026-2027\nMy Subjects'),
      findsOneWidget,
    );
    expect(find.text('No subjects yet.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, '+ New subject'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'CP1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create subject'));
    await tester.pumpAndSettle();

    expect(find.text('CP1'), findsOneWidget);
    expect(find.text('0 activities - 0 files'), findsOneWidget);

    await tester.tap(find.byTooltip('Subject actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'CP10');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('CP10'), findsOneWidget);
    expect(find.text('CP1'), findsNothing);

    await db.close();
    await tester.pump();
  });

  testWidgets('empty name in the dialog shows an error and stays open', (
    tester,
  ) async {
    final db = await _pumpSubjects(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, '+ New subject'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create subject'));
    await tester.pumpAndSettle();

    expect(find.text('Subject name is required.'), findsOneWidget);
    expect(find.text('New subject'), findsOneWidget);

    await db.close();
    await tester.pump();
  });
}
