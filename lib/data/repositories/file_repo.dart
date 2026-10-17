import 'package:drift/drift.dart';
import 'package:subtrack/core/mime.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/commit_repo.dart';
import 'package:subtrack/data/storage/blob_store.dart';

/// A file with its current commit, for the activity files screen.
class FileListItem {
  const FileListItem({required this.file, required this.currentCommit});

  final DbFile file;

  /// Null only for rows created before their first commit exists.
  final Commit? currentCommit;
}

class FileRepo {
  FileRepo(this.db, this.blobs);

  final AppDatabase db;
  final BlobStore blobs;

  /// Files of [activityId], newest added first, each with its current commit.
  Stream<List<FileListItem>> watchByActivity(int activityId) {
    final query =
        db.select(db.files).join([
            leftOuterJoin(
              db.commits,
              db.commits.id.equalsExp(db.files.currentCommitId),
            ),
          ])
          ..where(db.files.activityId.equals(activityId))
          ..orderBy([OrderingTerm.desc(db.files.id)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => FileListItem(
              file: row.readTable(db.files),
              currentCommit: row.readTableOrNull(db.commits),
            ),
          )
          .toList(),
    );
  }

  Future<DbFile?> getById(int id) {
    return (db.select(
      db.files,
    )..where((f) => f.id.equals(id))).getSingleOrNull();
  }

  /// Upload: stores the blob, creates the file row and its first commit,
  /// and points `current_commit_id` at it (AGENTS.md section 8).
  Future<int> upload({
    required int activityId,
    required Uint8List bytes,
    required String displayName,
    String message = 'Initial version',
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      throw ArgumentError('File name is required.');
    }
    if (bytes.isEmpty) {
      throw ArgumentError('File is empty.');
    }
    final hash = await blobs.saveBytes(bytes);
    final commitRepo = CommitRepo(db);
    return db.transaction(() async {
      final fileId = await db
          .into(db.files)
          .insert(
            FilesCompanion.insert(activityId: activityId, displayName: name),
          );
      await commitRepo.create(
        fileId: fileId,
        versionNo: 1,
        message: message,
        blobHash: hash,
        sizeBytes: bytes.length,
        mimeType: mimeForName(name),
      );
      return fileId;
    });
  }

  Future<void> create({
    required int activityId,
    required String displayName,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      throw ArgumentError('File name is required.');
    }
    await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(activityId: activityId, displayName: name),
        );
  }

  Future<void> setCurrentCommit(int fileId, int commitId) async {
    await (db.update(db.files)..where((f) => f.id.equals(fileId))).write(
      FilesCompanion(currentCommitId: Value(commitId)),
    );
  }

  Future<void> delete(int id) async {
    await (db.delete(db.files)..where((f) => f.id.equals(id))).go();
  }
}
