import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/activity_repo.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';
import 'package:subtrack/features/activities/activity_dialog.dart';
import 'package:subtrack/features/activities/activity_providers.dart';
import 'package:subtrack/features/reminders/reminder_providers.dart';
import 'package:subtrack/features/subjects/subject_providers.dart';
import 'package:subtrack/shared/chips.dart';
import 'package:subtrack/shared/status_sheet.dart';
import 'package:subtrack/shared/ui_components.dart';

/// Screen 5 from AGENTS.md section 14: Activities of one subject.
class ActivitiesPage extends ConsumerStatefulWidget {
  const ActivitiesPage({required this.subjectId, super.key});

  final String subjectId;

  @override
  ConsumerState<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends ConsumerState<ActivitiesPage> {
  /// null means the All chip.
  String? _filter;

  late final int _subjectId = int.tryParse(widget.subjectId) ?? -1;

  @override
  void initState() {
    super.initState();
    // Keep the notification schedule in step with the database (after a
    // reinstall, restored data, or alarms cleared by the system).
    unawaited(ref.read(reminderServiceProvider).syncAll());
  }

  bool _isFuture(DateTime? deadline) =>
      deadline != null && deadline.isAfter(DateTime.now());

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Re-creates deadline reminders after an activity changed; asks for the
  /// notification permission when a future deadline was just saved.
  Future<void> _syncReminders({bool askPermission = false}) async {
    final service = ref.read(reminderServiceProvider);
    if (askPermission && !await service.requestPermission()) {
      _snack('Allow notifications to get deadline reminders.');
    }
    await service.syncAll();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/subjects');
    }
  }

  Future<void> _changeStatus(Activity activity) async {
    final status = await showStatusSheet(
      context,
      currentStatus: activity.status,
    );
    if (status == null || status == activity.status || !mounted) return;
    try {
      await ref
          .read(activityRepoProvider)
          .updateDetails(id: activity.id, status: status);
      await _syncReminders();
    } catch (error) {
      _snack('Could not update status: $error');
    }
  }

  Future<void> _runAction(Activity activity) async {
    final repo = ref.read(activityRepoProvider);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            ListTile(
              leading: Icon(
                activity.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              title: Text(activity.isArchived ? 'Unarchive' : 'Archive'),
              onTap: () =>
                  Navigator.of(context)
                      .pop(activity.isArchived ? 'unarchive' : 'archive'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: context.palette.overdue,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: context.palette.overdue),
              ),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case 'edit':
        final result = await showEditActivityDialog(
          context,
          title: activity.title,
          notes: activity.notes,
          deadline: activity.deadline,
          status: activity.status,
        );
        if (result != null) {
          await repo.updateDetails(
            id: activity.id,
            title: result.title,
            notes: result.notes,
            status: result.status,
          );
          await repo.setDeadline(activity.id, result.deadline);
          await _syncReminders(askPermission: _isFuture(result.deadline));
        }
      case 'archive':
        await repo.setArchived(activity.id, true);
        await _syncReminders();
      case 'unarchive':
        await repo.setArchived(activity.id, false);
        await _syncReminders();
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete activity?'),
            content: Text(
              'This deletes "${activity.title}", its files, and versions. '
              'This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await repo.delete(activity.id);
          await _syncReminders();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectRepo = ref.watch(subjectRepoProvider);
    final activities = ref.watch(activitiesProvider(_subjectId));
    final items = activities.value ?? const <ActivityListItem>[];
    final filtered = _filter == null
        ? items
        : items.where((i) => i.activity.status == _filter).toList();

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
                    child: _SubjectHeader(
                      repo: subjectRepo,
                      subjectId: _subjectId,
                      countLabel: activities.whenOrNull(
                        data: (list) => list.length == 1
                            ? '1 activity'
                            : '${list.length} activities',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (label, value) in _filters)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(label),
                          selected: _filter == value,
                          onSelected: (_) => setState(() => _filter = value),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: activities.when(
                  loading: () =>
                      const AppLoadingState(message: 'Loading activities...'),
                  error: (e, _) =>
                      AppErrorState(message: 'Could not load activities: $e'),
                  data: (_) {
                    if (items.isEmpty) {
                      return const EmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'No activities yet.',
                        message: 'Tap + to add your first activity.',
                      );
                    }
                    if (filtered.isEmpty) {
                      return const EmptyState(
                        icon: Icons.filter_list,
                        title: 'No activities match this filter.',
                        message:
                            'Choose another status to see more activities.',
                      );
                    }
                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _ActivityCard(
                        item: filtered[index],
                        onAction: _runAction,
                        onStatus: _changeStatus,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _filters = <(String, String?)>[
  ('All', null),
  ('Draft', 'draft'),
  ('In progress', 'in_progress'),
  ('Final', 'final'),
  ('Submitted', 'submitted'),
];

class _SubjectHeader extends StatelessWidget {
  const _SubjectHeader({
    required this.repo,
    required this.subjectId,
    required this.countLabel,
  });

  final SubjectRepo repo;
  final int subjectId;
  final String? countLabel;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Subject?>(
      stream: repo.watchById(subjectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final subject = snapshot.data;
        if (subject == null) {
          return const Text('Subject not found');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (countLabel != null)
              Text(
                countLabel!,
                style: TextStyle(
                  color: context.palette.mutedText,
                  fontSize: 13,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ActivityCard extends ConsumerWidget {
  const _ActivityCard({
    required this.item,
    required this.onAction,
    required this.onStatus,
  });

  final ActivityListItem item;
  final Future<void> Function(Activity activity) onAction;
  final Future<void> Function(Activity activity) onStatus;

  String get _filesLabel {
    final n = item.fileCount;
    final v = item.latestVersion;
    if (n == 0) return 'No files yet.';
    final noun = n == 1 ? '1 file' : '$n files';
    return v == null ? noun : '$noun - latest v$v';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = item.activity;
    return Opacity(
      opacity: activity.isArchived ? 0.65 : 1,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        onTap: () => context.push('/activities/${activity.id}'),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      StatusChip(
                        status: activity.status,
                        onTap: () => onStatus(activity),
                      ),
                      if (activity.deadline != null)
                        DeadlineChip(deadline: activity.deadline!),
                      if (activity.isArchived)
                        Text(
                          'Archived',
                          style: TextStyle(
                            color: context.palette.mutedText,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _filesLabel,
                    style: TextStyle(color: context.palette.mutedText),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Activity actions',
              onPressed: () => onAction(activity),
            ),
          ],
        ),
      ),
    );
  }
}
