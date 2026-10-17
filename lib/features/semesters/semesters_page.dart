import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/shared/chips.dart';

final _rangeFormat = DateFormat('MMM d');
final _yearFormat = DateFormat('yyyy');

String _dateRange(DateTime start, DateTime end) {
  return '${_rangeFormat.format(start)} - ${_rangeFormat.format(end)}, ${_yearFormat.format(end)}';
}

/// Screen 2 from AGENTS.md section 14: Choose semester.
class SemestersPage extends ConsumerWidget {
  const SemestersPage({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SemesterListItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete semester?'),
        content: Text(
          'This deletes its subjects, activities, files, and versions. '
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
      final selected = ref.read(selectedSemesterProvider);
      await ref.read(semesterRepoProvider).delete(item.semester.id);
      if (selected == item.semester.id) {
        await ref.read(selectedSemesterProvider.notifier).select(null);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authControllerProvider)?.email ?? '';
    final semesters = ref.watch(semestersProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Signed in as $email'),
              const SizedBox(height: 4),
              Text(
                'Choose semester',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: semesters.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Could not load: $e')),
                  data: (items) {
                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('No semesters yet.'),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => context.go('/semesters/new'),
                              child: const Text('+ New semester'),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final s = item.semester;
                        return Card(
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${semesterLabel(s.term)} · SY ${s.schoolYear}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (index == 0) const CurrentChip(),
                              ],
                            ),
                            subtitle: Text(
                              '${item.subjectCount} subjects · ${item.fileCount} files\n${_dateRange(s.startDate, s.endDate)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  _confirmDelete(context, ref, item),
                            ),
                            onTap: () async {
                              await ref
                                  .read(selectedSemesterProvider.notifier)
                                  .select(s.id);
                              if (context.mounted) context.go('/subjects');
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/semesters/new'),
                child: const Text('+ New semester'),
              ),
              TextButton(
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
