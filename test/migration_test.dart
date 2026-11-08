import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:subtrack/data/db/app_database.dart';

/// Builds a v2-shaped database from the current schema, then reopens it so
/// the real v2 -> v3 migration runs. This protects the data already on the
/// student's phone when the Phase 5B build is installed.
void main() {
  test('v2 restore links become kind + based_on during migration', () async {
    final tmp = await Directory.systemTemp.createTemp('subtrack_migration');
    final file = File(p.join(tmp.path, 'subtrack.sqlite'));
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    // 1. Create the current schema and seed a small history.
    var db = AppDatabase(NativeDatabase(file));
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
            name: 'CP1',
            color: 0xFF3B4BDB,
          ),
        );
    final activityId = await db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(subjectId: subjectId, title: 'Thesis'),
        );
    final fileId = await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            activityId: activityId,
            displayName: 'thesis.txt',
          ),
        );
    final v1 = await db
        .into(db.commits)
        .insert(
          CommitsCompanion.insert(
            fileId: fileId,
            versionNo: 1,
            message: 'Initial version',
            blobHash: 'a' * 64,
            sizeBytes: 3,
            mimeType: const Value('text/plain'),
            kind: const Value('upload'),
          ),
        );
    final v2 = await db
        .into(db.commits)
        .insert(
          CommitsCompanion.insert(
            fileId: fileId,
            versionNo: 2,
            message: 'Restored from v1',
            blobHash: 'a' * 64,
            sizeBytes: 3,
            mimeType: const Value('text/plain'),
            kind: const Value('restore'),
            basedOnCommitId: Value(v1),
          ),
        );

    // 2. Rewind the commits table to the v2 shape.
    await db.customStatement(
      'ALTER TABLE commits ADD COLUMN restored_from_commit_id INTEGER',
    );
    await db.customStatement(
      'UPDATE commits SET restored_from_commit_id = ? WHERE id = ?',
      [v1, v2],
    );
    await db.customStatement('ALTER TABLE commits DROP COLUMN kind');
    await db.customStatement(
      'ALTER TABLE commits DROP COLUMN based_on_commit_id',
    );
    await db.customStatement('DROP TABLE edit_sessions');
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();

    // 3. Reopen: drift runs onUpgrade(from: 2, to: 3).
    db = AppDatabase(NativeDatabase(file));
    final commits = await (db.select(
      db.commits,
    )..orderBy([(c) => OrderingTerm.asc(c.versionNo)])).get();

    expect(commits, hasLength(2));
    expect(commits[0].message, 'Initial version');
    expect(commits[0].kind, 'upload');
    expect(commits[0].basedOnCommitId, isNull);
    expect(commits[1].message, 'Restored from v1');
    expect(commits[1].kind, 'restore');
    expect(commits[1].basedOnCommitId, v1);

    // The working-copy table exists and the old column is gone.
    expect(await db.select(db.editSessions).get(), isEmpty);
    final columns = await db.customSelect('PRAGMA table_info(commits)').get();
    final names = columns.map((row) => row.read<String>('name')).toList();
    expect(names, contains('kind'));
    expect(names, contains('based_on_commit_id'));
    expect(names, isNot(contains('restored_from_commit_id')));

    await db.close();
  });
}
