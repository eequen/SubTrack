import 'package:flutter_test/flutter_test.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/activity_repo.dart';
import 'package:subtrack/data/repositories/commit_repo.dart';
import 'package:subtrack/data/repositories/search_repo.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';

void main() {
  late AppDatabase db;
  late SearchRepo repo;
  late int semesterId;
  late int otherSemesterId;
  late int labActivityId;
  late int thesisFileId;
  late int reportFileId;
  late int psetFileId;
  late int otherThesisFileId;

  setUp(() async {
    db = AppDatabase.memory();
    repo = SearchRepo(db);

    final semesters = SemesterRepo(db);
    semesterId = await semesters.create(
      term: 'first',
      schoolYear: '2026-2027',
      startDate: DateTime(2026, 8, 18),
      endDate: DateTime(2026, 12, 19),
    );
    otherSemesterId = await semesters.create(
      term: 'second',
      schoolYear: '2026-2027',
      startDate: DateTime(2027, 1, 11),
      endDate: DateTime(2027, 5, 29),
    );

    final subjects = SubjectRepo(db);
    final commits = CommitRepo(db);

    // Chosen semester: CP1 has Thesis (thesis.txt, v1 and v2) and Lab 3
    // (report.pdf); Math has Problem set 1 (pset1.txt).
    final cp1 = await subjects.create(
      semesterId: semesterId,
      name: 'CP1',
      color: 0xFF3B4BDB,
    );
    final thesis = await db
        .into(db.activities)
        .insert(ActivitiesCompanion.insert(subjectId: cp1, title: 'Thesis'));
    thesisFileId = await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(activityId: thesis, displayName: 'thesis.txt'),
        );
    await commits.create(
      fileId: thesisFileId,
      versionNo: 1,
      message: 'Initial version',
      blobHash: 'h1',
      sizeBytes: 10,
      mimeType: 'text/plain',
    );
    await commits.create(
      fileId: thesisFileId,
      versionNo: 2,
      message: 'Second draft',
      blobHash: 'h2',
      sizeBytes: 12,
      mimeType: 'text/plain',
    );

    labActivityId = await db
        .into(db.activities)
        .insert(ActivitiesCompanion.insert(subjectId: cp1, title: 'Lab 3'));
    reportFileId = await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            activityId: labActivityId,
            displayName: 'report.pdf',
          ),
        );
    await commits.create(
      fileId: reportFileId,
      versionNo: 1,
      message: 'Lab report final',
      blobHash: 'h3',
      sizeBytes: 20,
      mimeType: 'application/pdf',
    );

    final math = await subjects.create(
      semesterId: semesterId,
      name: 'Math',
      color: 0xFF0B7A6B,
    );
    final pset = await db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(subjectId: math, title: 'Problem set 1'),
        );
    psetFileId = await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(activityId: pset, displayName: 'pset1.txt'),
        );
    await commits.create(
      fileId: psetFileId,
      versionNo: 1,
      message: 'Answers done',
      blobHash: 'h4',
      sizeBytes: 8,
      mimeType: 'text/plain',
    );

    // Another semester repeats the names, to prove search is scoped.
    final cp1B = await subjects.create(
      semesterId: otherSemesterId,
      name: 'CP1',
      color: 0xFF3B4BDB,
    );
    final thesisB = await db
        .into(db.activities)
        .insert(ActivitiesCompanion.insert(subjectId: cp1B, title: 'Thesis'));
    otherThesisFileId = await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(activityId: thesisB, displayName: 'thesis.txt'),
        );
    await commits.create(
      fileId: otherThesisFileId,
      versionNo: 1,
      message: 'Initial version',
      blobHash: 'h5',
      sizeBytes: 9,
      mimeType: 'text/plain',
    );
  });

  tearDown(() => db.close());

  test('finds nothing for an empty query', () async {
    expect((await repo.search(semesterId, '   ')).isEmpty, isTrue);
  });

  test('finds files, activities, and commits with their path', () async {
    final results = await repo.search(semesterId, 'thesis');

    expect(results.files.map((f) => f.file.id), [thesisFileId]);
    expect(results.files.single.subjectName, 'CP1');
    expect(results.files.single.activityTitle, 'Thesis');

    expect(results.activities.map((a) => a.activity.title), ['Thesis']);
    expect(results.activities.single.subjectName, 'CP1');

    // Commits match through their file name, newest first.
    expect(results.commits.map((c) => c.commit.message), [
      'Second draft',
      'Initial version',
    ]);
    expect(results.commits.first.fileName, 'thesis.txt');
    expect(results.commits.first.activityTitle, 'Thesis');
    expect(results.commits.first.subjectName, 'CP1');
  });

  test('ignores case', () async {
    final lower = await repo.search(semesterId, 'thesis');
    final upper = await repo.search(semesterId, 'THESIS');
    expect(upper.files.length, lower.files.length);
    expect(upper.commits.length, lower.commits.length);
    expect(upper.files.single.file.id, lower.files.single.file.id);
  });

  test('matches commit messages', () async {
    final results = await repo.search(semesterId, 'second draft');
    expect(results.files, isEmpty);
    expect(results.activities, isEmpty);
    expect(results.commits.single.commit.message, 'Second draft');
    expect(results.commits.single.commit.versionNo, 2);
  });

  test('matches activities and their content by title', () async {
    final results = await repo.search(semesterId, 'lab');
    expect(results.activities.single.activity.id, labActivityId);
    expect(results.files.single.file.id, reportFileId);
    expect(results.commits.single.commit.message, 'Lab report final');
  });

  test('matches everything under a subject name', () async {
    final results = await repo.search(semesterId, 'math');
    expect(results.activities.single.activity.title, 'Problem set 1');
    expect(results.files.single.file.id, psetFileId);
    expect(results.commits.single.commit.message, 'Answers done');
  });

  test('only searches the chosen semester', () async {
    final first = await repo.search(semesterId, 'thesis');
    expect(first.commits.map((c) => c.commit.blobHash), ['h2', 'h1']);
    expect(first.files.single.file.id, thesisFileId);

    final second = await repo.search(otherSemesterId, 'thesis');
    expect(second.commits.single.commit.blobHash, 'h5');
    expect(second.files.single.file.id, otherThesisFileId);
  });

  test('lists files and commits newest first', () async {
    final results = await repo.search(semesterId, 'txt');
    expect(results.activities, isEmpty);
    expect(results.files.map((f) => f.file.id), [psetFileId, thesisFileId]);
    expect(results.commits.map((c) => c.commit.message), [
      'Answers done',
      'Second draft',
      'Initial version',
    ]);
  });

  test('caps each section at limit', () async {
    final results = await repo.search(semesterId, 'txt', limit: 1);
    expect(results.files.single.file.id, psetFileId);
    expect(results.commits.single.commit.message, 'Answers done');
  });

  test('still finds archived activities', () async {
    await ActivityRepo(db).setArchived(labActivityId, true);
    final results = await repo.search(semesterId, 'lab');
    expect(results.activities.single.activity.id, labActivityId);
  });
}
