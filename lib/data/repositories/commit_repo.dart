import 'package:subtrack/data/db/app_database.dart';

/// Method signatures only; versioning and restore land in Phase 3.
class CommitRepo {
  CommitRepo(this.db);

  final AppDatabase db;

  /// Newest first.
  Stream<List<Commit>> watchByFile(int fileId) => throw UnimplementedError();

  Future<int> create({
    required int fileId,
    required int versionNo,
    required String message,
    required String blobHash,
    required int sizeBytes,
    String mimeType = '',
    int? restoredFromCommitId,
  }) => throw UnimplementedError();

  /// Non-destructive restore: copies [fromCommitId] into a new commit.
  Future<int> restoreAsNewCommit({
    required int fileId,
    required int fromCommitId,
  }) => throw UnimplementedError();
}
