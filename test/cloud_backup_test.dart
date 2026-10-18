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

/// Records upserted rows per table, in call order, and serves [fetched]
/// rows for reads — a fake cloud between two "devices".
class FakeMetadataApi implements CloudMetadataApi {
  FakeMetadataApi({Map<String, List<Map<String, dynamic>>>? fetched})
    : fetched = fetched ?? {};

  /// Rows fetch() serves, keyed by table.
  Map<String, List<Map<String, dynamic>>> fetched;
  final rows = <String, List<Map<String, dynamic>>>{};

  @override
  Future<void> upsert(String table, List<Map<String, dynamic>> batch) async {
    rows.putIfAbsent(table, () => []).addAll(batch);
  }

  @override
  Future<List<Map<String, dynamic>>> fetch(String table) async =>
      fetched[table] ?? const [];
}

/// Pretends to be the account's blob folder, starting from [existing] and
/// serving bytes from [stored]. Keys of [stored] are automatically visible
/// to listBlobHashes, like a real bucket listing.
class FakeBlobApi implements CloudBlobApi {
  FakeBlobApi({
    Set<String>? existing,
    this.used = 0,
    Map<String, Uint8List>? stored,
  }) : stored = stored ?? <String, Uint8List>{},
       existing = Set.of({...?existing, ...?stored?.keys});

  Set<String> existing;
  Map<String, Uint8List> stored;
  int used;
  final uploaded = <String, Uint8List>{};
  final downloaded = <String>[];

  @override
  Future<Set<String>> listBlobHashes() async => Set.of(existing);

  @override
  Future<void> uploadBlob(String hash, Uint8List bytes) async {
    uploaded[hash] = bytes;
    stored[hash] = bytes;
    existing.add(hash);
    used += bytes.length;
  }

