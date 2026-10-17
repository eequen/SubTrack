import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/core/format.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/file_repo.dart';
import 'package:subtrack/features/activities/activity_providers.dart';
import 'package:subtrack/features/files/file_providers.dart';
import 'package:subtrack/shared/chips.dart';

/// Screen 6 from AGENTS.md section 14: files of one activity.
class ActivityFilesPage extends ConsumerStatefulWidget {
  const ActivityFilesPage({required this.activityId, super.key});

  final String activityId;

  @override
  ConsumerState<ActivityFilesPage> createState() => _ActivityFilesPageState();
}

class _ActivityFilesPageState extends ConsumerState<ActivityFilesPage> {
  late final int _activityId = int.tryParse(widget.activityId) ?? -1;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/subjects');
    }
  }

  Future<void> _addFile() async {
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
    if (source == null || !mounted) return;

    try {
      Uint8List? bytes;
      String name;
      if (source == 'storage') {
        final result = await FilePicker.pickFiles();
        if (result.isEmpty) return;
        final picked = result.single;
        bytes = await picked.readAsBytes();
        name = picked.name;
      } else {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.camera,
        );
        if (picked == null) return;
        bytes = await picked.readAsBytes();
        name = p.basename(picked.path);
      }
      await ref
          .read(fileRepoProvider)
          .upload(activityId: _activityId, bytes: bytes, displayName: name);
    } catch (e) {
      _snack('Could not add file: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open(FileListItem item) async {
    final commit = item.currentCommit;
    if (commit == null) return;
    try {
      final file = await ref
          .read(blobStoreProvider)
          .exportForOpening(commit.blobHash, item.file.displayName);
      final status = await OpenFilex.open(file.path);
      if (status.type != ResultType.done) {
        _snack('No app found to open this file.');
      }
    } catch (e) {
      _snack('Could not open the file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(activityProvider(_activityId));
    final files = ref.watch(filesProvider(_activityId));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                    onPressed: _back,
                  ),
                  Expanded(
                    child: activity.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const Text('Activity not found'),
                      data: (a) => a == null
                          ? const Text('Activity not found')
                          : _ActivityHeader(activity: a),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: files.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Could not load: $e')),
                  data: (items) {
                    if (items.isEmpty) {
                      return const Center(child: Text('No files yet.'));
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _FileCard(
                        item: items[index],
                        onOpen: () => _open(items[index]),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _activityId <= 0 ? null : _addFile,
                child: const Text('+ Add file'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final notes = activity.notes.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activity.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            StatusChip(status: activity.status),
            if (activity.deadline != null) ...[
              const SizedBox(width: 8),
              DeadlineChip(deadline: activity.deadline!),
            ],
          ],
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            notes,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.item, required this.onOpen});

  final FileListItem item;
  final VoidCallback onOpen;

  static final _dateFormat = DateFormat('MMM d, h:mm a');

  @override
  Widget build(BuildContext context) {
    final commit = item.currentCommit;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.file.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (commit != null)
                  Text(
                    'v${commit.versionNo}',
                    style: const TextStyle(color: AppColors.mutedText),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (commit != null) ...[
              Text(
                '${commit.message} · ${_dateFormat.format(commit.createdAt)}',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                formatBytes(commit.sizeBytes),
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _CardButton(label: 'Open', onPressed: onOpen),
                const SizedBox(width: 8),
                _CardButton(
                  label: 'History',
                  onPressed: () =>
                      context.push('/files/${item.file.id}/history'),
                ),
                const SizedBox(width: 8),
                _CardButton(
                  label: 'Commit',
                  onPressed: () =>
                      context.push('/files/${item.file.id}/commit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
