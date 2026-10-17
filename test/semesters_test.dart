import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthService(prefs: prefs);
  await auth.signIn(email: 'maria@school.edu', password: 'secret');
  final db = AppDatabase.memory();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authServiceProvider.overrideWithValue(auth),
      databaseProvider.overrideWithValue(db),
    ],
  );
  addTearDown(() async {
    await db.close();
    container.dispose();
  });
  return container;
}

Future<int> _semester(ProviderContainer c) {
  return c
      .read(semesterRepoProvider)
      .create(
        term: 'first',
        schoolYear: '2026-2027',
        startDate: DateTime(2026, 8, 18),
        endDate: DateTime(2026, 12, 19),
      );
}

void main() {
  test('create lists with counts and rejects end before start', () async {
    final c = await _container();

    final id = await _semester(c);
    final items = await c.read(semesterRepoProvider).watchAllWithCounts().first;
    expect(items.length, 1);
    expect(items.first.semester.id, id);
    expect(items.first.subjectCount, 0);
    expect(items.first.fileCount, 0);

    await expectLater(
      c
          .read(semesterRepoProvider)
          .create(
            term: 'second',
            schoolYear: '2026-2027',
            startDate: DateTime(2026, 12, 19),
            endDate: DateTime(2026, 8, 18),
          ),
      throwsArgumentError,
    );
  });

  test('counts roll up through subjects, activities, and files', () async {
    final c = await _container();
    final db = c.read(databaseProvider);

    final semesterId = await _semester(c);
    final subjectId = await db
        .into(db.subjects)
        .insert(
          SubjectsCompanion.insert(
            semesterId: semesterId,
            name: 'CP1',
            color: 0,
          ),
        );
    final activityId = await db
        .into(db.activities)
        .insert(ActivitiesCompanion.insert(subjectId: subjectId, title: 'Lab'));
    await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(activityId: activityId, displayName: 'a.txt'),
        );

    final items = await c.read(semesterRepoProvider).watchAllWithCounts().first;
    expect(items.first.subjectCount, 1);
    expect(items.first.fileCount, 1);
  });

  test('last chosen semester persists per user', () async {
    final c = await _container();

    expect(c.read(selectedSemesterProvider), isNull);
    await c.read(selectedSemesterProvider.notifier).select(7);
    expect(c.read(selectedSemesterProvider), 7);
  });
}
