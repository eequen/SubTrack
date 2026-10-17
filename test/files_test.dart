import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/storage/blob_store.dart';
import 'package:subtrack/features/activities/activity_providers.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/features/files/file_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/features/subjects/subject_providers.dart';

Uint8List bytesOf(String s) => Uint8List.fromList(utf8.encode(s));

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthService(prefs: prefs);
  await auth.signIn(email: 'maria@school.edu', password: 'secret');
  final db = AppDatabase.memory();
  final tmp = await Directory.systemTemp.createTemp('subtrack_blobs_test');
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authServiceProvider.overrideWithValue(auth),
      databaseProvider.overrideWithValue(db),
      blobStoreProvider.overrideWithValue(BlobStore(Future.value(tmp))),
    ],
  );
  addTearDown(() async {
    await db.close();
    container.dispose();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });
  return container;
}

Future<int> _semester(ProviderContainer c) {
  return c
      .read(semesterRepoProvider)
      .create(
        term: 'first',
        schoolYear: '2026-2027',
        startDate: DateTime(2026, 8, 18),
        endDate: DateTime(2026, 12, 19),
      );
}

Future<int> _subject(ProviderContainer c, int semesterId) {
  return c
      .read(subjectRepoProvider)
      .create(semesterId: semesterId, name: 'CP1', color: 0xFF3B4BDB);
}

Future<int> _activity(ProviderContainer c, int subjectId) {
  return c
      .read(activityRepoProvider)
      .create(subjectId: subjectId, title: 'Lab');
}

/// Names of every blob currently on disk.
Future<List<String>> _blobsOnDisk(ProviderContainer c) async {
  final store = c.read(blobStoreProvider);
  final blobsDir = Directory(p.dirname(await store.pathFor('placeholder')));
  if (!await blobsDir.exists()) return [];
  return blobsDir.list().map((e) => p.basename(e.path)).toList();
}

