import 'package:drift/drift.dart';
import 'package:subtrack/core/hashing.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/backup_repo.dart';
import 'package:subtrack/data/storage/blob_store.dart';

/// Free-plan storage quota per account (AGENTS.md constraint 7).
const int cloudQuotaBytes = 100 * 1024 * 1024;

/// Supabase seams kept narrow so [CloudRepo] can be unit-tested offline.
abstract class CloudMetadataApi {
  /// Upserts rows into [table]; every row already carries user_id and id.
  Future<void> upsert(String table, List<Map<String, dynamic>> rows);

  /// Reads every row of [table] the account can see; RLS keeps it to its
  /// own rows.
  Future<List<Map<String, dynamic>>> fetch(String table);

  /// Deletes every row of [table] owned by [userId]; RLS also enforces it.
  Future<void> deleteRowsFor(String table, String userId);
}

abstract class CloudBlobApi {
  /// Hashes already stored in the account's blobs folder.
  Future<Set<String>> listBlobHashes();

  Future<void> uploadBlob(String hash, Uint8List bytes);

  /// Downloads the account's blob [hash].
  Future<Uint8List> downloadBlob(String hash);

  /// Bytes used by the account's blobs folder.
  Future<int> usedBytes();

  /// Deletes every blob in the account's folder.
  Future<void> deleteAllBlobs();
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

/// Phases reported while a cloud restore runs.
enum CloudRestorePhase { preparing, downloading, replacing, done }

/// Progress snapshot for Restore from cloud.
class CloudRestoreProgress {
  const CloudRestoreProgress(this.phase, {this.current = 0, this.total = 0});

  final CloudRestorePhase phase;

  /// Within [CloudRestorePhase.downloading]: 1-based index and count.
  final int current;
  final int total;
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
    bool includeOlderVersions = false,
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

    // 2. Only the latest version's blob goes up (AGENTS.md Phase 5), or
    //    every version when the student asked for the full history.
    final latest = includeOlderVersions
        ? await _allBlobs()
        : await _latestBlobs();
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

  /// What a restore from the cloud would bring, for the confirm dialog.
  /// Reads the cloud without touching the local database.
  Future<BackupContents> peekCloud() async {
    final (semesters, subjects, activities, files, commits) =
        await _fetchMetadata();
    return BackupContents(
      semesters: semesters.length,
      subjects: subjects.length,
      activities: activities.length,
      files: files.length,
      commits: commits.length,
    );
  }

  /// Restores from the cloud (AGENTS.md section 9, Phase 5 task 7) by
  /// replacing everything on this device with the cloud backup.
  ///
  /// Default backups keep only the latest blob per file, so commits whose
  /// blob was never uploaded are left out and each file points at its
  /// newest restored version. Existing commits are never rewritten; the
  /// replaced rows belong to this device alone.
  Future<void> restoreFromCloud({
    void Function(CloudRestoreProgress progress)? onProgress,
    bool Function()? cancelled,
  }) async {
    void report(CloudRestoreProgress progress) => onProgress?.call(progress);
    bool isCancelled() => cancelled?.call() ?? false;

    // 1. Fetch the metadata.
    report(const CloudRestoreProgress(CloudRestorePhase.preparing));
    final (semesters, subjects, activities, allFiles, allCommits) =
        await _fetchMetadata();
    if (semesters.isEmpty &&
        subjects.isEmpty &&
        activities.isEmpty &&
        allFiles.isEmpty &&
        allCommits.isEmpty) {
      throw const CloudBackupException(
        'Nothing is in the cloud yet. Press Back up now first.',
      );
    }
    final cloudHashes = await blobApi.listBlobHashes();

    // 2. Download blobs this device is missing, verifying each download
    // against its hash so a damaged transfer never reaches the database.
    final needed = {for (final commit in allCommits) commit.blobHash};
    final toDownload = [
      for (final hash in needed)
        if (!await blobs.exists(hash) && cloudHashes.contains(hash)) hash,
    ];
    var downloaded = 0;
    for (final hash in toDownload) {
      if (isCancelled()) {
        throw const CloudBackupCancelled();
      }
      downloaded++;
      report(
        CloudRestoreProgress(
          CloudRestorePhase.downloading,
          current: downloaded,
          total: toDownload.length,
        ),
      );
      final bytes = await blobApi.downloadBlob(hash);
      if (sha256Hex(bytes) != hash) {
        throw const CloudBackupException('A file from the cloud is damaged.');
      }
      await blobs.saveBytes(bytes);
    }

    // 3. Keep only the commits whose contents are on this device now, and
    // keep `restored from` links only when their target came back too.
    final keptIds = <int>{
      for (final commit in allCommits)
        if (await blobs.exists(commit.blobHash)) commit.id,
    };
    final keptCommits = [
      for (final commit in allCommits)
        if (keptIds.contains(commit.id))
          Commit(
            id: commit.id,
            fileId: commit.fileId,
            versionNo: commit.versionNo,
            message: commit.message,
            blobHash: commit.blobHash,
            sizeBytes: commit.sizeBytes,
            mimeType: commit.mimeType,
            restoredFromCommitId: keptIds.contains(commit.restoredFromCommitId)
                ? commit.restoredFromCommitId
                : null,
            createdAt: commit.createdAt,
          ),
    ];

    // 4. Each file points at its newest kept version; a file without any
    // kept version does not come back.
    final latestKept = <int, (int, int)>{}; // fileId -> (version, commit id)
    for (final commit in keptCommits) {
      final current = latestKept[commit.fileId];
      if (current == null || commit.versionNo > current.$1) {
        latestKept[commit.fileId] = (commit.versionNo, commit.id);
      }
    }
    final restoredFiles = [
      for (final file in allFiles)
        if (latestKept[file.id] != null)
          DbFile(
            id: file.id,
            activityId: file.activityId,
            displayName: file.displayName,
            currentCommitId: latestKept[file.id]!.$2,
            createdAt: file.createdAt,
          ),
    ];

    if (isCancelled()) {
      throw const CloudBackupCancelled();
    }

    // 5. Replace rows in one transaction, children before parents.
    report(const CloudRestoreProgress(CloudRestorePhase.replacing));
    await db.transaction(() async {
      await db.delete(db.commits).go();
      await db.delete(db.files).go();
      await db.delete(db.activities).go();
      await db.delete(db.subjects).go();
      await db.delete(db.semesters).go();
      for (final semester in semesters) {
        await db.into(db.semesters).insert(semester.toCompanion(true));
      }
      for (final subject in subjects) {
        await db.into(db.subjects).insert(subject.toCompanion(true));
      }
      for (final activity in activities) {
        await db.into(db.activities).insert(activity.toCompanion(true));
      }
      for (final file in restoredFiles) {
        await db.into(db.files).insert(file.toCompanion(true));
      }
      for (final commit in keptCommits) {
        await db.into(db.commits).insert(commit.toCompanion(true));
      }
    });
    report(const CloudRestoreProgress(CloudRestorePhase.done));
  }

