import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';
import 'package:subtrack/features/activities/activity_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/features/subjects/subject_dialog.dart';
import 'package:subtrack/features/subjects/subject_providers.dart';
import 'package:subtrack/shared/chips.dart';

/// Screen 4 from AGENTS.md section 14: Subjects.
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedSemesterProvider);
    final semesterRepo = ref.watch(semesterRepoProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: selectedId == null
                        ? const Text('My Subjects')
                        : _SemesterHeader(
                            repo: semesterRepo,
                            semesterId: selectedId,
                          ),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/semesters'),
                    child: const Text('Change'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (selectedId != null) _DueSoonCard(semesterId: selectedId),
              Expanded(
                child: selectedId == null
                    ? const Center(
                        child: Text('Choose a semester to see its subjects.'),
                      )
                    : _SubjectList(semesterId: selectedId),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: selectedId == null
                    ? null
                    : () => _createSubject(context, ref, selectedId),
                child: const Text('+ New subject'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SemesterHeader extends StatelessWidget {
  const _SemesterHeader({required this.repo, required this.semesterId});

  final SemesterRepo repo;
  final int semesterId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Semester?>(
      stream: repo.watchById(semesterId),
      builder: (context, snapshot) {
        final s = snapshot.data;
        return Text(
          s == null
              ? 'My Subjects'
              : '${semesterLabel(s.term)} - SY ${s.schoolYear}\nMy Subjects',
        );
      },
    );
  }
}

class _SubjectList extends ConsumerWidget {
  const _SubjectList({required this.semesterId});

  final int semesterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider(semesterId));
    return subjects.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No subjects yet.'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _SubjectCard(item: items[index]),
        );
      },
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
      builder: (context) => SafeArea(
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
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
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
        if (name != null) await repo.rename(subject.id, name);
      case _SubjectAction.archive:
        await repo.setArchived(subject.id, true);
      case _SubjectAction.unarchive:
        await repo.setArchived(subject.id, false);
      case _SubjectAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete subject?'),
            content: Text(
              'This deletes "${subject.name}", its activities, files, and '
              'versions. This cannot be undone.',
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
        if (confirmed == true) await repo.delete(subject.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = item.subject;
    final counts = '${item.activityCount} activities - ${item.fileCount} files';
    return Card(
      child: Opacity(
        opacity: subject.isArchived ? 0.6 : 1,
        child: ListTile(
          leading: SubjectBadge(subject: subject),
          title: Text(
            subject.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subject.isArchived ? 'Archived · $counts' : counts),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Subject actions',
            onPressed: () => _runAction(context, ref),
          ),
          onTap: () => context.push('/subjects/${subject.id}/activities'),
        ),
      ),
    );
  }
}

/// Nearest deadlines this semester (mockup 4); hidden when there are none.
class _DueSoonCard extends ConsumerWidget {
  const _DueSoonCard({required this.semesterId});

  final int semesterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(upcomingProvider(semesterId));
    return upcoming.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Due soon',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final upcoming in items)
                    InkWell(
                      onTap: () =>
                          context.push('/activities/${upcoming.activity.id}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    upcoming.activity.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    upcoming.subjectName,
                                    style: const TextStyle(
                                      color: AppColors.mutedText,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (upcoming.activity.deadline != null)
                              DeadlineChip(
                                deadline: upcoming.activity.deadline!,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Colored circle with the icon if set, otherwise the name's initials.
class SubjectBadge extends StatelessWidget {
  const SubjectBadge({required this.subject, super.key});

  final Subject subject;

  String get _label {
    final icon = subject.icon.trim();
    if (icon.isNotEmpty) return icon;
    final words = subject.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(subject.color);
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        _label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
