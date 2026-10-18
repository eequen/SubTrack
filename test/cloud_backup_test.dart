import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/cloud_repo.dart';
import 'package:subtrack/data/repositories/commit_repo.dart';
import 'package:subtrack/data/repositories/file_repo.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';
import 'package:subtrack/data/storage/blob_store.dart';

/// Records upserted rows per table, in call order.
class FakeMetadataApi implements CloudMetadataApi {
  final rows = <String, List<Map<String, dynamic>>>{};

  @override
  Future<void> upsert(String table, List<Map<String, dynamic>> batch) async {
    rows.putIfAbsent(table, () => []).addAll(batch);
  }
}

/// Pretends to be the account's blob folder, starting from [existing].
class FakeBlobApi implements CloudBlobApi {
  FakeBlobApi({Set<String>? existing, this.used = 0})
    : existing = Set.of(existing ?? const {});

  Set<String> existing;
  int used;
  final uploaded = <String, Uint8List>{};

  @override
  Future<Set<String>> listBlobHashes() async => Set.of(existing);

  @override
  Future<void> uploadBlob(String hash, Uint8List bytes) async {
    uploaded[hash] = bytes;
    existing.add(hash);
    used += bytes.length;
  }

  @override
  Future<int> usedBytes() async => used;
}

void main() {
  /// A fake "device": an in-memory database and a temp blob root.
  Future<(AppDatabase, BlobStore)> device(String prefix) async {
    final tmp = await Directory.systemTemp.createTemp(prefix);
    addTearDown(() async {
      if (await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    });
    final db = AppDatabase.memory();
    addTearDown(db.close);
    return (db, BlobStore(Future.value(tmp)));
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

  CloudRepo repo(
    AppDatabase db,
    BlobStore blobs, {
    required CloudMetadataApi metadata,
    required CloudBlobApi cloudBlobs,
  }) {
    return CloudRepo(
      db: db,
      blobs: blobs,
      metadataApi: metadata,
      blobApi: cloudBlobs,
      userId: 'user-1',
    );
  }

  test('uploads all metadata and only the latest blob', () async {
    final (db, blobs) = await device('cloud-all');
    await seedThesis(db, blobs);
    final metadata = FakeMetadataApi();
    final cloudBlobs = FakeBlobApi();

    final phases = <CloudBackupProgress>[];
    await repo(
      db,
      blobs,
      metadata: metadata,
      cloudBlobs: cloudBlobs,
    ).backupNow(onProgress: phases.add);

    // Every table received its rows.
    expect(metadata.rows.keys, [
      'semesters',
      'subjects',
      'activities',
      'files',
      'commits',
    ]);
    expect(metadata.rows['semesters']!.length, 1);
    expect(metadata.rows['subjects']!.length, 1);
    expect(metadata.rows['activities']!.length, 1);
    expect(metadata.rows['files']!.length, 1);
    expect(metadata.rows['commits']!.length, 2);

    // Only the latest version's blob is uploaded (AGENTS.md Phase 5).
    expect(cloudBlobs.uploaded.length, 1);
    expect(cloudBlobs.uploaded.values.single, 'v2 content'.codeUnits);

    // Progress reports each phase in order, with blob counts.
    expect(phases.map((p) => p.phase).toSet(), {
      CloudBackupPhase.preparing,
      CloudBackupPhase.metadata,
      CloudBackupPhase.blobs,
      CloudBackupPhase.done,
    });
    final blobProgress = phases
        .where((p) => p.phase == CloudBackupPhase.blobs)
        .single;
    expect(blobProgress.current, 1);
    expect(blobProgress.total, 1);
  });

  test('skips blobs the account already stores', () async {
    final (db, blobs) = await device('cloud-skip');
    final fileId = await seedThesis(db, blobs);
    // Latest blob, already in the cloud from an earlier backup.
    final latestHash =
        await (db.select(db.commits)
              ..where((c) => c.fileId.equals(fileId))
              ..orderBy([(c) => OrderingTerm.desc(c.versionNo)])
              ..limit(1))
            .get()
            .then((rows) => rows.single.blobHash);
    final metadata = FakeMetadataApi();
    final cloudBlobs = FakeBlobApi(existing: {latestHash});

    await repo(
      db,
      blobs,
      metadata: metadata,
      cloudBlobs: cloudBlobs,
    ).backupNow();

    expect(cloudBlobs.uploaded, isEmpty);
  });

  test('serializes rows with cloud column names and UTC dates', () async {
    final (db, blobs) = await device('cloud-serialize');
    await seedThesis(db, blobs);
    final metadata = FakeMetadataApi();
    final cloudBlobs = FakeBlobApi();

    await repo(
      db,
      blobs,
      metadata: metadata,
      cloudBlobs: cloudBlobs,
    ).backupNow();

    final semester = metadata.rows['semesters']!.single;
    expect(semester['user_id'], 'user-1');
    expect(semester['term'], 'first');
    expect(semester['school_year'], '2026-2027');
    final parsed = DateTime.parse(semester['start_date'] as String);
    expect(parsed.isAtSameMomentAs(DateTime(2026, 8, 18)), isTrue);

    final commit = metadata.rows['commits']!.last;
    expect(commit.keys, containsAll(['file_id', 'version_no', 'blob_hash']));
    expect(commit['version_no'], 2);
  });

  test('throws when the backup would exceed the quota', () async {
    final (db, blobs) = await device('cloud-quota');
    await seedThesis(db, blobs);
    final cloudBlobs = FakeBlobApi(used: cloudQuotaBytes);

    await expectLater(
      repo(
        db,
        blobs,
        metadata: FakeMetadataApi(),
        cloudBlobs: cloudBlobs,
      ).backupNow(),
      throwsA(isA<CloudBackupException>()),
    );
    expect(cloudBlobs.uploaded, isEmpty);
  });

  test('cancel from the start uploads nothing', () async {
    final (db, blobs) = await device('cloud-cancel');
    await seedThesis(db, blobs);
    final metadata = FakeMetadataApi();
    final cloudBlobs = FakeBlobApi();

    await expectLater(
      repo(
        db,
        blobs,
        metadata: metadata,
        cloudBlobs: cloudBlobs,
      ).backupNow(cancelled: () => true),
      throwsA(isA<CloudBackupCancelled>()),
    );
    expect(metadata.rows, isEmpty);
    expect(cloudBlobs.uploaded, isEmpty);
  });

  test('cancel after metadata keeps details but skips blobs', () async {
    final (db, blobs) = await device('cloud-cancel-mid');
    await seedThesis(db, blobs);
    final metadata = FakeMetadataApi();
    final cloudBlobs = FakeBlobApi();

    // Cancelled becomes true as soon as the last metadata table (commits)
    // has been uploaded, so the blob phase never starts.
    await expectLater(
      repo(
        db,
        blobs,
        metadata: metadata,
        cloudBlobs: cloudBlobs,
      ).backupNow(cancelled: () => metadata.rows.containsKey('commits')),
      throwsA(isA<CloudBackupCancelled>()),
    );
    expect(metadata.rows['commits']!.length, 2);
    expect(cloudBlobs.uploaded, isEmpty);
  });
}
