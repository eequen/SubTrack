import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/features/subjects/subject_providers.dart';
import 'package:subtrack/shared/ui_components.dart';

/// Opens a subject's lessons, flashcards, and activities in one workspace.
class FileManagerPage extends ConsumerWidget {
  const FileManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semesterId = ref.watch(selectedSemesterProvider);
    if (semesterId == null) {
      return const Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.folder_copy_outlined,
            title: 'Choose a semester first',
            message: 'The file manager organizes the subjects in a semester.',
          ),
        ),
      );
    }
    final subjects = ref.watch(subjectsProvider(semesterId));
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            18,
            AppTheme.screenPadding,
            28,
          ),
          children: [
            Text(
              'File manager',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.palette.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lessons, flashcards, and activities in one place. Choose a '
              'subject to open its workspace.',
              style: TextStyle(color: context.palette.mutedText, height: 1.35),
            ),
            const SizedBox(height: 16),
            subjects.when(
              loading: () =>
                  const AppLoadingState(message: 'Loading subjects...'),
              error: (error, _) =>
                  AppErrorState(message: 'Could not load subjects: $error'),
              data: (items) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: EmptyState(
                      icon: Icons.menu_book_outlined,
                      title: 'No subjects yet',
                      message:
                          'Create a subject from the Subjects screen, then '
                          'return here.',
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in items) ...[
                      _SubjectFolderCard(
                        item: item,
                        onTap: () =>
                            context.push('/subjects/${item.subject.id}/files'),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectFolderCard extends StatelessWidget {
  const _SubjectFolderCard({required this.item, required this.onTap});

  final SubjectListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subject = item.subject;
    final label = subject.name.trim().isEmpty
        ? '?'
        : subject.name.trim()[0].toUpperCase();
    return Opacity(
      opacity: subject.isArchived ? 0.65 : 1,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color(subject.color),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: context.palette.onAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.activityCount} activities · ${item.fileCount} files',
                    style: TextStyle(
                      color: context.palette.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.folder_open_outlined, color: context.palette.accentText),
          ],
        ),
      ),
    );
  }
}
