import 'package:drift/drift.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/storage/blob_store.dart';

/// Free-plan storage quota per account (AGENTS.md constraint 7).
const int cloudQuotaBytes = 100 * 1024 * 1024;

/// Supabase seams kept narrow so [CloudRepo] can be unit-tested offline.
abstract class CloudMetadataApi {
  /// Upserts rows into [table]; every row already carries user_id and id.
  Future<void> upsert(String table, List<Map<String, dynamic>> rows);
}

abstract class CloudBlobApi {
  /// Hashes already stored in the account's blobs folder.
  Future<Set<String>> listBlobHashes();

  Future<void> uploadBlob(String hash, Uint8List bytes);

  /// Bytes used by the account's blobs folder.
  Future<int> usedBytes();
}

/// Phases reported while a cloud backup runs.
enum CloudBackupPhase { preparing, metadata, blobs, done }

/// Progress snapshot shown on the Cloud screen.
class CloudBackupProgress {
  const CloudBackupProgress(this.phase, {this.current = 0, this.total = 0});

  final CloudBackupPhase phase;

  /// Within [CloudBackupPhase.blobs]: 1-based index and count.
  final int current;
  final int total;
}

/// The student pressed Cancel during a backup.
class CloudBackupCancelled implements Exception {
  const CloudBackupCancelled();

  @override
  String toString() => 'Backup cancelled.';
}

