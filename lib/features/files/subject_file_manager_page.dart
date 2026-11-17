import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/activity_repo.dart';
import 'package:subtrack/data/repositories/flashcard_repo.dart';
import 'package:subtrack/features/activities/activity_dialog.dart';
import 'package:subtrack/features/activities/activity_providers.dart';
import 'package:subtrack/features/cloud/backup_status_provider.dart';
import 'package:subtrack/features/flashcards/flashcard_dialogs.dart';
import 'package:subtrack/features/flashcards/flashcard_providers.dart';
import 'package:subtrack/features/lessons/lesson_dialog.dart';
import 'package:subtrack/features/reminders/reminder_providers.dart';
import 'package:subtrack/features/subjects/subject_providers.dart';
import 'package:subtrack/shared/chips.dart';
import 'package:subtrack/shared/status_sheet.dart';
import 'package:subtrack/shared/ui_components.dart';

final _dueFormat = DateFormat('MMM d');

/// One subject workspace: separate lesson folders, local flashcard decks, and
/// activities that keep the existing files/commits workflow.
class SubjectFileManagerPage extends ConsumerStatefulWidget {
  const SubjectFileManagerPage({required this.subjectId, super.key});

  final String subjectId;

  @override
  ConsumerState<SubjectFileManagerPage> createState() =>
      _SubjectFileManagerPageState();
}

