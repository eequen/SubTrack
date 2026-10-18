import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/repositories/cloud_repo.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/cloud/supabase_cloud_api.dart';
import 'package:subtrack/features/files/file_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// Reading [cloudRepoProvider] without credentials or without a signed-in
/// user throws a [StateError]; the Cloud screen shows it as a message.
final cloudRepoProvider = Provider<CloudRepo>((ref) {
  if (!supabaseConfigured) {
    throw StateError(
      'Cloud backup needs Supabase credentials in the build (--dart-define).',
    );
  }
  final user = ref.watch(authControllerProvider);
  if (user == null) {
    throw StateError('Sign in first.');
  }
  return CloudRepo(
    db: ref.watch(databaseProvider),
    blobs: ref.watch(blobStoreProvider),
    metadataApi: SupabaseMetadataApi(supa.Supabase.instance.client),
    blobApi: SupabaseBlobApi(supa.Supabase.instance.client, user.id),
    userId: user.id,
  );
});
