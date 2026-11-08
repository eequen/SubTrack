import 'package:path/path.dart' as p;

/// Builds the file name for a newly picked profile photo.
///
/// Every pick gets its own name: writing a new photo over the previous
/// path changes the bytes but not the path, and Flutter's image cache keys
/// FileImage by path, so the old photo would keep showing. The extension
/// comes from the picked file; a timestamp keeps names unique.
String avatarFileName(String userId, String sourcePath, {DateTime? at}) {
  final safeId = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final extension = p.extension(sourcePath).toLowerCase();
  final stamp = (at ?? DateTime.now()).microsecondsSinceEpoch;
  return '${safeId}_$stamp${extension.isEmpty ? '.jpg' : extension}';
}