/// Upload failed for a reason worth showing to the student.
class CloudBackupException implements Exception {
  const CloudBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Manual cloud backup (AGENTS.md section 9, Phase 5 task 5).
///
/// Uploads every row of the local database (keyed by the ids the phone
/// assigned) and the latest version's blob per file, skipping hashes the
/// account already stores. Restore-from-cloud re-inserts rows with these
/// ids, so every reference keeps working.
class CloudRepo {
  CloudRepo({
    required this.db,
    required this.blobs,
    required this.metadataApi,
    required this.blobApi,
    required this.userId,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final CloudMetadataApi metadataApi;
  final CloudBlobApi blobApi;
  final String userId;

  /// Runs one manual backup, reporting [onProgress] and honouring
  /// [cancelled] between steps. Throws [CloudBackupCancelled] when the
  /// student cancels, [CloudBackupException] when the quota would overflow.
  Future<void> backupNow({
    void Function(CloudBackupProgress progress)? onProgress,
    bool Function()? cancelled,
  }) async {
    void report(CloudBackupProgress progress) => onProgress?.call(progress);
    bool isCancelled() => cancelled?.call() ?? false;

    // 1. Read every row.
    report(const CloudBackupProgress(CloudBackupPhase.preparing));
    final semesters = await db.select(db.semesters).get();
    final subjects = await db.select(db.subjects).get();
    final activities = await db.select(db.activities).get();
    final files = await db.select(db.files).get();
    final commits = await db.select(db.commits).get();

    // 2. Only the latest version's blob goes up (AGENTS.md Phase 5).
    final latest = await _latestBlobs();
    final known = await blobApi.listBlobHashes();
    final fresh = <String, int>{
      for (final entry in latest.entries)
        if (!known.contains(entry.key)) entry.key: entry.value,
    };

    // 3. Quota: the account never exceeds 100 MB (constraint 7).
    final used = await blobApi.usedBytes();
    var needed = 0;
    for (final size in fresh.values) {
      needed += size;
    }
    if (used + needed > cloudQuotaBytes) {
      throw CloudBackupException(
        'Not enough cloud space: this backup needs '
        '${_mb(needed)} MB more, and you already use '
        '${_mb(used)} of 100 MB.',
      );
    }

    if (isCancelled()) {
      throw const CloudBackupCancelled();
    }

    // 4. Metadata: parents before children.
    report(const CloudBackupProgress(CloudBackupPhase.metadata));
    await _upsertAll('semesters', [
      for (final row in semesters) _semesterRow(row),
    ]);
    await _upsertAll('subjects', [
      for (final row in subjects) _subjectRow(row),
    ]);
    await _upsertAll('activities', [
      for (final row in activities) _activityRow(row),
    ]);
    await _upsertAll('files', [for (final row in files) _fileRow(row)]);
    await _upsertAll('commits', [for (final row in commits) _commitRow(row)]);

    if (isCancelled()) {
      throw const CloudBackupCancelled();
    }

    // 5. Blobs the account does not have yet.
    var index = 0;
    for (final entry in fresh.entries) {
      if (isCancelled()) {
        throw const CloudBackupCancelled();
      }
      index++;
      report(
        CloudBackupProgress(
          CloudBackupPhase.blobs,
          current: index,
          total: fresh.length,
        ),
      );
      final Uint8List bytes;
      try {
        bytes = await blobs.read(entry.key);
      } on StateError {
        throw CloudBackupException(
          'A file\'s contents are missing on this device.',
        );
      }
      await blobApi.uploadBlob(entry.key, bytes);
    }
    report(const CloudBackupProgress(CloudBackupPhase.done));
  }

  /// The latest commit's blob hash per file, with its size. Files without a
  /// commit cannot exist (upload always creates v1), so the join skips none.
  Future<Map<String, int>> _latestBlobs() async {
    final query = db.select(db.files).join([
      innerJoin(db.commits, db.commits.id.equalsExp(db.files.currentCommitId)),
    ]);
    final result = <String, int>{};
    for (final row in await query.get()) {
      final commit = row.readTable(db.commits);
      result[commit.blobHash] = commit.sizeBytes;
    }
    return result;
  }

  Future<void> _upsertAll(String table, List<Map<String, dynamic>> rows) async {
    for (var start = 0; start < rows.length; start += 250) {
      final end = start + 250 > rows.length ? rows.length : start + 250;
      await metadataApi.upsert(table, rows.sublist(start, end));
    }
  }

  String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  String _iso(DateTime value) => value.toUtc().toIso8601String();

  Map<String, dynamic> _semesterRow(Semester semester) => {
    'user_id': userId,
    'id': semester.id,
    'term': semester.term,
    'school_year': semester.schoolYear,
    'start_date': _iso(semester.startDate),
    'end_date': _iso(semester.endDate),
    'created_at': _iso(semester.createdAt),
  };

  Map<String, dynamic> _subjectRow(Subject subject) => {
    'user_id': userId,
    'id': subject.id,
    'semester_id': subject.semesterId,
    'name': subject.name,
    'color': subject.color,
    'icon': subject.icon,
    'is_archived': subject.isArchived,
    'created_at': _iso(subject.createdAt),
  };

  Map<String, dynamic> _activityRow(Activity activity) => {
    'user_id': userId,
    'id': activity.id,
    'subject_id': activity.subjectId,
    'title': activity.title,
    'notes': activity.notes,
    'deadline': activity.deadline == null ? null : _iso(activity.deadline!),
    'status': activity.status,
    'is_archived': activity.isArchived,
    'created_at': _iso(activity.createdAt),
  };

  Map<String, dynamic> _fileRow(DbFile file) => {
    'user_id': userId,
    'id': file.id,
    'activity_id': file.activityId,
    'display_name': file.displayName,
    'current_commit_id': file.currentCommitId,
    'created_at': _iso(file.createdAt),
  };

  Map<String, dynamic> _commitRow(Commit commit) => {
    'user_id': userId,
    'id': commit.id,
    'file_id': commit.fileId,
    'version_no': commit.versionNo,
    'message': commit.message,
    'blob_hash': commit.blobHash,
    'size_bytes': commit.sizeBytes,
    'mime_type': commit.mimeType,
    'restored_from_commit_id': commit.restoredFromCommitId,
    'created_at': _iso(commit.createdAt),
  };
}
