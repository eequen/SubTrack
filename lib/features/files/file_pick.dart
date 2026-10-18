import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

/// Bytes and name of a file the user picked, before it is stored.
class PickedUpload {
  const PickedUpload({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

/// Asks where to pick from (storage or camera) and returns the chosen file,
/// or null when the user cancels. Used by the files screen and the commit
/// screen (mockups 6 and 8).
Future<PickedUpload?> pickFileBytes(BuildContext context) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('From storage'),
            onTap: () => Navigator.of(context).pop('storage'),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Camera'),
            onTap: () => Navigator.of(context).pop('camera'),
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancel'),
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;

  if (source == 'storage') {
    final result = await FilePicker.pickFiles();
    if (result.isEmpty) return null;
    final picked = result.single;
    return PickedUpload(bytes: await picked.readAsBytes(), name: picked.name);
  }
  final picked = await ImagePicker().pickImage(source: ImageSource.camera);
  if (picked == null) return null;
  return PickedUpload(
    bytes: await picked.readAsBytes(),
    name: p.basename(picked.path),
  );
}
