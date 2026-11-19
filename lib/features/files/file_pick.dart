import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/shared/ui_components.dart';

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
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => SheetScaffold(
      title: 'Add file',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FileSourceTile(
            icon: Icons.folder_open_outlined,
            title: 'From storage',
            onTap: () => Navigator.of(context).pop('storage'),
          ),
          const SizedBox(height: 8),
          _FileSourceTile(
            icon: Icons.camera_alt_outlined,
            title: 'Camera',
            onTap: () => Navigator.of(context).pop('camera'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
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

class _FileSourceTile extends StatelessWidget {
  const _FileSourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: context.palette.accentText),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Icon(Icons.chevron_right, color: context.palette.mutedText),
        ],
      ),
    );
  }
}
