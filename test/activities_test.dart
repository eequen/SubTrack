import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/features/activities/activity_providers.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/features/subjects/subject_providers.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthService(prefs: prefs);
  await auth.signIn(identifier: 'maria@school.edu', password: 'secret');
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

Future<int> _subject(ProviderContainer c, int semesterId) {
  return c
      .read(subjectRepoProvider)
      .create(semesterId: semesterId, name: 'CP1', color: 0xFF3B4BDB);
}

Future<int> _activity(
  ProviderContainer c,
  int subjectId,
  String title, {
  DateTime? deadline,
  String status = 'draft',
  bool archived = false,
}) async {
  final id = await c
      .read(activityRepoProvider)
      .create(
        subjectId: subjectId,
        title: title,
        deadline: deadline,
        status: status,
      );
  if (archived) {
    await c.read(activityRepoProvider).setArchived(id, true);
  }
  return id;
}

void main() {
  test(
    'create validates title and status; updates write non-null fields',
    () async {
      final c = await _container();
      final semesterId = await _semester(c);
      final subjectId = await _subject(c, semesterId);
      final repo = c.read(activityRepoProvider);

      await expectLater(
        repo.create(subjectId: subjectId, title: '  '),
        throwsArgumentError,
      );
      await expectLater(
        repo.create(subjectId: subjectId, title: 'Lab', status: 'weird'),
        throwsArgumentError,
      );

      final id = await repo.create(
        subjectId: subjectId,
        title: '  Lab report  ',
      );
      var item = (await repo.watchWithCounts(subjectId).first).single;
      expect(item.activity.title, 'Lab report');
      expect(item.activity.status, 'draft');
      expect(item.activity.deadline, isNull);

      await expectLater(
        repo.updateDetails(id: id, title: '   '),
        throwsArgumentError,
      );
      await expectLater(
        repo.updateDetails(id: id, status: 'nope'),
        throwsArgumentError,
      );

      await repo.updateDetails(id: id, title: 'Lab 2', status: 'final');
      item = (await repo.watchWithCounts(subjectId).first).single;
      expect(item.activity.title, 'Lab 2');
      expect(item.activity.status, 'final');
      expect(item.activity.deadline, isNull, reason: 'null means unchanged');

      final due = DateTime(2026, 11, 3);
      await repo.setDeadline(id, due);
      expect(
        (await repo.watchWithCounts(subjectId).first).single.activity.deadline,
        due,
      );
      await repo.setDeadline(id, null);
      expect(
        (await repo.watchWithCounts(subjectId).first).single.activity.deadline,
        isNull,
      );
    },
  );

  test(
    'cards report file count and latest version, newest activity first',
    () async {
      final c = await _container();
      final db = c.read(databaseProvider);
      final semesterId = await _semester(c);
      final subjectId = await _subject(c, semesterId);
      final repo = c.read(activityRepoProvider);

      final firstId = await _activity(c, subjectId, 'Lab report');
      final secondId = await _activity(c, subjectId, 'Quiz');

      final fileId = await db
          .into(db.files)
          .insert(
            FilesCompanion.insert(activityId: firstId, displayName: 'a.txt'),
          );
      for (final version in [1, 2, 3]) {
        await db
            .into(db.commits)
            .insert(
              CommitsCompanion.insert(
                fileId: fileId,
                versionNo: version,
                message: 'v$version',
                blobHash: 'hash$version',
                sizeBytes: 10 * version,
              ),
            );
      }

      final items = await repo.watchWithCounts(subjectId).first;
      expect(items.map((i) => i.activity.id), [secondId, firstId]);
      expect(items.first.fileCount, 0);
      expect(items.first.latestVersion, isNull);
      expect(items.last.fileCount, 1);
      expect(items.last.latestVersion, 3);
    },
  );

  test('delete removes the activity and cascades files and commits', () async {
    final c = await _container();
    final db = c.read(databaseProvider);
    final semesterId = await _semester(c);
    final subjectId = await _subject(c, semesterId);
    final activityId = await _activity(c, subjectId, 'Lab report');

    final fileId = await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(activityId: activityId, displayName: 'a.txt'),
        );
    await db
        .into(db.commits)
        .insert(
          CommitsCompanion.insert(
            fileId: fileId,
            versionNo: 1,
            message: 'v1',
            blobHash: 'h1',
            sizeBytes: 10,
          ),
        );

    await c.read(activityRepoProvider).delete(activityId);

    expect(await db.select(db.activities).get(), isEmpty);
    expect(await db.select(db.files).get(), isEmpty);
    expect(await db.select(db.commits).get(), isEmpty);
    expect(await db.select(db.subjects).get(), hasLength(1));
  });

  test(
    'upcoming deadlines: future, active, this semester, nearest first',
    () async {
      final c = await _container();
      final semesterA = await _semester(c);
      final semesterB = await c
          .read(semesterRepoProvider)
          .create(
            term: 'second',
            schoolYear: '2026-2027',
            startDate: DateTime(2026, 12, 20),
            endDate: DateTime(2027, 4, 30),
          );
      final subjectA = await _subject(c, semesterA);
      final subjectB = await c
          .read(subjectRepoProvider)
          .create(semesterId: semesterB, name: 'PE', color: 0xFF0B7A6B);

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      DateTime inDays(int days) => startOfDay.add(Duration(days: days));

      await _activity(c, subjectA, 'four', deadline: inDays(4));
      final a1 = await _activity(c, subjectA, 'one', deadline: inDays(1));
      final a2 = await _activity(c, subjectA, 'two', deadline: inDays(2));
      final a3 = await _activity(c, subjectA, 'three', deadline: inDays(3));
      await _activity(c, subjectA, 'past', deadline: inDays(-1));
      await _activity(c, subjectA, 'no deadline');
      await _activity(
        c,
        subjectA,
        'archived',
        deadline: inDays(1),
        archived: true,
      );
      await _activity(c, subjectB, 'other semester', deadline: inDays(1));

      final repo = c.read(activityRepoProvider);
      final upcoming = await repo.watchUpcoming(semesterA, limit: 3).first;
      expect(upcoming.map((u) => u.activity.id), [a1, a2, a3]);
      expect(upcoming.first.subjectName, 'CP1');

      final forB = await repo.watchUpcoming(semesterB).first;
      expect(forB, hasLength(1));
      expect(forB.single.subjectName, 'PE');
    },
  );
}
