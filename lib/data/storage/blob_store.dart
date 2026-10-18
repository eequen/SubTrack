import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:subtrack/core/hashing.dart';

/// Content-addressed blob storage: `blobs/<sha256>` inside the app documents
/// folder (AGENTS.md section 8). Identical content is stored once; the file
/// name carries no extension, extensions live in `commits.mime_type` and the
/// file's display name.
class BlobStore {
  BlobStore(Future<Directory> root) : _root = root;

  /// Real app storage; tests pass a temp directory instead.
  BlobStore.app() : _root = getApplicationDocumentsDirectory();

  final Future<Directory> _root;

  Future<Directory> _blobsDir() async {
    final root = await _root;
    final dir = Directory(p.join(root.path, 'blobs'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> pathFor(String hash) async {
    return p.join((await _blobsDir()).path, hash);
  }

  Future<bool> exists(String hash) async {
    return File(await pathFor(hash)).exists();
  }

  /// Saves [bytes] under its SHA-256 hash and returns the hash.
  /// Reuses the existing blob when the content is already stored.
  Future<String> saveBytes(Uint8List bytes) async {
    final hash = sha256Hex(bytes);
    final file = File(await pathFor(hash));
    if (!await file.exists()) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return hash;
  }

  Future<Uint8List> read(String hash) async {
    final file = File(await pathFor(hash));
    if (!await file.exists()) {
      throw StateError('Blob not found: $hash');
    }
    return file.readAsBytes();
  }

  /// Copies the blob into `<root>/tmp` carrying [displayName]'s sanitized
  /// name (and extension) so an external app can open it. Blob content is
  /// immutable, so the copy is reused on later opens.
  Future<File> exportForOpening(String hash, String displayName) async {
    final root = await _root;
    final tmp = Directory(p.join(root.path, 'tmp'));
    if (!await tmp.exists()) {
      await tmp.create(recursive: true);
    }
    final safeName = p
        .basename(displayName)
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final target = File(p.join(tmp.path, '${hash.substring(0, 8)}_$safeName'));
    if (!await target.exists()) {
      await target.writeAsBytes(await read(hash), flush: true);
    }
    return target;
  }
}
