import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/core/hashing.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/commit_repo.dart';
import 'package:subtrack/data/repositories/file_repo.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';
import 'package:subtrack/data/storage/blob_store.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/features/edit/edit_providers.dart';
import 'package:subtrack/features/files/file_providers.dart';

Uint8List bytesOf(String s) => Uint8List.fromList(s.codeUnits);

class _Setup {
  const _Setup({
    required this.container,
    required this.tmp,
    required this.db,
    required this.fileId,
    required this.activityId,
  });

  final ProviderContainer container;
  final Directory tmp;
  final AppDatabase db;
  final int fileId;
  final int activityId;
}

Future<_Setup> _setup() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthService(prefs: prefs);
  await auth.signIn(identifier: 'maria@school.edu', password: 'secret');
  final db = AppDatabase.memory();
  final tmp = await Directory.systemTemp.createTemp('subtrack_edit_test');
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authServiceProvider.overrideWithValue(auth),
      databaseProvider.overrideWithValue(db),
      blobStoreProvider.overrideWithValue(BlobStore(Future.value(tmp))),
    ],
  );

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
  final fileId = await FileRepo(db, BlobStore(Future.value(tmp))).upload(
    activityId: activityId,
    bytes: bytesOf('v1 content'),
    displayName: 'thesis.txt',
  );

  addTearDown(() async {
    container.dispose();
    await db.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });
  return _Setup(
    container: container,
    tmp: tmp,
    db: db,
    fileId: fileId,
    activityId: activityId,
  );
}

Future<Commit> _baseCommit(_Setup s) async {
  return (await CommitRepo(s.db).watchByFile(s.fileId).first).single;
}

void main() {
  test(
    'start creates a private working copy and marks the file editing',
    () async {
      final s = await _setup();
      final base = await _baseCommit(s);
      final repo = s.container.read(editSessionRepoProvider);

      final session = await repo.start(
        fileId: s.fileId,
        baseCommitId: base.id,
        displayName: 'thesis.txt',
      );

      expect(session.baseCommitId, base.id);
      expect(session.fileId, s.fileId);
      expect(await File(session.workingPath).exists(), isTrue);
      expect(
        await File(session.workingPath).readAsBytes(),
        bytesOf('v1 content'),
      );
      // The copy keeps the display name so editors recognize the format.
      expect(p.basename(session.workingPath), 'thesis.txt');
      expect(await repo.watchActiveFileIds(s.activityId).first, {s.fileId});
    },
  );

  test('editing v1 of a three-version file creates v4 based on v1', () async {
    final s = await _setup();
    final commits = CommitRepo(s.db);
    final store = s.container.read(blobStoreProvider);
    final sessions = s.container.read(editSessionRepoProvider);

    for (final (versionNo, message, content) in [
      (2, 'Second draft', 'v2 content'),
      (3, 'Third draft', 'v3 content'),
    ]) {
      await commits.create(
        fileId: s.fileId,
        versionNo: versionNo,
        message: message,
        blobHash: await store.saveBytes(bytesOf(content)),
        sizeBytes: content.length,
        mimeType: 'text/plain',
      );
    }
    final before = await commits.watchByFile(s.fileId).first;
    final v1 = before.firstWhere((c) => c.versionNo == 1);

    final session = await sessions.start(
      fileId: s.fileId,
      baseCommitId: v1.id,
      displayName: 'thesis.txt',
    );

    // The student edits v1 in Word/WPS.
    final edited = bytesOf('v1 content, edited in Word');
    await File(session.workingPath).writeAsBytes(edited, flush: true);
    final hash = sha256Hex(edited);
    await store.saveBytes(edited);

    final v4Id = await commits.create(
      fileId: s.fileId,
      versionNo: await commits.nextVersionNo(s.fileId),
      message: 'Edited from v1',
      blobHash: hash,
      sizeBytes: edited.length,
      mimeType: 'text/plain',
      kind: 'edit',
      basedOnCommitId: v1.id,
    );
    await sessions.discard(session.id);

    final after = await commits.watchByFile(s.fileId).first;
    expect(after, hasLength(4), reason: 'editing adds a version, deletes none');
    final v4 = after.first;
    expect(v4.id, v4Id);
    expect(v4.versionNo, 4);
    expect(v4.kind, 'edit');
    expect(v4.basedOnCommitId, v1.id);
    expect(v4.message, 'Edited from v1');
    expect(await store.read(v4.blobHash), edited);
    // v3, v2, and v1 are untouched.
    expect(
      [after[1].message, after[2].message, after[3].message],
      ['Third draft', 'Second draft', 'Initial version'],
    );
    expect(after[3].kind, 'upload');
    expect(after[3].basedOnCommitId, isNull);
  });

  test('discard deletes the session and working copy, not history', () async {
    final s = await _setup();
    final base = await _baseCommit(s);
    final sessions = s.container.read(editSessionRepoProvider);
    final session = await sessions.start(
      fileId: s.fileId,
      baseCommitId: base.id,
      displayName: 'thesis.txt',
    );
    final dir = Directory(p.dirname(session.workingPath));
    expect(await dir.exists(), isTrue);

    await sessions.discard(session.id);

    expect(await File(session.workingPath).exists(), isFalse);
    expect(await dir.exists(), isFalse);
    expect(await sessions.all(), isEmpty);
    expect(await CommitRepo(s.db).watchByFile(s.fileId).first, hasLength(1));
  });

  test('cleanup removes sessions whose working copy vanished', () async {
    final s = await _setup();
    final base = await _baseCommit(s);
    final sessions = s.container.read(editSessionRepoProvider);
    final session = await sessions.start(
      fileId: s.fileId,
      baseCommitId: base.id,
      displayName: 'thesis.txt',
    );
    await File(session.workingPath).delete();

    expect(await sessions.cleanupMissing(), 1);
    expect(await sessions.all(), isEmpty);
    expect(await sessions.watchActiveFileIds(s.activityId).first, isEmpty);
  });

  test(
    'cleanup removes orphan working folders after a session row is gone',
    () async {
      final s = await _setup();
      final base = await _baseCommit(s);
      final sessions = s.container.read(editSessionRepoProvider);
      final session = await sessions.start(
        fileId: s.fileId,
        baseCommitId: base.id,
        displayName: 'thesis.txt',
      );
      final dir = Directory(p.dirname(session.workingPath));

      // Deleting the parent file/activity cascades the session row, but the
      // folder on disk needs the startup cleanup.
      await (s.db.delete(s.db.editSessions)).go();
      expect(await dir.exists(), isTrue);

      await sessions.cleanupMissing();
      expect(await dir.exists(), isFalse);
    },
  );

  test('start rejects a version that belongs to another file', () async {
    final s = await _setup();
    final otherId = await FileRepo(s.db, s.container.read(blobStoreProvider))
        .upload(
          activityId: s.activityId,
          bytes: bytesOf('other'),
          displayName: 'other.txt',
        );
    final otherCommit = (await CommitRepo(
      s.db,
    ).watchByFile(otherId).first).single;

    await expectLater(
      s.container
          .read(editSessionRepoProvider)
          .start(
            fileId: s.fileId,
            baseCommitId: otherCommit.id,
            displayName: 'thesis.txt',
          ),
      throwsArgumentError,
    );
    expect(await s.container.read(editSessionRepoProvider).all(), isEmpty);
  });
}