  Future<
    (List<Semester>, List<Subject>, List<Activity>, List<DbFile>, List<Commit>)
  >
  _fetchMetadata() async {
    return (
      [for (final row in await metadataApi.fetch('semesters')) _semester(row)],
      [for (final row in await metadataApi.fetch('subjects')) _subject(row)],
      [for (final row in await metadataApi.fetch('activities')) _activity(row)],
      [for (final row in await metadataApi.fetch('files')) _file(row)],
      [for (final row in await metadataApi.fetch('commits')) _commit(row)],
    );
  }

  /// PostgREST returns whole bigints as JSON strings in some setups, so
  /// accept both forms.
  int _int(Object? value) => value is int ? value : int.parse(value! as String);

  DateTime _date(Object? value) => DateTime.parse(value! as String);

  DateTime? _dateOrNull(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  Semester _semester(Map<String, dynamic> row) => Semester(
    id: _int(row['id']),
    term: row['term'] as String,
    schoolYear: row['school_year'] as String,
    startDate: _date(row['start_date']),
    endDate: _date(row['end_date']),
    createdAt: _date(row['created_at']),
  );

  Subject _subject(Map<String, dynamic> row) => Subject(
    id: _int(row['id']),
    semesterId: _int(row['semester_id']),
    name: row['name'] as String,
    color: _int(row['color']),
    icon: row['icon'] as String,
    isArchived: row['is_archived'] as bool,
    createdAt: _date(row['created_at']),
  );

  Activity _activity(Map<String, dynamic> row) => Activity(
    id: _int(row['id']),
    subjectId: _int(row['subject_id']),
    title: row['title'] as String,
    notes: row['notes'] as String,
    deadline: _dateOrNull(row['deadline']),
    status: row['status'] as String,
    isArchived: row['is_archived'] as bool,
    createdAt: _date(row['created_at']),
  );

  DbFile _file(Map<String, dynamic> row) => DbFile(
    id: _int(row['id']),
    activityId: _int(row['activity_id']),
    displayName: row['display_name'] as String,
    currentCommitId: row['current_commit_id'] == null
        ? null
        : _int(row['current_commit_id']),
    createdAt: _date(row['created_at']),
  );

  Commit _commit(Map<String, dynamic> row) => Commit(
    id: _int(row['id']),
    fileId: _int(row['file_id']),
    versionNo: _int(row['version_no']),
    message: row['message'] as String,
    blobHash: row['blob_hash'] as String,
    sizeBytes: _int(row['size_bytes']),
    mimeType: row['mime_type'] as String,
    restoredFromCommitId: row['restored_from_commit_id'] == null
        ? null
        : _int(row['restored_from_commit_id']),
    createdAt: _date(row['created_at']),
  );

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

  /// Every commit's blob hash with its size, for the include-older-versions
  /// option. Identical content collapses into one entry.
  Future<Map<String, int>> _allBlobs() async {
    final result = <String, int>{};
    for (final commit in await db.select(db.commits).get()) {
      result[commit.blobHash] = commit.sizeBytes;
    }
    return result;
  }

  /// Bytes the account's blobs take in the cloud, for the storage bar.
  Future<int> cloudUsageBytes() => blobApi.usedBytes();

  /// Deletes this account's cloud rows and blobs (Profile > Delete cloud
  /// data, AGENTS.md 14). The username-to-email mapping in the cloud
  /// profiles table is kept, so the account can still log in by username.
  Future<void> deleteAllCloudData() async {
    for (final table in [
      'commits',
      'files',
      'activities',
      'subjects',
      'semesters',
    ]) {
      await metadataApi.deleteRowsFor(table, userId);
    }
    await blobApi.deleteAllBlobs();
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
