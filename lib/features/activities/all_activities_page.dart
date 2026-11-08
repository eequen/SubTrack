import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/features/activities/all_activities_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/shared/chips.dart';

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
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) =>
                            Center(child: Text('Could not load: $e')),
                        data: (_) {
                          if (items.isEmpty) {
                            return const Center(
                              child: Text('No activities yet.'),
                            );
                          }
                          if (filtered.isEmpty) {
                            return const Center(
                              child: Text('No activities match this filter.'),
                            );
                          }
                          return ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _AllActivityCard(item: filtered[index]),
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
  const _AllActivityCard({required this.item});

  final AllActivitiesItem item;

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
    return Material(
      color: context.palette.card,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: () => context.push('/activities/${activity.id}'),
        child: Container(
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
                        StatusChip(status: activity.status),
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
        ),
      ),
    );
  }
}
