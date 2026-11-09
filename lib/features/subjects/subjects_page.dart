import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/activity_repo.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';
import 'package:subtrack/features/activities/activity_providers.dart';
import 'package:subtrack/features/cloud/backup_status_provider.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/features/semesters/semesters_page.dart';
import 'package:subtrack/features/subjects/subject_dialog.dart';
import 'package:subtrack/features/subjects/subject_providers.dart';
import 'package:subtrack/shared/ui_components.dart';

class SubjectsPage extends ConsumerWidget {
  const SubjectsPage({super.key});

  Future<void> _createSubject(
    BuildContext context,
    WidgetRef ref,
    int semesterId,
  ) async {
    final result = await showNewSubjectDialog(context);
    if (result == null) return;
    await ref
        .read(subjectRepoProvider)
        .create(
          semesterId: semesterId,
          name: result.name,
          color: result.color,
          icon: result.icon,
        );
    await ref.read(localBackupPendingProvider.notifier).markPending();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedSemesterProvider);
    final semesterRepo = ref.watch(semesterRepoProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SemesterHeader(
                          repo: semesterRepo,
                          semesterId: selectedId,
                        ),
                        Text(
                          'My Subjects',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: context.palette.text,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Search',
                    onPressed: selectedId == null
                        ? null
                        : () => context.go('/search'),
                    icon: const Icon(Icons.search),
                  ),
                ],
              ),
            ),
            Expanded(
              child: selectedId == null
                  ? Center(
                      child: Text(
                        'Choose a semester to see its subjects.',
                        style: TextStyle(color: context.palette.mutedText),
                      ),
                    )
                  : _SubjectGrid(
                      semesterId: selectedId,
                      onCreate: () => _createSubject(context, ref, selectedId),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SemesterHeader extends StatelessWidget {
  const _SemesterHeader({required this.repo, required this.semesterId});

  final SemesterRepo repo;
  final int? semesterId;

  @override
  Widget build(BuildContext context) {
    if (semesterId == null) {
      return Text(
        'No semester selected',
        style: TextStyle(color: context.palette.mutedText),
      );
    }
    return StreamBuilder<Semester?>(
      stream: repo.watchById(semesterId!),
      builder: (context, snapshot) {
        final semester = snapshot.data;
        if (semester == null) return const SizedBox(height: 22);
        return InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () => showSemesterChooser(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '${semesterLabel(semester.term)} - SY ${semester.schoolYear}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.palette.accentText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: context.palette.accentText,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SubjectGrid extends ConsumerWidget {
  const _SubjectGrid({required this.semesterId, required this.onCreate});

  final int semesterId;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider(semesterId));
    return subjects.when(
      loading: () => const AppLoadingState(message: 'Loading subjects...'),
      error: (error, _) =>
          AppErrorState(message: 'Could not load subjects: $error'),
      data: (items) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.96,
        ),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == items.length) {
            return _NewSubjectTile(onTap: onCreate);
          }
          return _SubjectCard(item: items[index]);
        },
      ),
    );
  }
}

enum _SubjectAction { rename, archive, unarchive, delete }

class _SubjectCard extends ConsumerWidget {
  const _SubjectCard({required this.item});

  final SubjectListItem item;

  Future<void> _runAction(BuildContext context, WidgetRef ref) async {
    final subject = item.subject;
    final repo = ref.read(subjectRepoProvider);
    final action = await showModalBottomSheet<_SubjectAction>(
      context: context,
      builder: (context) => SheetScaffold(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () => Navigator.of(context).pop(_SubjectAction.rename),
            ),
            ListTile(
              leading: Icon(
                subject.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              title: Text(subject.isArchived ? 'Unarchive' : 'Archive'),
              onTap: () => Navigator.of(context).pop(
                subject.isArchived
                    ? _SubjectAction.unarchive
                    : _SubjectAction.archive,
              ),
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
              onTap: () => Navigator.of(context).pop(_SubjectAction.delete),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case _SubjectAction.rename:
        final name = await showRenameSubjectDialog(
          context,
          currentName: subject.name,
        );
        if (name != null) {
          await repo.rename(subject.id, name);
          await ref.read(localBackupPendingProvider.notifier).markPending();
        }
      case _SubjectAction.archive:
        await repo.setArchived(subject.id, true);
        await ref.read(localBackupPendingProvider.notifier).markPending();
      case _SubjectAction.unarchive:
        await repo.setArchived(subject.id, false);
        await ref.read(localBackupPendingProvider.notifier).markPending();
      case _SubjectAction.delete:
        final backupPending = ref.read(localBackupPendingProvider);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete subject?'),
            content: Text(
              'This deletes "${subject.name}", its activities, files, and '
              'versions. This cannot be undone.'
              '${backupPending ? '\n\nRecent changes have not been backed up. '
                        'Back up now first if you may need to recover them.' : ''}',
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
          await repo.delete(subject.id);
          await ref.read(localBackupPendingProvider.notifier).markPending();
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = item.subject;
    return Opacity(
      opacity: subject.isArchived ? 0.65 : 1,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => context.push('/subjects/${subject.id}/activities'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SubjectBadge(subject: subject),
                const Spacer(),
                IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Subject actions',
                  onPressed: () => _runAction(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subject.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.palette.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${item.activityCount} activities · ${item.fileCount} files',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.palette.mutedText, fontSize: 12),
            ),
            const Spacer(),
            _SubjectProgress(subjectId: subject.id),
          ],
        ),
      ),
    );
  }
}

class _SubjectProgress extends ConsumerWidget {
  const _SubjectProgress({required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities =
        ref.watch(activitiesProvider(subjectId)).value ??
        const <ActivityListItem>[];
    final counts = <String, int>{
      for (final status in ActivityRepo.statuses)
        status: activities
            .where(
              (item) =>
                  item.activity.status == status && !item.activity.isArchived,
            )
            .length,
    };
    final total = counts.values.fold(0, (sum, count) => sum + count);
    final palette = context.palette;
    final segments = [
      (palette.draftText, counts['draft']!),
      (palette.inProgressText, counts['in_progress']!),
      (palette.finalText, counts['final']!),
      (palette.submittedText, counts['submitted']!),
    ].where((segment) => segment.$2 > 0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 8,
        child: total == 0
            ? ColoredBox(color: palette.cardBorder)
            : Row(
                children: [
                  for (final (color, count) in segments)
                    Expanded(
                      flex: count,
                      child: ColoredBox(color: color),
                    ),
                ],
              ),
      ),
    );
  }
}

class _NewSubjectTile extends StatelessWidget {
  const _NewSubjectTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DashedCard(
      onTap: onTap,
      borderColor: context.palette.accent.withValues(alpha: 0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: context.palette.accent, size: 30),
            const SizedBox(height: 8),
            Text(
              'New subject',
              style: TextStyle(
                color: context.palette.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubjectBadge extends StatelessWidget {
  const SubjectBadge({required this.subject, super.key});

  final Subject subject;

  String get _label {
    final icon = subject.icon.trim();
    if (icon.isNotEmpty) return icon;
    final words = subject.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(subject.color),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: context.palette.onAccent,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }
}
