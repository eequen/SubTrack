import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/core/avatar.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/profile/profile_providers.dart';

/// Screen 16 from AGENTS.md section 14: Edit profile.
///
/// The photo is copied into the app's private folder and never leaves the
/// device (constraint 7: no cloud backup of profile photos). The username
/// is read-only: it cannot be changed after sign-up.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _name = TextEditingController();
  bool _filledOnce = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      final documents = await getApplicationDocumentsDirectory();
      final avatars = Directory('${documents.path}/avatars');
      await avatars.create(recursive: true);
      final file = File(
        '${avatars.path}/${avatarFileName(user.id, picked.path)}',
      );
      await file.writeAsBytes(await picked.readAsBytes(), flush: true);
      final previous = ref.read(profileProvider).value?.avatarPath;
      await ref
          .read(profileRepoProvider)
          .update(user.id, avatarPath: file.path);
      // Each pick has its own file, so the old one can go; deleting it also
      // keeps the avatars folder from growing.
      await _deleteAvatar(previous, keep: file.path);
    } catch (e) {
      if (mounted) _snack('Could not save the photo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    setState(() => _busy = true);
    try {
      final path = ref.read(profileProvider).value?.avatarPath;
      await _deleteAvatar(path, keep: '');
      await ref.read(profileRepoProvider).update(user.id, clearAvatar: true);
    } catch (e) {
      if (mounted) _snack('Could not remove the photo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Deletes an old avatar file and drops its cached decode so a new photo
  /// is not hidden behind the previous image (Flutter caches by path).
  Future<void> _deleteAvatar(String? path, {required String keep}) async {
    if (path == null || path.isEmpty || path == keep) return;
    final old = File(path);
    try {
      if (await old.exists()) await old.delete();
    } catch (_) {
      // A missing or locked file must not block the new photo.
    }
    await FileImage(old).evict();
  }

  Future<void> _save() async {
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your display name.');
      return;
    }
    if (name.length > 30) {
      setState(() => _error = 'Display names use 30 characters or fewer.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepoProvider).update(user.id, displayName: name);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save: $e';
        });
      }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final profile = ref.watch(profileProvider).value;
    if (profile != null && !_filledOnce) {
      _name.text = profile.displayName;
      _filledOnce = true;
    }
    final username = profile == null || profile.username.isEmpty
        ? (user?.username.isNotEmpty == true ? user!.username : user?.email)
        : profile.username;
    final hasPhoto =
        profile?.avatarPath != null && profile!.avatarPath!.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Edit profile',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: context.palette.accent,
                foregroundImage: hasPhoto
                    ? FileImage(File(profile.avatarPath!))
                    : null,
                onForegroundImageError: hasPhoto ? (_, _) {} : null,
                child: Text(
                  _name.text.isEmpty ? 'S' : _name.text[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Take photo'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Choose from gallery'),
                ),
                if (hasPhoto)
                  TextButton(
                    onPressed: _busy ? null : _removePhoto,
                    child: const Text('Remove photo'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              key: const ValueKey('display-name-field'),
              controller: _name,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('username-field'),
              enabled: false,
              controller: TextEditingController(text: username),
              decoration: const InputDecoration(
                labelText: 'Username',
                helperText: "Username can't be changed",
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: context.palette.overdue, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              key: const ValueKey('save-profile'),
              onPressed: _busy ? null : _save,
              child: const Text('Save changes'),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