void main() {
  test('upload stores the blob, creates the file row and commit v1', () async {
    final c = await _container();
    final semesterId = await _semester(c);
    final subjectId = await _subject(c, semesterId);
    final activityId = await _activity(c, subjectId);
    final repo = c.read(fileRepoProvider);

    final fileId = await repo.upload(
      activityId: activityId,
      bytes: bytesOf('hello'),
      displayName: 'notes.txt',
    );

    final items = await repo.watchByActivity(activityId).first;
    expect(items, hasLength(1));
    final item = items.single;
    expect(item.file.id, fileId);
    expect(item.file.displayName, 'notes.txt');
    final commit = item.currentCommit!;
    expect(commit.versionNo, 1);
    expect(commit.message, 'Initial version');
    expect(commit.sizeBytes, 5);
    expect(commit.mimeType, 'text/plain');

    // current_commit_id points at the new commit (AGENTS.md section 8).
    final db = c.read(databaseProvider);
    final row = await (db.select(
      db.files,
    )..where((f) => f.id.equals(fileId))).getSingle();
    expect(row.currentCommitId, commit.id);

    // Exactly one blob on disk, named by its hash.
    final blobs = await _blobsOnDisk(c);
    expect(blobs, [commit.blobHash]);
  });

  test('uploading the same content twice keeps one blob on disk', () async {
    final c = await _container();
    final semesterId = await _semester(c);
    final subjectId = await _subject(c, semesterId);
    final activityId = await _activity(c, subjectId);
    final repo = c.read(fileRepoProvider);

    await repo.upload(
      activityId: activityId,
      bytes: bytesOf('same content'),
      displayName: 'a.txt',
    );
    await repo.upload(
      activityId: activityId,
      bytes: bytesOf('same content'),
      displayName: 'b.txt',
    );

    final items = await repo.watchByActivity(activityId).first;
    expect(items, hasLength(2));
    expect(
      items.first.currentCommit!.blobHash,
      items.last.currentCommit!.blobHash,
    );
    expect(await _blobsOnDisk(c), hasLength(1));
  });

  test('upload validates name and content', () async {
    final c = await _container();
    final semesterId = await _semester(c);
    final subjectId = await _subject(c, semesterId);
    final activityId = await _activity(c, subjectId);
    final repo = c.read(fileRepoProvider);

    await expectLater(
      repo.upload(
        activityId: activityId,
        bytes: bytesOf('x'),
        displayName: '   ',
      ),
      throwsArgumentError,
    );
    await expectLater(
      repo.upload(
        activityId: activityId,
        bytes: Uint8List(0),
        displayName: 'a',
      ),
      throwsArgumentError,
    );
    expect(await repo.watchByActivity(activityId).first, isEmpty);
    expect(await _blobsOnDisk(c), isEmpty);
  });

  test('a new commit bumps the version and moves current_commit_id', () async {
    final c = await _container();
    final semesterId = await _semester(c);
    final subjectId = await _subject(c, semesterId);
    final activityId = await _activity(c, subjectId);
    final files = c.read(fileRepoProvider);
    final commits = c.read(commitRepoProvider);

    final fileId = await files.upload(
      activityId: activityId,
      bytes: bytesOf('v1 content'),
      displayName: 'essay.docx',
    );
    expect(await commits.nextVersionNo(fileId), 2);

    final v2Id = await commits.create(
      fileId: fileId,
      versionNo: await commits.nextVersionNo(fileId),
      message: 'Fixed intro',
      blobHash: 'otherhash',
      sizeBytes: 20,
      mimeType:
          'application/vnd.openxmlformats-officedocument'
          '.wordprocessingml.document',
    );

    final item = (await files.watchByActivity(activityId).first).single;
    expect(item.currentCommit!.id, v2Id);
    expect(item.currentCommit!.versionNo, 2);
    expect(item.currentCommit!.message, 'Fixed intro');

    final history = await commits.watchByFile(fileId).first;
    expect(history.map((h) => h.versionNo), [2, 1]);
  });

  test('restore copies an old version and never deletes history', () async {
    final c = await _container();
    final semesterId = await _semester(c);
    final subjectId = await _subject(c, semesterId);
    final activityId = await _activity(c, subjectId);
    final files = c.read(fileRepoProvider);
    final commits = c.read(commitRepoProvider);

    final fileId = await files.upload(
      activityId: activityId,
      bytes: bytesOf('v1 content'),
      displayName: 'essay.txt',
    );
    final history1 = await commits.watchByFile(fileId).first;
    final v1 = history1.single;
    final v2Id = await commits.create(
      fileId: fileId,
      versionNo: 2,
      message: 'Second draft',
      blobHash: 'v2hash',
      sizeBytes: 99,
    );

    final v3Id = await commits.restoreAsNewCommit(
      fileId: fileId,
      fromCommitId: v1.id,
    );

    final history = await commits.watchByFile(fileId).first;
    expect(history, hasLength(3), reason: 'restore never deletes commits');
    final v3 = history.first;
    expect(v3.id, v3Id);
    expect(v3.versionNo, 3);
    expect(v3.message, 'Restored from v1');
    expect(v3.restoredFromCommitId, v1.id);
    expect(v3.blobHash, v1.blobHash);
    expect(v3.sizeBytes, v1.sizeBytes);
    // v1 and v2 are untouched.
    expect(history[1].id, v2Id);
    expect(history[1].message, 'Second draft');
    expect(history.last.id, v1.id);
    expect(history.last.message, 'Initial version');
    // The file now points at the restore commit.
    final item = (await files.watchByActivity(activityId).first).single;
    expect(item.currentCommit!.id, v3Id);
  });

  test('restoring v2 of a 3-version file yields v4 that matches v2', () async {
    final c = await _container();
    final semesterId = await _semester(c);
    final subjectId = await _subject(c, semesterId);
    final activityId = await _activity(c, subjectId);
    final files = c.read(fileRepoProvider);
    final commits = c.read(commitRepoProvider);
    final store = c.read(blobStoreProvider);

    final fileId = await files.upload(
      activityId: activityId,
      bytes: bytesOf('v1 content'),
      displayName: 'thesis.txt',
    );
    for (final (versionNo, message, content) in [
      (2, 'Second draft', 'v2 content'),
      (3, 'Third draft', 'v3 content'),
    ]) {
      final hash = await store.saveBytes(bytesOf(content));
      await commits.create(
        fileId: fileId,
        versionNo: versionNo,
        message: message,
        blobHash: hash,
        sizeBytes: content.length,
        mimeType: 'text/plain',
      );
    }

    final before = await commits.watchByFile(fileId).first;
    expect(before.map((h) => h.versionNo), [3, 2, 1]);
    final v2 = before.firstWhere((h) => h.versionNo == 2);

    await commits.restoreAsNewCommit(fileId: fileId, fromCommitId: v2.id);

    // Done-when (AGENTS.md section 9, Phase 3): 3 versions + restore = 4,
    // and v4 matches v2.
    final after = await commits.watchByFile(fileId).first;
    expect(after, hasLength(4), reason: 'restore adds a version, deletes none');
    final v4 = after.first;
    expect(v4.versionNo, 4);
    expect(v4.message, 'Restored from v2');
    expect(v4.restoredFromCommitId, v2.id);
    expect(v4.blobHash, v2.blobHash);
    expect(v4.sizeBytes, v2.sizeBytes);
    expect(await store.read(v4.blobHash), await store.read(v2.blobHash));

    // v3, v2, v1 are untouched.
    expect(
      [after[1].message, after[2].message, after[3].message],
      ['Third draft', 'Second draft', 'Initial version'],
    );

    // current_commit_id points at v4.
    final item = (await files.watchByActivity(activityId).first).single;
    expect(item.currentCommit!.id, v4.id);
  });

  test('restore rejects a commit from another file', () async {
    final c = await _container();
    final semesterId = await _semester(c);
    final subjectId = await _subject(c, semesterId);
    final activityId = await _activity(c, subjectId);
    final files = c.read(fileRepoProvider);
    final commits = c.read(commitRepoProvider);

    final fileId = await files.upload(
      activityId: activityId,
      bytes: bytesOf('a'),
      displayName: 'a.txt',
    );
    final otherId = await files.upload(
      activityId: activityId,
      bytes: bytesOf('b'),
      displayName: 'b.txt',
    );
    final otherCommit = (await commits.watchByFile(otherId).first).single;

    await expectLater(
      commits.restoreAsNewCommit(fileId: fileId, fromCommitId: otherCommit.id),
      throwsArgumentError,
    );
  });

  test('deleting a file cascades its commits', () async {
    final c = await _container();
    final db = c.read(databaseProvider);
    final semesterId = await _semester(c);
    final subjectId = await _subject(c, semesterId);
    final activityId = await _activity(c, subjectId);
    final files = c.read(fileRepoProvider);

    final fileId = await files.upload(
      activityId: activityId,
      bytes: bytesOf('bye'),
      displayName: 'bye.txt',
    );
    await files.delete(fileId);

    expect(await db.select(db.files).get(), isEmpty);
    expect(await db.select(db.commits).get(), isEmpty);
  });
}
