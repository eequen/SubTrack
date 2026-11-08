import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/repositories/edit_session_repo.dart';
import 'package:subtrack/features/edit/editor_service.dart';
import 'package:subtrack/features/files/file_providers.dart';

final editSessionRepoProvider = Provider<EditSessionRepo>((ref) {
  return EditSessionRepo(
    ref.watch(databaseProvider),
    ref.watch(blobStoreProvider),
  );
});

/// Injected so edit-flow widget tests do not need the native channel.
final editorServiceProvider = Provider<EditorService>(
  (_) => const EditorService(),
);

/// File ids with an unfinished edit in one activity (for the Editing badge).
final activeEditSessionsProvider = StreamProvider.family<Set<int>, int>((
  ref,
  activityId,
) {
  return ref.watch(editSessionRepoProvider).watchActiveFileIds(activityId);
});

/// Removes sessions whose working copy vanished, once per app start.
final editSessionCleanupProvider = FutureProvider<int>((ref) {
  return ref.watch(editSessionRepoProvider).cleanupMissing();
});
