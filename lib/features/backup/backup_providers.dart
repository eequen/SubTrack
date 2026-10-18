import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/repositories/backup_repo.dart';
import 'package:subtrack/features/files/file_pick.dart';
import 'package:subtrack/features/files/file_providers.dart';

final backupRepoProvider = Provider<BackupRepo>((ref) {
  return BackupRepo(
    ref.watch(databaseProvider),
    ref.watch(blobStoreProvider),
    getApplicationDocumentsDirectory(),
  );
});

/// Picking a backup .zip is injected so the Cloud screen stays testable
/// without the native picker (widget tests override this with fixed bytes).
typedef BackupPickFn = Future<PickedUpload?> Function();

final backupPickerProvider = Provider<BackupPickFn>((_) {
  return () async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result.isEmpty) return null;
    final picked = result.single;
    return PickedUpload(bytes: await picked.readAsBytes(), name: picked.name);
  };
});
