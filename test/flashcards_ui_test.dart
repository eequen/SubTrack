import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/app.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';

import 'helpers.dart';

class _Fixture {
  const _Fixture({
    required this.db,
    required this.semesterId,
    required this.subjectId,
  });

  final AppDatabase db;
  final int semesterId;
  final int subjectId;
}

Future<_Fixture> _pumpApp(
  WidgetTester tester, {
  required String location,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    'subtrack_fake_auth_email': 'kent@gmail.com',
  });
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.memory();
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
          name: 'Biology',
          color: 0xFF0B7A6B,
        ),
      );
  await prefs.setInt('selected_semester:kent@gmail.com', semesterId);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(FakeAuthService(prefs: prefs)),
        databaseProvider.overrideWithValue(db),
        initialLocationProvider.overrideWithValue(location),
      ],
      child: const SubTrackApp(),
    ),
  );
  await tester.pumpAndSettle();
  return _Fixture(db: db, semesterId: semesterId, subjectId: subjectId);
}

void main() {
  testWidgets('the centre menu opens flashcards, file manager, and calendar', (
    tester,
  ) async {
    final fixture = await _pumpApp(tester, location: '/home');

    await tester.tap(find.byKey(const Key('nav-menu')));
    await tester.pumpAndSettle();
    for (final label in [
      'Subjects',
      'Calendar',
      'Profile',
      'Flashcards',
      'File manager',
    ]) {
      expect(find.text(label), findsWidgets);
    }

    await tester.tap(find.text('Flashcards'));
    await tester.pumpAndSettle();
    expect(find.text('Flashcards'), findsOneWidget);
    expect(find.text('No flashcards yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('File manager'));
    await tester.pumpAndSettle();
    expect(find.text('File manager'), findsOneWidget);
    expect(find.text('Biology'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Calendar'), findsOneWidget); // page title

    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back,'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-cloud')));
    await tester.pumpAndSettle();
    expect(find.text('Cloud backup'), findsOneWidget);

    await closeDatabase(tester, fixture.db);
  });

  testWidgets('a lesson folder gets files and keeps activity-only UI hidden', (
    tester,
  ) async {
    final fixture = await _pumpApp(tester, location: '/subjects/1/files');

    expect(find.text('Lessons'), findsOneWidget);
    expect(find.text('Flashcards'), findsOneWidget);
    expect(find.text('Activities'), findsOneWidget);

    await tester.tap(find.text('New lesson folder'));
    await tester.pumpAndSettle();
    expect(find.text('New lesson'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Week 1');
    await tester.tap(find.text('Create lesson'));
    await tester.pumpAndSettle();

    expect(find.text('Week 1'), findsOneWidget);
    expect(find.text('Lesson folder'), findsOneWidget);
    expect(find.text('No files yet.'), findsOneWidget);
    expect(find.text('Draft'), findsNothing);
    expect(find.textContaining('Deadline'), findsNothing);

    final lessons = await fixture.db.select(fixture.db.activities).get();
    expect(lessons, hasLength(1));
    expect(lessons.single.kind, 'lesson');
    expect(lessons.single.status, 'draft');

    await closeDatabase(tester, fixture.db);
  });

  testWidgets('a manual deck can be studied by flipping cards', (tester) async {
    final fixture = await _pumpApp(tester, location: '/flashcards');

    await tester.tap(find.text('New deck'));
    await tester.pumpAndSettle();
    expect(find.text('New deck'), findsNWidgets(2)); // button + dialog title
    await tester.enterText(find.byType(TextField).first, 'Biology cells');
    await tester.tap(find.text('Create deck'));
    await tester.pumpAndSettle();

    expect(find.text('Biology cells'), findsOneWidget);
    expect(find.text('No cards yet'), findsOneWidget);

    await tester.tap(find.text('Add card'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Cell');
    await tester.enterText(find.byType(TextField).at(1), 'Basic unit of life');
    await tester.tap(find.text('Save card'));
    await tester.pumpAndSettle();

    expect(find.text('Cell'), findsOneWidget);
    expect(find.text('Basic unit of life'), findsOneWidget);

    await tester.tap(find.text('Study'));
    await tester.pumpAndSettle();
    expect(find.text('Cell'), findsOneWidget);
    expect(find.text('Basic unit of life'), findsNothing);

    await tester.tap(find.text('Cell'));
    await tester.pumpAndSettle();
    expect(find.text('Basic unit of life'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Biology cells'), findsOneWidget);

    await closeDatabase(tester, fixture.db);
  });

  testWidgets('AI import previews and saves a validated deck', (tester) async {
    final fixture = await _pumpApp(
      tester,
      location: '/flashcards/import?subject=1',
    );

    const reply =
        '{"schema":"subtrack.cards.v1","deck":"Biology cells",'
        '"cards":[{"front":"What is a cell?",'
        '"back":"The basic unit of life."}]}';
    await tester.enterText(find.byType(TextField).first, reply);
    await tester.tap(find.text('Preview cards'));
    await tester.pumpAndSettle();

    expect(find.text('Review import'), findsOneWidget);
    expect(find.text('What is a cell?'), findsOneWidget);
    expect(find.text('The basic unit of life.'), findsOneWidget);

    await tester.tap(find.text('Save deck'));
    await tester.pumpAndSettle();
    expect(find.text('Biology cells'), findsOneWidget);
    expect(find.text('1 card'), findsOneWidget);

    final deck = (await fixture.db.select(fixture.db.decks).get()).single;
    expect(deck.source, 'ai_import');
    expect(deck.subjectId, fixture.subjectId);
    expect((await fixture.db.select(fixture.db.cards).get()), hasLength(1));

    await closeDatabase(tester, fixture.db);
  });
}