class _SubjectFileManagerPageState
    extends ConsumerState<SubjectFileManagerPage> {
  late final int _subjectId = int.tryParse(widget.subjectId) ?? -1;
  String _tab = 'lessons';

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/subjects');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _markPending() async {
    await ref.read(localBackupPendingProvider.notifier).markPending();
  }

  Future<void> _createLesson() async {
    final result = await showLessonDialog(context);
    if (result == null || !mounted) return;
    try {
      final id = await ref
          .read(activityRepoProvider)
          .create(
            subjectId: _subjectId,
            title: result.title,
            kind: ActivityRepo.lessonKind,
            notes: result.notes,
          );
      await _markPending();
      if (mounted) context.push('/activities/$id');
    } catch (error) {
      _snack('Could not create lesson: $error');
    }
  }

  Future<void> _editLesson(Activity lesson) async {
    final result = await showLessonDialog(
      context,
      initialTitle: lesson.title,
      initialNotes: lesson.notes,
    );
    if (result == null || !mounted) return;
    await ref
        .read(activityRepoProvider)
        .updateDetails(id: lesson.id, title: result.title, notes: result.notes);
    await _markPending();
  }

  Future<void> _deleteLesson(Activity lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete lesson?'),
        content: Text(
          'This deletes "${lesson.title}", its files, and versions. This '
          'cannot be undone.',
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
    if (confirmed != true || !mounted) return;
    await ref.read(activityRepoProvider).delete(lesson.id);
    await _markPending();
  }

  Future<void> _createDeck() async {
    final name = await showDeckNameDialog(context);
    if (name == null || !mounted) return;
    try {
      final id = await ref
          .read(flashcardRepoProvider)
          .createDeck(subjectId: _subjectId, name: name);
      await _markPending();
      if (mounted) context.push('/decks/$id');
    } catch (error) {
      _snack('Could not create deck: $error');
    }
  }

  Future<void> _importDeck() async {
    await context.push('/flashcards/import?subject=$_subjectId');
  }

  Future<void> _createActivity() async {
    final result = await showNewActivityDialog(context);
    if (result == null || !mounted) return;
    try {
      await ref
          .read(activityRepoProvider)
          .create(
            subjectId: _subjectId,
            title: result.title,
            notes: result.notes,
            deadline: result.deadline,
            status: result.status,
          );
      await _markPending();
      await ref.read(reminderServiceProvider).syncAll();
    } catch (error) {
      _snack('Could not create activity: $error');
    }
  }

  Future<void> _changeStatus(Activity activity) async {
    final status = await showStatusSheet(
      context,
      currentStatus: activity.status,
    );
    if (status == null || status == activity.status || !mounted) return;
    await ref
        .read(activityRepoProvider)
        .updateDetails(id: activity.id, status: status);
    await _markPending();
    await ref.read(reminderServiceProvider).syncAll();
  }

  Future<void> _activityAction(Activity activity) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SheetScaffold(
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
    final repo = ref.read(activityRepoProvider);
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
          await _markPending();
          await ref.read(reminderServiceProvider).syncAll();
        }
      case 'archive':
        await repo.setArchived(activity.id, true);
        await _markPending();
        await ref.read(reminderServiceProvider).syncAll();
      case 'unarchive':
        await repo.setArchived(activity.id, false);
        await _markPending();
        await ref.read(reminderServiceProvider).syncAll();
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
          await _markPending();
          await ref.read(reminderServiceProvider).syncAll();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectAsync = ref.watch(subjectProvider(_subjectId));
    final lessons = ref.watch(lessonsProvider(_subjectId)).value;
    final decks = ref.watch(decksBySubjectProvider(_subjectId)).value;
    final activities = ref.watch(activitiesProvider(_subjectId)).value;
    return Scaffold(
      body: SafeArea(
        child: subjectAsync.when(
          loading: () => const AppLoadingState(message: 'Loading subject...'),
          error: (error, _) =>
              AppErrorState(message: 'Could not load subject: $error'),
          data: (subject) {
            if (subject == null) {
              return const AppErrorState(message: 'Subject not found.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      _SubjectMark(subject: subject),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${lessons?.length ?? 0} lessons · '
                              '${decks?.length ?? 0} decks · '
                              '${activities?.length ?? 0} activities',
                              style: TextStyle(
                                color: context.palette.mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.screenPadding,
                    8,
                    AppTheme.screenPadding,
                    12,
                  ),
                  child: SegmentedSelector(
                    options: const [
                      SegmentOption(value: 'lessons', label: 'Lessons'),
                      SegmentOption(value: 'flashcards', label: 'Flashcards'),
                      SegmentOption(value: 'activities', label: 'Activities'),
                    ],
                    value: _tab,
                    onChanged: (value) => setState(() => _tab = value),
                  ),
                ),
                Expanded(
                  child: switch (_tab) {
                    'flashcards' => _flashcardsTab(),
                    'activities' => _activitiesTab(),
                    _ => _lessonsTab(),
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _lessonsTab() {
    final lessons = ref.watch(lessonsProvider(_subjectId));
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        2,
        AppTheme.screenPadding,
        24,
      ),
      children: [
        DashedCard(
          borderColor: context.palette.accent.withValues(alpha: 0.6),
          onTap: _createLesson,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.create_new_folder_outlined),
                SizedBox(width: 10),
                Text(
                  'New lesson folder',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        lessons.when(
          loading: () => const AppLoadingState(message: 'Loading lessons...'),
          error: (error, _) =>
              AppErrorState(message: 'Could not load lessons: $error'),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.folder_outlined,
                title: 'No lessons yet',
                message:
                    'A lesson is a folder with its own files and version '
                    'history, separate from activities.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in items) ...[
                  _LessonCard(
                    item: item,
                    onEdit: () => _editLesson(item.activity),
                    onDelete: () => _deleteLesson(item.activity),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _flashcardsTab() {
    final decks = ref.watch(decksBySubjectProvider(_subjectId));
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        2,
        AppTheme.screenPadding,
        24,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _createDeck,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('New deck'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _importDeck,
                icon: const Icon(Icons.auto_awesome_outlined, size: 20),
                label: const Text('Import with AI'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.palette.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.palette.cardBorder),
          ),
          child: Row(
            children: [
              Icon(
                Icons.phonelink_lock_outlined,
                size: 18,
                color: context.palette.accentText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Flashcards stay on this phone and are included in local '
                  'backups only.',
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        decks.when(
          loading: () => const AppLoadingState(message: 'Loading decks...'),
          error: (error, _) =>
              AppErrorState(message: 'Could not load decks: $error'),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.style_outlined,
                title: 'No decks yet',
                message:
                    'Create a deck by hand, or import an AI reply for this '
                    'subject.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in items) ...[
                  _DeckRow(item: item),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _activitiesTab() {
    final activities = ref.watch(activitiesProvider(_subjectId));
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        2,
        AppTheme.screenPadding,
        24,
      ),
      children: [
        Center(
          child: TextButton.icon(
            onPressed: _createActivity,
            icon: const Icon(Icons.add),
            label: const Text('New activity'),
          ),
        ),
        const SizedBox(height: 6),
        activities.when(
          loading: () =>
              const AppLoadingState(message: 'Loading activities...'),
          error: (error, _) =>
              AppErrorState(message: 'Could not load activities: $error'),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.assignment_outlined,
                title: 'No activities yet',
                message:
                    'Activities track deadlines and status. Lessons keep '
                    'lesson material separate.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in items) ...[
                  _ActivityRow(
                    item: item,
                    onStatus: () => _changeStatus(item.activity),
                    onAction: () => _activityAction(item.activity),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SubjectMark extends StatelessWidget {
  const _SubjectMark({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final label = subject.name.trim().isEmpty
        ? '?'
        : subject.name.trim()[0].toUpperCase();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(subject.color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.palette.onAccent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final ActivityListItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String get _filesLabel {
    final n = item.fileCount;
    final v = item.latestVersion;
    if (n == 0) return 'No files yet';
    final noun = n == 1 ? '1 file' : '$n files';
    return v == null ? noun : '$noun · latest v$v';
  }

  @override
  Widget build(BuildContext context) {
    final lesson = item.activity;
    return AppCard(
      onTap: () => context.push('/activities/${lesson.id}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.palette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.folder_outlined,
              color: context.palette.accentText,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _filesLabel,
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 12,
                  ),
                ),
                if (lesson.notes.trim().isNotEmpty)
                  Text(
                    lesson.notes.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.palette.mutedText,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Lesson actions',
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit lesson')),
              PopupMenuItem(value: 'delete', child: Text('Delete lesson')),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeckRow extends StatelessWidget {
  const _DeckRow({required this.item});

  final DeckListItem item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/decks/${item.deck.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.palette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.style_outlined,
              color: context.palette.accentText,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.deck.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${item.cardCount} ${item.cardCount == 1 ? 'card' : 'cards'}'
                  '${item.deck.source == 'ai_import' ? ' · AI import' : ''}',
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.item,
    required this.onStatus,
    required this.onAction,
  });

  final ActivityListItem item;
  final VoidCallback onStatus;
  final VoidCallback onAction;

  String get _filesLabel {
    final n = item.fileCount;
    final v = item.latestVersion;
    if (n == 0) return 'No files yet';
    final noun = n == 1 ? '1 file' : '$n files';
    return v == null ? noun : '$noun · latest v$v';
  }

  @override
  Widget build(BuildContext context) {
    final activity = item.activity;
    return Opacity(
      opacity: activity.isArchived ? 0.65 : 1,
      child: AppCard(
        onTap: () => context.push('/activities/${activity.id}'),
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusChip(status: activity.status, onTap: onStatus),
                      if (activity.deadline != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.palette.deadlineBg,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'Due ${_dueFormat.format(activity.deadline!)}',
                            style: TextStyle(
                              color: context.palette.deadlineText,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (activity.isArchived)
                        Text(
                          'Archived',
                          style: TextStyle(
                            color: context.palette.mutedText,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _filesLabel,
                    style: TextStyle(
                      color: context.palette.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Activity actions',
              onPressed: onAction,
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
      ),
    );
  }
}
