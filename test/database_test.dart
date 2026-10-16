import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:subtrack/data/db/app_database.dart';

Future<int> _seedChain(AppDatabase db) async {
  final semesterId = await db
      .into(db.semesters)
      .insert(
        SemestersCompanion.insert(
          term: 'first',
          schoolYear: '2026-2027',
          startDate: DateTime(2026, 8, 18),
          endDate: DateTime(2026, 12, 19),
        ),
      );
  final subjectId = await db
      .into(db.subjects)
      .insert(
        SubjectsCompanion.insert(
          semesterId: semesterId,
          name: 'Computer Programming 1',
          color: 0xFF3B4BDB,
        ),
      );
  final activityId = await db
      .into(db.activities)
      .insert(
        ActivitiesCompanion.insert(
          subjectId: subjectId,
          title: 'Midterm Project',
        ),
      );
  final fileId = await db
      .into(db.files)
      .insert(
        FilesCompanion.insert(
          activityId: activityId,
          displayName: 'ProjectReport.docx',
        ),
      );
  final commitId = await db
      .into(db.commits)
      .insert(
        CommitsCompanion.insert(
          fileId: fileId,
          versionNo: 1,
          message: 'First draft',
          blobHash: 'abc123',
          sizeBytes: 1024,
        ),
      );
  await (db.update(db.files)..where((f) => f.id.equals(fileId))).write(
    FilesCompanion(currentCommitId: Value(commitId)),
  );
  return semesterId;
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() => db.close());

  test('in-memory database opens and stores the full chain', () async {
    await _seedChain(db);

    expect((await db.select(db.semesters).get()).length, 1);
    expect((await db.select(db.subjects).get()).length, 1);
    expect((await db.select(db.activities).get()).length, 1);

    final file = await (db.select(db.files)).getSingle();
    expect(file.displayName, 'ProjectReport.docx');
    expect(file.currentCommitId, isNotNull);

    final commit = await (db.select(db.commits)).getSingle();
    expect(commit.versionNo, 1);
    expect(commit.message, 'First draft');
  });

  test('deleting a semester cascades through the hierarchy', () async {
    final semesterId = await _seedChain(db);

    await (db.delete(db.semesters)..where((s) => s.id.equals(semesterId))).go();

    expect(await db.select(db.semesters).get(), isEmpty);
    expect(await db.select(db.subjects).get(), isEmpty);
    expect(await db.select(db.activities).get(), isEmpty);
    expect(await db.select(db.files).get(), isEmpty);
    expect(await db.select(db.commits).get(), isEmpty);
  });
}
