import 'dart:typed_data';

import 'package:subtrack/data/repositories/cloud_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// PostgREST-backed metadata storage (AGENTS.md section 9, Phase 5 task 3).
class SupabaseMetadataApi implements CloudMetadataApi {
  SupabaseMetadataApi(this._client);

  final supa.SupabaseClient _client;

  @override
  Future<void> upsert(String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) {
      return;
    }
    await _client.from(table).upsert(rows, onConflict: 'user_id,id');
  }

  @override
  Future<List<Map<String, dynamic>>> fetch(String table) async {
    return await _client.from(table).select();
  }
}

/// Storage-backed blobs under `<userId>/blobs/<sha256>` in the private
/// `backups` bucket; the RLS policies keep every account to its own folder.
class SupabaseBlobApi implements CloudBlobApi {
  SupabaseBlobApi(this._client, this.userId);

  static const String _bucket = 'backups';
  static final RegExp _hashPattern = RegExp(r'^[0-9a-f]{64}$');

  final supa.SupabaseClient _client;
  final String userId;

  String _path(String hash) => '$userId/blobs/$hash';

  @override
  Future<Set<String>> listBlobHashes() async {
    final objects = await _client.storage
        .from(_bucket)
        .list(path: '$userId/blobs');
    return {
      for (final object in objects)
        if (_hashPattern.hasMatch(object.name)) object.name,
    };
  }

  @override
  Future<void> uploadBlob(String hash, Uint8List bytes) async {
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          _path(hash),
          bytes,
          fileOptions: const supa.FileOptions(
            contentType: 'application/octet-stream',
          ),
        );
  }

  @override
  Future<Uint8List> downloadBlob(String hash) async {
    return await _client.storage.from(_bucket).download(_path(hash));
  }

  @override
  Future<int> usedBytes() async {
    final objects = await _client.storage
        .from(_bucket)
        .list(path: '$userId/blobs');
    var total = 0;
    for (final object in objects) {
      total += (object.metadata?['size'] as num?)?.toInt() ?? 0;
    }
    return total;
  }
}
