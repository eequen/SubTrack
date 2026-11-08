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
  /// Tests pass a real temp directory; a missing [root] resolves the app
  /// documents folder on first use instead of at construction, so simply
  /// building the store is safe in widget tests where the platform
  /// channels do not run (view-only flows like file lists keep working).
  BlobStore([Future<Directory>? root]) : _override = root;

  final Future<Directory>? _override;
  Future<Directory>? _cached;

  Future<Directory> get _root {
    final override = _override;
    if (override != null) {
      return override;
    }
    return _cached ??= getApplicationDocumentsDirectory();
  }

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

  /// Copies the blob into `<root>/edits/<sessionId>/<displayName>` and
  /// returns the working copy. Editors get this file through the Android
  /// FileProvider; the blob itself is never handed out for editing.
  Future<File> createWorkingCopy({
    required String hash,
    required int sessionId,
    required String displayName,
  }) async {
    final root = await _root;
    final dir = Directory(p.join(root.path, 'edits', '$sessionId'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final target = File(p.join(dir.path, _safeName(displayName)));
    await target.writeAsBytes(await read(hash), flush: true);
    return target;
  }

  /// Deletes the whole `edits/<sessionId>` folder, if it exists.
  Future<void> deleteWorkingCopy(int sessionId) async {
    final root = await _root;
    final dir = Directory(p.join(root.path, 'edits', '$sessionId'));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Removes working-copy folders whose session row is gone (for example,
  /// after the activity was deleted). Sessions in [keepSessionIds] survive.
  Future<void> cleanupWorkingCopies(Set<int> keepSessionIds) async {
    final root = await _root;
    final dir = Directory(p.join(root.path, 'edits'));
    if (!await dir.exists()) return;
    await for (final entry in dir.list()) {
      if (entry is! Directory) continue;
      final id = int.tryParse(p.basename(entry.path));
      if (id == null || !keepSessionIds.contains(id)) {
        await entry.delete(recursive: true);
      }
    }
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
    final target = File(
      p.join(tmp.path, '${hash.substring(0, 8)}_${_safeName(displayName)}'),
    );
    if (!await target.exists()) {
      await target.writeAsBytes(await read(hash), flush: true);
    }
    return target;
  }

  String _safeName(String displayName) {
    final name = p
        .basename(displayName)
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return name.isEmpty ? 'document' : name;
  }
}
