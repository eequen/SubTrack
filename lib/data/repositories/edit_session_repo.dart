import 'dart:io';

import 'package:drift/drift.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/commit_repo.dart';
import 'package:subtrack/data/storage/blob_store.dart';

/// Working copies opened in an external editor (AGENTS.md Phase 5B).
///
/// A session points at the version it started from and at a private copy in
/// `edits/<sessionId>/`. Nothing in the history is touched until the student
/// commits, and a commit is always a new version.
class EditSessionRepo {
  EditSessionRepo(this.db, this.blobs);

  final AppDatabase db;
  final BlobStore blobs;

  /// File ids in [activityId] that have an unfinished edit session.
  Stream<Set<int>> watchActiveFileIds(int activityId) {
    final query = db.select(db.editSessions).join([
      innerJoin(db.files, db.files.id.equalsExp(db.editSessions.fileId)),
    ])..where(db.files.activityId.equals(activityId));
    return query.watch().map(
      (rows) => {for (final row in rows) row.readTable(db.editSessions).fileId},
    );
  }

  Future<EditSession?> getById(int id) {
    return (db.select(
      db.editSessions,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  /// The most recent session for [fileId], optionally only one based on
  /// [baseCommitId].
  Future<EditSession?> findForFile(int fileId, {int? baseCommitId}) {
    final query = db.select(db.editSessions)
      ..where((s) => s.fileId.equals(fileId))
      ..orderBy([(s) => OrderingTerm.desc(s.id)])
      ..limit(1);
    if (baseCommitId != null) {
      query.where((s) => s.baseCommitId.equals(baseCommitId));
    }
    return query.getSingleOrNull();
  }

  Future<List<EditSession>> all() => db.select(db.editSessions).get();

  /// Creates a session and its working copy for [baseCommitId].
  ///
  /// The copy keeps the file's display name so editors recognize the format.
  /// If the copy cannot be written, the row is removed again.
  Future<EditSession> start({
    required int fileId,
    required int baseCommitId,
    required String displayName,
  }) async {
    final base = await CommitRepo(db).getById(baseCommitId);
    if (base == null || base.fileId != fileId) {
      throw ArgumentError('The version to edit was not found.');
    }
    final id = await db
        .into(db.editSessions)
        .insert(
          EditSessionsCompanion.insert(
            fileId: fileId,
            baseCommitId: baseCommitId,
            workingPath: '',
          ),
        );
    try {
      final copy = await blobs.createWorkingCopy(
        hash: base.blobHash,
        sessionId: id,
        displayName: displayName,
      );
      await (db.update(db.editSessions)..where((s) => s.id.equals(id))).write(
        EditSessionsCompanion(workingPath: Value(copy.path)),
      );
      return (await getById(id))!;
    } catch (_) {
      await (db.delete(db.editSessions)..where((s) => s.id.equals(id))).go();
      await blobs.deleteWorkingCopy(id);
      rethrow;
    }
  }

  /// Deletes the session row and its working copy. History is untouched.
  Future<void> discard(int sessionId) async {
    await (db.delete(
      db.editSessions,
    )..where((s) => s.id.equals(sessionId))).go();
    await blobs.deleteWorkingCopy(sessionId);
  }

  Future<void> discardAllForFile(int fileId) async {
    final sessions = await (db.select(
      db.editSessions,
    )..where((s) => s.fileId.equals(fileId))).get();
    for (final session in sessions) {
      await discard(session.id);
    }
  }

  /// Removes sessions whose working copy disappeared (for example, the
  /// student cleared app storage) and folders whose session row was deleted
  /// with its file/activity. Returns how many sessions were removed.
  Future<int> cleanupMissing() async {
    final sessions = await all();
    var removed = 0;
    for (final session in sessions) {
      if (!await File(session.workingPath).exists()) {
        await discard(session.id);
        removed++;
      }
    }
    final remaining = await all();
    await blobs.cleanupWorkingCopies({for (final s in remaining) s.id});
    return removed;
  }
}
