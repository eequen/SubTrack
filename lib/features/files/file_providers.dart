import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/repositories/commit_repo.dart';
import 'package:subtrack/data/repositories/file_repo.dart';
import 'package:subtrack/data/storage/blob_store.dart';

/// Content-addressed blobs live outside the per-user database, shared safely
/// across accounts on the device (identical content is identical everywhere).
final blobStoreProvider = Provider<BlobStore>((_) => BlobStore.app());

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
