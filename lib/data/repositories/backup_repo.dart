import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:subtrack/core/hashing.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/storage/blob_store.dart';

/// Row counts shown in the import confirmation (screen 10).
class BackupContents {
  const BackupContents({
    required this.semesters,
    required this.subjects,
    required this.activities,
    required this.files,
    required this.commits,
  });

  final int semesters;
  final int subjects;
  final int activities;
  final int files;
  final int commits;
}

/// The picked file is not a SubTrack backup, or it is damaged.
class InvalidBackupException implements Exception {
  const InvalidBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What one backup file contains, after validation.
class _BackupPlan {
  const _BackupPlan({
    required this.entries,
    required this.contents,
    required this.semesters,
    required this.subjects,
    required this.activities,
    required this.files,
    required this.commits,
  });

  final Map<String, ArchiveFile> entries;
  final BackupContents contents;
  final List<Semester> semesters;
  final List<Subject> subjects;
  final List<Activity> activities;
  final List<DbFile> files;
  final List<Commit> commits;
}

/// Local backup: the whole database plus every blob as one .zip
/// (AGENTS.md section 9, Phase 4; screen 10).
///
/// Zip layout: `subtrack.sqlite` (a consistent snapshot of the per-user
/// database) and `blobs/<sha256>` for every blob a commit references.
/// Nothing else is accepted on import.
class BackupRepo {
  BackupRepo(this.db, this.blobs, this.root);

  final AppDatabase db;
  final BlobStore blobs;

  /// The same root folder the [BlobStore] lives in; backups go to
  /// `<root>/backups`.
  final Future<Directory> root;

  static const _dbName = 'subtrack.sqlite';
  static final _entryPattern = RegExp(
    r'^(subtrack\.sqlite|blobs/[0-9a-f]{64})$',
  );

  /// Writes a new .zip into `<root>/backups` and returns it.
  Future<File> export() async {
    final dir = await root;
    final backupsDir = Directory(p.join(dir.path, 'backups'));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final zipFile = File(p.join(backupsDir.path, 'subtrack-backup-$stamp.zip'));

    // VACUUM INTO writes a consistent, self-contained snapshot even while
    // the database is open and in use.
    final snapshotPath = p.join(backupsDir.path, 'snapshot-$stamp.sqlite');
    await db.customStatement('VACUUM INTO ?', [snapshotPath]);
    try {
      final archive = Archive();
      archive.addFile(
        ArchiveFile.bytes(_dbName, await File(snapshotPath).readAsBytes()),
      );
      final hashes =
          await (db.selectOnly(db.commits)
                ..addColumns([db.commits.blobHash])
                ..groupBy([db.commits.blobHash]))
              .get();
      for (final row in hashes) {
        final hash = row.read(db.commits.blobHash)!;
        archive.addFile(
          ArchiveFile.bytes('blobs/$hash', await blobs.read(hash)),
        );
      }
      await zipFile.writeAsBytes(ZipEncoder().encode(archive), flush: true);
      return zipFile;
    } finally {
      final snapshot = File(snapshotPath);
      if (await snapshot.exists()) {
        await snapshot.delete();
      }
    }
  }

  /// Checks a backup without touching any data. Throws
  /// [InvalidBackupException] when the file is not a valid backup.
  Future<BackupContents> validate(Uint8List zipBytes) async {
    return (await _plan(zipBytes)).contents;
  }

