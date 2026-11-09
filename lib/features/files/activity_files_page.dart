import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/core/format.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/activity_repo.dart';
import 'package:subtrack/data/repositories/file_repo.dart';
import 'package:subtrack/features/activities/activity_providers.dart';
import 'package:subtrack/features/edit/edit_providers.dart';
import 'package:subtrack/features/files/file_providers.dart';
import 'package:subtrack/features/profile/profile_providers.dart';
import 'package:subtrack/features/reminders/reminder_providers.dart';
import 'package:subtrack/shared/card_button.dart';
import 'package:subtrack/shared/chips.dart';
import 'package:subtrack/shared/ui_components.dart';

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
    try {
      final picked = await ref.read(filePickerProvider)(context);
      if (picked == null || !mounted) return;
      await ref
          .read(fileRepoProvider)
          .upload(
            activityId: _activityId,
            bytes: picked.bytes,
            displayName: picked.name,
          );
    } catch (e) {
      _snack('Could not add file: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setStatus(Activity activity, String status) async {
    if (activity.status == status) return;
    try {
      await ref
          .read(activityRepoProvider)
          .updateDetails(id: activity.id, status: status);
      await ref.read(reminderServiceProvider).syncAll();
    } catch (error) {
      _snack('Could not update status: $error');
    }
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
    final editing =
        ref.watch(activeEditSessionsProvider(_activityId)).value ??
        const <int>{};
    final remindersEnabled =
        ref.watch(profileProvider).value?.remindDeadlines ?? true;

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
                      data: (a) => Text(
                        a?.title ?? 'Activity not found',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              activity.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (a) => a == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ActivityDetails(
                          activity: a,
                          remindersEnabled: remindersEnabled,
                          onStatusChanged: (status) => _setStatus(a, status),
                        ),
                      ),
              ),
              Expanded(
                child: files.when(
                  loading: () =>
                      const AppLoadingState(message: 'Loading files...'),
                  error: (e, _) =>
                      AppErrorState(message: 'Could not load files: $e'),
                  data: (items) {
                    if (items.isEmpty) {
                      return const EmptyState(
                        icon: Icons.folder_open_outlined,
                        title: 'No files yet.',
                        message: 'Add a file to keep your work in one place.',
                        showBrandLogo: true,
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _FileCard(
                        item: items[index],
                        hasActiveEdit: editing.contains(items[index].file.id),
                        onOpen: () => _open(items[index]),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: '+ Add file',
                onPressed: _activityId <= 0 ? null : _addFile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityDetails extends StatelessWidget {
  const _ActivityDetails({
    required this.activity,
    required this.remindersEnabled,
    required this.onStatusChanged,
  });

  final Activity activity;
  final bool remindersEnabled;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final notes = activity.notes.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedSelector(
          options: [
            for (final status in ActivityRepo.statuses)
              SegmentOption(value: status, label: statusLabel(status)),
          ],
          value: activity.status,
          onChanged: onStatusChanged,
        ),
        if (activity.deadline != null) ...[
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.event_outlined, color: context.palette.deadlineText),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Due ${DateFormat('EEE, MMM d').format(activity.deadline!)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        remindersEnabled
                            ? 'Reminder: 1 day before'
                            : 'Deadline reminders are off in Profile',
                        style: TextStyle(
                          color: context.palette.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                DeadlineChip(deadline: activity.deadline!),
              ],
            ),
          ),
        ],
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            notes,
            style: TextStyle(color: context.palette.mutedText, fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.item,
    required this.hasActiveEdit,
    required this.onOpen,
  });

  final FileListItem item;
  final bool hasActiveEdit;
  final VoidCallback onOpen;

  static final _dateFormat = DateFormat('MMM d, h:mm a');

  @override
  Widget build(BuildContext context) {
    final commit = item.currentCommit;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.file.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasActiveEdit) ...[
                const SizedBox(width: 6),
                const EditingChip(),
              ],
              if (commit != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    'v${commit.versionNo}',
                    style: TextStyle(color: context.palette.mutedText),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (commit != null) ...[
            Text(
              '${commit.message} · ${_dateFormat.format(commit.createdAt)}',
              style: TextStyle(color: context.palette.mutedText, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              formatBytes(commit.sizeBytes),
              style: TextStyle(color: context.palette.mutedText, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CardButton(label: 'Open', onPressed: onOpen),
              CardButton(
                label: 'Edit',
                onPressed: () => context.push('/files/${item.file.id}/edit'),
              ),
              CardButton(
                label: 'History',
                onPressed: () => context.push('/files/${item.file.id}/history'),
              ),
              CardButton(
                label: 'Commit',
                onPressed: () => context.push('/files/${item.file.id}/commit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
