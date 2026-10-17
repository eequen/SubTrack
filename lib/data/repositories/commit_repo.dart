import 'package:drift/drift.dart';
import 'package:subtrack/data/db/app_database.dart';

class CommitRepo {
  CommitRepo(this.db);

  final AppDatabase db;

  /// Newest first.
  Stream<List<Commit>> watchByFile(int fileId) {
    final query = db.select(db.commits)
      ..where((c) => c.fileId.equals(fileId))
      ..orderBy([
        (c) => OrderingTerm.desc(c.versionNo),
        (c) => OrderingTerm.desc(c.id),
      ]);
    return query.watch();
  }

  Future<Commit?> getById(int id) {
    return (db.select(
      db.commits,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  /// Next version number for [fileId] (1 when there are no commits).
  Future<int> nextVersionNo(int fileId) async {
    final max = db.commits.versionNo.max();
    final query = db.selectOnly(db.commits)
      ..addColumns([max])
      ..where(db.commits.fileId.equals(fileId));
    final row = await query.getSingle();
    return (row.read(max) ?? 0) + 1;
  }

  /// Creates the commit and keeps `files.current_commit_id` in sync.
  Future<int> create({
    required int fileId,
    required int versionNo,
    required String message,
    required String blobHash,
    required int sizeBytes,
    String mimeType = '',
    int? restoredFromCommitId,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Commit message is required.');
    }
    if (versionNo < 1) {
      throw ArgumentError('Version number must be at least 1.');
    }
    return db.transaction(() async {
      final id = await db
          .into(db.commits)
          .insert(
            CommitsCompanion.insert(
              fileId: fileId,
              versionNo: versionNo,
              message: trimmed,
              blobHash: blobHash,
              sizeBytes: sizeBytes,
              mimeType: Value(mimeType),
              restoredFromCommitId: Value(restoredFromCommitId),
            ),
          );
      await (db.update(db.files)..where((f) => f.id.equals(fileId))).write(
        FilesCompanion(currentCommitId: Value(id)),
      );
      return id;
    });
  }

  /// Non-destructive restore: copies [fromCommitId] into a new commit
  /// (AGENTS.md constraint 3). Existing commits are never touched.
  Future<int> restoreAsNewCommit({
    required int fileId,
    required int fromCommitId,
  }) async {
    final source = await getById(fromCommitId);
    if (source == null || source.fileId != fileId) {
      throw ArgumentError('Version to restore not found.');
    }
    final versionNo = await nextVersionNo(fileId);
    return create(
      fileId: fileId,
      versionNo: versionNo,
      message: 'Restored from v${source.versionNo}',
      blobHash: source.blobHash,
      sizeBytes: source.sizeBytes,
      mimeType: source.mimeType,
      restoredFromCommitId: source.id,
    );
  }
}
