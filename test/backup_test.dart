import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/backup_repo.dart';
import 'package:subtrack/data/repositories/commit_repo.dart';
import 'package:subtrack/data/repositories/file_repo.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';
import 'package:subtrack/data/storage/blob_store.dart';

void main() {
  /// A fake "device": an in-memory database and a temp blob root.
  Future<(AppDatabase, BlobStore, Directory)> device(String prefix) async {
    final tmp = await Directory.systemTemp.createTemp(prefix);
    addTearDown(() async {
      if (await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    });
    final db = AppDatabase.memory();
    addTearDown(db.close);
    return (db, BlobStore(Future.value(tmp)), tmp);
  }

  /// One semester > CP1 > Thesis > thesis.txt with v1 and v2.
  Future<int> seedThesis(AppDatabase db, BlobStore blobs) async {
    final semesterId = await SemesterRepo(db).create(
      term: 'first',
      schoolYear: '2026-2027',
      startDate: DateTime(2026, 8, 18),
      endDate: DateTime(2026, 12, 19),
    );
    final subjectId = await SubjectRepo(db)
        .create(semesterId: semesterId, name: 'CP1', color: 0xFF3B4BDB);
    final activityId = await db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(subjectId: subjectId, title: 'Thesis'),
        );
    final fileId = await FileRepo(db, blobs).upload(
      activityId: activityId,
      bytes: Uint8List.fromList('v1 content'.codeUnits),
      displayName: 'thesis.txt',
    );
    final hash = await blobs.saveBytes(
      Uint8List.fromList('v2 content'.codeUnits),
    );
    await CommitRepo(db).create(
      fileId: fileId,
      versionNo: 2,
      message: 'Second draft',
      blobHash: hash,
      sizeBytes: 10,
      mimeType: 'text/plain',
    );
    return fileId;
  }

  /// Different data that an import must fully replace.
  Future<void> seedOther(AppDatabase db) async {
    final semesterId = await SemesterRepo(db).create(
      term: 'second',
      schoolYear: '2025-2026',
      startDate: DateTime(2025, 1, 20),
      endDate: DateTime(2025, 5, 30),
    );
    final subjectId = await SubjectRepo(db)
        .create(semesterId: semesterId, name: 'Math', color: 0xFF0B7A6B);
    await db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(
            subjectId: subjectId,
            title: 'Problem set 1',
          ),
        );
  }

  test(
    'export and import round-trip recreates everything on a fresh device',
    () async {
      final (db1, blobs1, tmp1) = await device('subtrack_backup_src');
      final fileId = await seedThesis(db1, blobs1);
      final repo1 = BackupRepo(db1, blobs1, Future.value(tmp1));
      final zip = await repo1.export();
      expect(await zip.exists(), isTrue);
      expect(zip.path, endsWith('.zip'));

      // A fresh device: empty database, no blobs.
      final (db2, blobs2, tmp2) = await device('subtrack_backup_dst');
      final repo2 = BackupRepo(db2, blobs2, Future.value(tmp2));

      final zipBytes = await zip.readAsBytes();
      final contents = await repo2.validate(zipBytes);
      expect(contents.semesters, 1);
      expect(contents.subjects, 1);
      expect(contents.activities, 1);
      expect(contents.files, 1);
      expect(contents.commits, 2);

      await repo2.import(zipBytes);

      final semesters = await db2.select(db2.semesters).get();
      expect(semesters.single.schoolYear, '2026-2027');
      final subjects = await db2.select(db2.subjects).get();
      expect(subjects.single.name, 'CP1');
      final activities = await db2.select(db2.activities).get();
      expect(activities.single.title, 'Thesis');
      final files = await db2.select(db2.files).get();
      // Row ids are preserved, so references stay intact.
      expect(files.single.id, fileId);
      final commits = await (db2.select(
        db2.commits,
      )..orderBy([(c) => OrderingTerm.desc(c.versionNo)])).get();
      expect(commits.length, 2);
      expect(commits.first.message, 'Second draft');
      expect(commits.first.versionNo, 2);
      expect(commits.last.message, 'Initial version');
      // The blob contents survive (all versions, not just the latest).
      expect(
        String.fromCharCodes(await blobs2.read(commits.first.blobHash)),
        'v2 content',
      );
      expect(
        String.fromCharCodes(await blobs2.read(commits.last.blobHash)),
        'v1 content',
      );
      // current_commit_id still points at the latest version.
      expect(files.single.currentCommitId, commits.first.id);
    },
  );

  test('rejects a zip with unexpected entries', () async {
    final (db, blobs, tmp) = await device('subtrack_backup_bad');
    await seedThesis(db, blobs);
    final repo = BackupRepo(db, blobs, Future.value(tmp));

    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          'subtrack.sqlite',
          Uint8List.fromList('not a database'.codeUnits),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          'blobs/deadbeef',
          Uint8List.fromList('short hash'.codeUnits),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          'blobs/../../evil',
          Uint8List.fromList('path traversal'.codeUnits),
        ),
      );
    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));

    await expectLater(
      repo.validate(zipBytes),
      throwsA(isA<InvalidBackupException>()),
    );
  });

  test('rejects and refuses to import a backup with a damaged blob', () async {
    final (db1, blobs1, tmp1) = await device('subtrack_backup_src');
    await seedThesis(db1, blobs1);
    final repo1 = BackupRepo(db1, blobs1, Future.value(tmp1));

    // Real export, with every blob replaced by other content.
    final decoded = ZipDecoder().decodeBytes(
      await repo1.export().then((f) => f.readAsBytes()),
    );
    final tampered = Archive();
    for (final file in decoded.files) {
      tampered.addFile(
        file.name.startsWith('blobs/')
            ? ArchiveFile.bytes(
                file.name,
                Uint8List.fromList('tampered'.codeUnits),
              )
            : ArchiveFile.bytes(file.name, file.content),
      );
    }
    final zipBytes = Uint8List.fromList(ZipEncoder().encode(tampered));

    final (db2, blobs2, tmp2) = await device('subtrack_backup_dst');
    final repo2 = BackupRepo(db2, blobs2, Future.value(tmp2));
    await expectLater(
      repo2.validate(zipBytes),
      throwsA(isA<InvalidBackupException>()),
    );
    // Import refuses before wiping anything.
    await expectLater(
      repo2.import(zipBytes),
      throwsA(isA<InvalidBackupException>()),
    );
    expect((await db2.select(db2.commits).get()), isEmpty);
  });

  test('rejects a backup that is missing file contents', () async {
    final (db1, blobs1, tmp1) = await device('subtrack_backup_src');
    await seedThesis(db1, blobs1);
    final repo1 = BackupRepo(db1, blobs1, Future.value(tmp1));
    final decoded = ZipDecoder().decodeBytes(
      await repo1.export().then((f) => f.readAsBytes()),
    );
    final dbEntry = decoded.files.firstWhere(
      (f) => f.name == 'subtrack.sqlite',
    );

    // A fresh device has none of the blobs, so metadata alone is not enough.
    final (db2, blobs2, tmp2) = await device('subtrack_backup_dst');
    final repo2 = BackupRepo(db2, blobs2, Future.value(tmp2));
    final stripped = Archive()
      ..addFile(ArchiveFile.bytes('subtrack.sqlite', dbEntry.content));
    final zipBytes = Uint8List.fromList(ZipEncoder().encode(stripped));

    await expectLater(
      repo2.validate(zipBytes),
      throwsA(isA<InvalidBackupException>()),
    );
  });

  test('import replaces data that is already on the device', () async {
    final (db1, blobs1, tmp1) = await device('subtrack_backup_src');
    await seedThesis(db1, blobs1);
    final repo1 = BackupRepo(db1, blobs1, Future.value(tmp1));
    final zipBytes = await repo1.export().then((f) => f.readAsBytes());

    final (db2, blobs2, tmp2) = await device('subtrack_backup_dst');
    await seedOther(db2);
    final repo2 = BackupRepo(db2, blobs2, Future.value(tmp2));
    await repo2.import(zipBytes);

    final semesters = await db2.select(db2.semesters).get();
    expect(semesters.single.schoolYear, '2026-2027');
    final subjects = await db2.select(db2.subjects).get();
    expect(subjects.single.name, 'CP1');
    final activities = await db2.select(db2.activities).get();
    expect(activities.single.title, 'Thesis');
    expect((await db2.select(db2.commits).get()).length, 2);
  });
}