  @override
  Future<Uint8List> downloadBlob(String hash) async {
    final bytes = stored[hash];
    if (bytes == null) {
      throw StateError('FakeBlobApi has no blob $hash');
    }
    downloaded.add(hash);
    return bytes;
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

  test('include older versions uploads every blob', () async {
    final (db, blobs) = await device('cloud-older');
    await seedThesis(db, blobs);
    final metadata = FakeMetadataApi();
    final cloudBlobs = FakeBlobApi();

    await repo(
      db,
      blobs,
      metadata: metadata,
      cloudBlobs: cloudBlobs,
    ).backupNow(includeOlderVersions: true);

    // v1 and v2 both go up when the student asked for the full history.
    expect(cloudBlobs.uploaded.length, 2);
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

  test(
    'restore rebuilds a fresh device, keeping restorable versions only',
    () async {
      final (dbA, blobsA) = await device('restore-a');
      await seedThesis(dbA, blobsA);
      final metadata = FakeMetadataApi();
      final cloudBlobs = FakeBlobApi();
      await repo(
        dbA,
        blobsA,
        metadata: metadata,
        cloudBlobs: cloudBlobs,
      ).backupNow();

      // Fresh phone: junk data on it, the cloud serves what was uploaded.
      final (dbB, blobsB) = await device('restore-b');
      await SemesterRepo(dbB).create(
        term: 'summer',
        schoolYear: '1999-2000',
        startDate: DateTime(1999, 6, 1),
        endDate: DateTime(1999, 7, 31),
      );
      final restoreMetadata = FakeMetadataApi(fetched: metadata.rows);
      final restoreBlobs = FakeBlobApi(stored: cloudBlobs.uploaded);
      final repoB = repo(
        dbB,
        blobsB,
        metadata: restoreMetadata,
        cloudBlobs: restoreBlobs,
      );

      final contents = await repoB.peekCloud();
      expect(contents.semesters, 1);
      expect(contents.commits, 2);

      await repoB.restoreFromCloud();

      // The junk semester is gone; the backup's rows are back with their
      // original ids.
      final semestersB = await dbB.select(dbB.semesters).get();
      expect(semestersB.length, 1);
      expect(semestersB.single.schoolYear, '2026-2027');
      expect((await dbB.select(dbB.subjects).get()).single.name, 'CP1');
      expect((await dbB.select(dbB.activities).get()).single.title, 'Thesis');
      final filesB = await dbB.select(dbB.files).get();
      expect(filesB.single.displayName, 'thesis.txt');

      // Only v2 was backed up (latest only), so v1 does not come back and
      // the file points straight at v2.
      final commitsB = await dbB.select(dbB.commits).get();
      expect(commitsB.length, 1);
      expect(commitsB.single.versionNo, 2);
      expect(filesB.single.currentCommitId, commitsB.single.id);
      expect(
        String.fromCharCodes(await blobsB.read(commitsB.single.blobHash)),
        'v2 content',
      );
    },
  );

  test('a damaged download fails the restore and keeps local data', () async {
    final (dbA, blobsA) = await device('restore-bad-a');
    await seedThesis(dbA, blobsA);
    final metadata = FakeMetadataApi();
    final cloudBlobs = FakeBlobApi();
    await repo(
      dbA,
      blobsA,
      metadata: metadata,
      cloudBlobs: cloudBlobs,
    ).backupNow();

    final (dbB, blobsB) = await device('restore-bad-b');
    await SemesterRepo(dbB).create(
      term: 'second',
      schoolYear: '1999-2000',
      startDate: DateTime(1999, 1, 1),
      endDate: DateTime(1999, 5, 31),
    );
    final tampered = {
      for (final entry in cloudBlobs.uploaded.entries)
        entry.key: Uint8List.fromList('tampered'.codeUnits),
    };
    final repoB = repo(
      dbB,
      blobsB,
      metadata: FakeMetadataApi(fetched: metadata.rows),
      cloudBlobs: FakeBlobApi(stored: tampered),
    );

    await expectLater(
      repoB.restoreFromCloud(),
      throwsA(isA<CloudBackupException>()),
    );
    // Nothing was replaced.
    expect(
      (await dbB.select(dbB.semesters).get()).single.schoolYear,
      '1999-2000',
    );
    expect(await dbB.select(dbB.commits).get(), isEmpty);
  });

  test('cancel before the replace keeps local data', () async {
    final (dbA, blobsA) = await device('restore-cancel-a');
    await seedThesis(dbA, blobsA);
    final metadata = FakeMetadataApi();
    final cloudBlobs = FakeBlobApi();
    await repo(
      dbA,
      blobsA,
      metadata: metadata,
      cloudBlobs: cloudBlobs,
    ).backupNow();

    final (dbB, blobsB) = await device('restore-cancel-b');
    await SemesterRepo(dbB).create(
      term: 'second',
      schoolYear: '1999-2000',
      startDate: DateTime(1999, 1, 1),
      endDate: DateTime(1999, 5, 31),
    );
    final restoreBlobs = FakeBlobApi(stored: cloudBlobs.uploaded);

    // Cancelled once the (only) blob has been downloaded, so the
    // destructive replace never runs.
    await expectLater(
      repo(
        dbB,
        blobsB,
        metadata: FakeMetadataApi(fetched: metadata.rows),
        cloudBlobs: restoreBlobs,
      ).restoreFromCloud(cancelled: () => restoreBlobs.downloaded.isNotEmpty),
      throwsA(isA<CloudBackupCancelled>()),
    );
    expect(
      (await dbB.select(dbB.semesters).get()).single.schoolYear,
      '1999-2000',
    );
    expect(await dbB.select(dbB.commits).get(), isEmpty);
  });

  test(
    'an empty cloud backup is refused instead of wiping the device',
    () async {
      final (db, blobs) = await device('restore-empty');
      await expectLater(
        repo(
          db,
          blobs,
          metadata: FakeMetadataApi(),
          cloudBlobs: FakeBlobApi(),
        ).restoreFromCloud(),
        throwsA(isA<CloudBackupException>()),
      );
    },
  );
}
