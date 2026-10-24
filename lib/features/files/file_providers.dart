import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/commit_repo.dart';
import 'package:subtrack/data/repositories/file_repo.dart';
import 'package:subtrack/data/storage/blob_store.dart';
import 'package:subtrack/features/files/file_pick.dart';

/// Content-addressed blobs live outside the per-user database, shared safely
/// across accounts on the device (identical content is identical everywhere).
final blobStoreProvider = Provider<BlobStore>((_) => BlobStore());

final fileRepoProvider = Provider<FileRepo>((ref) {
  return FileRepo(ref.watch(databaseProvider), ref.watch(blobStoreProvider));
});

final commitRepoProvider = Provider<CommitRepo>((ref) {
  return CommitRepo(ref.watch(databaseProvider));
});

final filesProvider = StreamProvider.family<List<FileListItem>, int>((
  ref,
  activityId,
) {
  return ref.watch(fileRepoProvider).watchByActivity(activityId);
});

/// One file with its current commit, for the commit and history screens.
final fileItemProvider = StreamProvider.family<FileListItem?, int>((ref, id) {
  return ref.watch(fileRepoProvider).watchById(id);
});

/// Versions of one file, newest first.
final commitsProvider = StreamProvider.family<List<Commit>, int>((ref, fileId) {
  return ref.watch(commitRepoProvider).watchByFile(fileId);
});

/// Picking a file is injected so screens stay testable without the native
/// picker (widget tests override this with fixed bytes).
typedef FilePickFn = Future<PickedUpload?> Function(BuildContext context);

final filePickerProvider = Provider<FilePickFn>((_) => pickFileBytes);
