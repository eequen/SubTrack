import 'package:flutter/services.dart';

/// A failure while handing a working copy to an external editor.
class EditorException implements Exception {
  const EditorException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Opens a file with Android's `ACTION_EDIT` intent through a FileProvider
/// (AGENTS.md Phase 5B). The native side grants read and write permission
/// for the working copy only, never for the blob store.
class EditorService {
  const EditorService();

  static const _channel = MethodChannel('subtrack/editor');

  Future<void> openForEdit({
    required String path,
    required String mimeType,
  }) async {
    try {
      final opened = await _channel.invokeMethod<bool>('openForEdit', {
        'path': path,
        'mimeType': mimeType,
      });
      if (opened != true) {
        throw const EditorException('No app can edit this file.');
      }
    } on PlatformException catch (e) {
      throw EditorException(e.message ?? 'No app can edit this file.');
    } on MissingPluginException {
      throw const EditorException(
        'Opening an editor is only available on Android.',
      );
    }
  }
}
