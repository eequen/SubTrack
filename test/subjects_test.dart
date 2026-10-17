import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/features/subjects/subject_providers.dart';

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

const _blue = 0xFF3B4BDB;

Future<int> _subject(ProviderContainer c, int semesterId, String name) {
  return c
      .read(subjectRepoProvider)
      .create(semesterId: semesterId, name: name, color: _blue);
}

void main() {
  test('create validates and trims the name; rename validates too', () async {
    final c = await _container();
    final semesterId = await _semester(c);
    final repo = c.read(subjectRepoProvider);

    await expectLater(
      repo.create(semesterId: semesterId, name: '   ', color: _blue),
      throwsArgumentError,
    );

    final id = await repo.create(
      semesterId: semesterId,
      name: '  CP1  ',
      color: _blue,
    );
    var items = await repo.watchWithCounts(semesterId).first;
    expect(items.single.subject.name, 'CP1');

    await expectLater(repo.rename(id, ''), throwsArgumentError);
    await repo.rename(id, ' CP10 ');
    items = await repo.watchWithCounts(semesterId).first;
    expect(items.single.subject.name, 'CP10');
  });

  test('counts roll up activities and files; archived sort last', () async {
    final c = await _container();
    final db = c.read(databaseProvider);
    final semesterId = await _semester(c);
    final repo = c.read(subjectRepoProvider);

    final alphaId = await _subject(c, semesterId, 'Alpha');
    final betaId = await _subject(c, semesterId, 'Beta');

    final activityId = await db
        .into(db.activities)
        .insert(ActivitiesCompanion.insert(subjectId: alphaId, title: 'Lab'));
    await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(activityId: activityId, displayName: 'a.txt'),
        );

    var items = await repo.watchWithCounts(semesterId).first;
    expect(items.map((i) => i.subject.name), ['Alpha', 'Beta']);
    expect(items.first.activityCount, 1);
    expect(items.first.fileCount, 1);
    expect(items.last.activityCount, 0);

    await repo.setArchived(alphaId, true);
    items = await repo.watchWithCounts(semesterId).first;
    expect(items.map((i) => i.subject.name), ['Beta', 'Alpha']);
    expect(items.last.subject.isArchived, isTrue);

    await repo.setArchived(betaId, false);
    expect((await repo.watchWithCounts(semesterId).first).length, 2);
  });

  test(
    'delete removes the subject and cascades its activities and files',
    () async {
      final c = await _container();
      final db = c.read(databaseProvider);
      final semesterId = await _semester(c);
      final subjectId = await _subject(c, semesterId, 'CP1');

      final activityId = await db
          .into(db.activities)
          .insert(
            ActivitiesCompanion.insert(subjectId: subjectId, title: 'Lab'),
          );
      await db
          .into(db.files)
          .insert(
            FilesCompanion.insert(activityId: activityId, displayName: 'a.txt'),
          );

      await c.read(subjectRepoProvider).delete(subjectId);

      expect(await db.select(db.subjects).get(), isEmpty);
      expect(await db.select(db.activities).get(), isEmpty);
      expect(await db.select(db.files).get(), isEmpty);
      expect(await db.select(db.semesters).get(), hasLength(1));
    },
  );
}