  /// Imports a validated backup: replaces every row and restores blobs.
  /// The confirmation dialog is the screen's job (AGENTS.md section 9).
  Future<void> import(Uint8List zipBytes) async {
    final plan = await _plan(zipBytes);

    // Blobs first: content verified by _plan, deduped by the BlobStore, so
    // no commit will ever point at a missing blob.
    for (final entry in plan.entries.values) {
      if (entry.name != _dbName) {
        await blobs.saveBytes(entry.content);
      }
    }

    // Replace rows in one transaction, children before parents.
    await db.transaction(() async {
      await db.delete(db.commits).go();
      await db.delete(db.files).go();
      await db.delete(db.activities).go();
      await db.delete(db.subjects).go();
      await db.delete(db.semesters).go();
      for (final semester in plan.semesters) {
        await db.into(db.semesters).insert(semester.toCompanion(true));
      }
      for (final subject in plan.subjects) {
        await db.into(db.subjects).insert(subject.toCompanion(true));
      }
      for (final activity in plan.activities) {
        await db.into(db.activities).insert(activity.toCompanion(true));
      }
      for (final file in plan.files) {
        await db.into(db.files).insert(file.toCompanion(true));
      }
      for (final commit in plan.commits) {
        await db.into(db.commits).insert(commit.toCompanion(true));
      }
    });
  }

  /// Decodes and fully checks a backup file, and reads its rows.
  Future<_BackupPlan> _plan(Uint8List zipBytes) async {
    final archive = _decode(zipBytes);
    final entries = {for (final file in archive.files) file.name: file};

    final dbEntry = entries[_dbName];
    if (dbEntry == null) {
      throw const InvalidBackupException('This file is not a SubTrack backup.');
    }

    // Every blob must carry the content its name promises.
    for (final entry in entries.values) {
      if (entry.name == _dbName) continue;
      final hash = entry.name.substring('blobs/'.length);
      if (sha256Hex(entry.content) != hash) {
        throw const InvalidBackupException('A file in the backup is damaged.');
      }
    }

    final (backupDb, snapshotFile) = await _openSnapshot(dbEntry.content);
    try {
      final List<Semester> semesters;
      final List<Subject> subjects;
      final List<Activity> activities;
      final List<DbFile> files;
      final List<Commit> commits;
      try {
        semesters = await backupDb.select(backupDb.semesters).get();
        subjects = await backupDb.select(backupDb.subjects).get();
        activities = await backupDb.select(backupDb.activities).get();
        files = await backupDb.select(backupDb.files).get();
        commits = await backupDb.select(backupDb.commits).get();
      } on Exception {
        throw const InvalidBackupException('This backup could not be read.');
      }

      // Every blob a commit references must be in the backup or already on
      // this device; otherwise the backup would restore files whose
      // contents are lost.
      for (final commit in commits) {
        final inBackup = entries.containsKey('blobs/${commit.blobHash}');
        if (!inBackup && !await blobs.exists(commit.blobHash)) {
          throw const InvalidBackupException(
            'The backup is missing some file contents.',
          );
        }
      }

      return _BackupPlan(
        entries: entries,
        contents: BackupContents(
          semesters: semesters.length,
          subjects: subjects.length,
          activities: activities.length,
          files: files.length,
          commits: commits.length,
        ),
        semesters: semesters,
        subjects: subjects,
        activities: activities,
        files: files,
        commits: commits,
      );
    } finally {
      await backupDb.close();
      if (await snapshotFile.exists()) {
        await snapshotFile.delete();
      }
    }
  }

  /// Opens the backup's database file from a temporary copy.
  Future<(AppDatabase, File)> _openSnapshot(Uint8List dbBytes) async {
    final dir = await root;
    final tmp = Directory(p.join(dir.path, 'tmp'));
    if (!await tmp.exists()) {
      await tmp.create(recursive: true);
    }
    final snapshotFile = File(
      p.join(
        tmp.path,
        'subtrack-backup-${DateTime.now().microsecondsSinceEpoch}.sqlite',
      ),
    );
    await snapshotFile.writeAsBytes(dbBytes, flush: true);
    return (AppDatabase(NativeDatabase(snapshotFile)), snapshotFile);
  }

  Archive _decode(Uint8List zipBytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (_) {
      throw const InvalidBackupException('This file is not a valid .zip.');
    }
    for (final file in archive.files) {
      if (!_entryPattern.hasMatch(file.name)) {
        throw const InvalidBackupException(
          'This file is not a SubTrack backup.',
        );
      }
    }
    return archive;
  }
}
