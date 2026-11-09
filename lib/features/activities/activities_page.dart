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
import 'package:subtrack/shared/editorial.dart';

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

  Future<void> _create() async {
    final result = await showNewActivityDialog(context);
    if (result == null) return;
    await ref
        .read(activityRepoProvider)
        .create(
          subjectId: _subjectId,
          title: result.title,
          notes: result.notes,
          deadline: result.deadline,
          status: result.status,
        );
    await _syncReminders(askPermission: _isFuture(result.deadline));
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
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
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
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Could not load: $e')),
                  data: (_) {
                    if (items.isEmpty) {
                      return const Center(child: Text('No activities yet.'));
                    }
                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('No activities match this filter.'),
                      );
                    }
                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _ActivityCard(
                        item: filtered[index],
                        index: index,
                        onAction: _runAction,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _subjectId <= 0 ? null : _create,
                child: const Text('+ New activity'),
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
            const SectionLabel('Activities / Index', showRule: false),
            const SizedBox(height: 2),
            Text(
              subject.name,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: context.palette.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (countLabel != null)
              Text(
                countLabel!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.palette.mutedText,
                  letterSpacing: 0.2,
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
    required this.index,
    required this.onAction,
  });

  final ActivityListItem item;
  final int index;
  final Future<void> Function(Activity activity) onAction;

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
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: activity.isArchived ? 0.6 : 1,
        child: InkWell(
          onTap: () => context.push('/activities/${activity.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IndexStamp(
                      '0${index + 1}',
                      size: 24,
                      color: context.palette.mutedText,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        activity.title,
                        style: textTheme.titleMedium?.copyWith(
                          color: context.palette.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'Activity actions',
                      onPressed: () => onAction(activity),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusChip(status: activity.status),
                          if (activity.deadline != null)
                            DeadlineChip(deadline: activity.deadline!),
                          if (activity.isArchived)
                            Text(
                              'Archived',
                              style: textTheme.labelSmall?.copyWith(
                                color: context.palette.mutedText,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _filesLabel,
                        style: textTheme.labelSmall?.copyWith(
                          color: context.palette.mutedText,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
