import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/features/activities/activity_dialog.dart';
import 'package:subtrack/features/activities/activity_providers.dart';
import 'package:subtrack/features/activities/all_activities_providers.dart';
import 'package:subtrack/features/reminders/reminder_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/features/subjects/subject_providers.dart';
import 'package:subtrack/shared/chips.dart';
import 'package:subtrack/shared/status_sheet.dart';
import 'package:subtrack/shared/ui_components.dart';

/// Screen 9 from AGENTS.md section 14: every activity in the chosen
/// semester across all subjects, with filter chips (All, Due soon, and the
/// four statuses). Home's See all opens this screen with the Due soon
/// filter already active.
class AllActivitiesPage extends ConsumerStatefulWidget {
  const AllActivitiesPage({this.initialFilter, super.key});

  final String? initialFilter;

  @override
  ConsumerState<AllActivitiesPage> createState() => _AllActivitiesPageState();
}

class _AllActivitiesPageState extends ConsumerState<AllActivitiesPage> {
  late String? _filter = widget.initialFilter;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
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
      await ref.read(reminderServiceProvider).syncAll();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update status: $error')),
      );
    }
  }

  Future<void> _addActivity() async {
    final semesterId = ref.read(selectedSemesterProvider);
    if (semesterId == null) {
      _snack('Choose a semester before adding an activity.');
      return;
    }

    try {
      final subjects = await ref.read(subjectsProvider(semesterId).future);
      if (!mounted) return;
      if (subjects.isEmpty) {
        _snack('Create a subject before adding an activity.');
        return;
      }

      final subjectId = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SheetScaffold(
          title: 'Choose a subject',
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.55,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: subjects.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final subject = subjects[index].subject;
                return AppCard(
                  padding: EdgeInsets.zero,
                  onTap: () => Navigator.of(context).pop(subject.id),
                  child: ListTile(
                    title: Text(subject.name),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: context.palette.mutedText,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      if (subjectId == null || !mounted) return;

      final result = await showNewActivityDialog(context);
      if (result == null || !mounted) return;
      await ref
          .read(activityRepoProvider)
          .create(
            subjectId: subjectId,
            title: result.title,
            notes: result.notes,
            deadline: result.deadline,
            status: result.status,
          );
      final reminders = ref.read(reminderServiceProvider);
      if (result.deadline?.isAfter(DateTime.now()) == true) {
        await reminders.requestPermission();
      }
      await reminders.syncAll();
    } catch (error) {
      _snack('Could not add activity: $error');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedSemesterProvider);
    final itemsAsync = ref.watch(allActivitiesProvider);
    final items = itemsAsync.value ?? const <AllActivitiesItem>[];

    final filtered = items.where((item) {
      switch (_filter) {
        case null:
          return true;
        case 'due_soon':
          return _isDueSoon(item.activity.deadline, item.activity.status);
        default:
          return item.activity.status == _filter;
      }
    }).toList();

    final canBuildList = selectedId != null;

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
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'All activities',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${items.length} ${items.length == 1 ? 'activity' : 'activities'}',
                          style: TextStyle(
                            color: context.palette.mutedText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: canBuildList ? _addActivity : null,
                    icon: const Icon(Icons.add),
                    label: const Text('New activity'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                child: !canBuildList
                    ? const _NoSemesterState()
                    : itemsAsync.when(
                        loading: () => const AppLoadingState(
                          message: 'Loading activities...',
                        ),
                        error: (e, _) => AppErrorState(
                          message: 'Could not load activities: $e',
                        ),
                        data: (_) {
                          if (items.isEmpty) {
                            return const EmptyState(
                              icon: Icons.assignment_outlined,
                              title: 'No activities yet.',
                              message: 'Add an activity to start tracking your work.',
                            );
                          }
                          if (filtered.isEmpty) {
                            return const EmptyState(
                              icon: Icons.filter_list,
                              title: 'No activities match this filter.',
                              message: 'Choose another filter to see more activities.',
                            );
                          }
                          return ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) => _AllActivityCard(
                              item: filtered[index],
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

  /// Not submitted and with a deadline before the end of the week window;
  /// overdue activities count too (they are the most due).
  bool _isDueSoon(DateTime? deadline, String status) {
    if (deadline == null || status == 'submitted') {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final windowEnd = today.add(const Duration(days: 7));
    return deadline.isBefore(windowEnd);
  }
}

const _filters = <(String, String?)>[
  ('All', null),
  ('Due soon', 'due_soon'),
  ('Draft', 'draft'),
  ('In progress', 'in_progress'),
  ('Final', 'final'),
  ('Submitted', 'submitted'),
];

class _NoSemesterState extends StatelessWidget {
  const _NoSemesterState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Choose a semester first.'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push('/semesters'),
            child: const Text('Choose semester'),
          ),
        ],
      ),
    );
  }
}

class _AllActivityCard extends StatelessWidget {
  const _AllActivityCard({required this.item, required this.onStatus});

  final AllActivitiesItem item;
  final Future<void> Function(Activity activity) onStatus;

  String get _filesLabel {
    final n = item.fileCount;
    final v = item.latestVersion;
    if (n == 0) return 'No files yet.';
    final noun = n == 1 ? '1 file' : '$n files';
    return v == null ? noun : '$noun - latest v$v';
  }

  @override
  Widget build(BuildContext context) {
    final activity = item.activity;
    return AppCard(
      onTap: () => context.push('/activities/${activity.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.subjectName,
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    StatusChip(
                      status: activity.status,
                      onTap: () => onStatus(activity),
                    ),
                    if (activity.deadline != null) ...[
                      const SizedBox(width: 8),
                      DeadlineChip(deadline: activity.deadline!),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
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
          Icon(Icons.chevron_right, color: context.palette.mutedText),
        ],
      ),
    );
  }
}
