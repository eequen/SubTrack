import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/repositories/search_repo.dart';
import 'package:subtrack/features/search/search_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';

/// Screen 9 from AGENTS.md section 14: search inside the chosen semester.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();

  /// null means the All chip.
  String? _filter;

  static const _filters = <(String, String?)>[
    ('All', null),
    ('Files', 'files'),
    ('Activities', 'activities'),
    ('Commits', 'commits'),
  ];

  static const _emptyHint =
      'Search subjects, activities, files, and commit messages.';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).setQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final semesterId = ref.watch(selectedSemesterProvider);
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Search',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search this semester',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.trim().isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear',
                          onPressed: _clear,
                        ),
                ),
                onChanged: (text) =>
                    ref.read(searchQueryProvider.notifier).setQuery(text),
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
              Expanded(child: _resultsArea(semesterId, query, results)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultsArea(
    int? semesterId,
    String query,
    AsyncValue<SearchResults> results,
  ) {
    if (semesterId == null) {
      return const Center(child: Text('Choose a semester first.'));
    }
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const Center(child: Text(_emptyHint, textAlign: TextAlign.center));
    }
    // While a new query runs, `value` keeps the previous results so the
    // list does not blink on every keystroke.
    final value = results.value;
    if (value == null) {
      if (results.hasError) {
        return Center(child: Text('Could not search: ${results.error}'));
      }
      return const Center(child: CircularProgressIndicator());
    }

    final showAll = _filter == null;
    final files = showAll || _filter == 'files'
        ? value.files
        : const <FileHit>[];
    final activities = showAll || _filter == 'activities'
        ? value.activities
        : const <ActivityHit>[];
    final commits = showAll || _filter == 'commits'
        ? value.commits
        : const <CommitHit>[];

    if (files.isEmpty && activities.isEmpty && commits.isEmpty) {
      final text = switch (_filter) {
        'files' => 'No files match "$trimmed".',
        'activities' => 'No activities match "$trimmed".',
        'commits' => 'No commits match "$trimmed".',
        _ => 'No results for "$trimmed".',
      };
      return Center(child: Text(text));
    }

    return ListView(
      children: [
        if (files.isNotEmpty)
          _Section(
            label: 'Files',
            children: [for (final hit in files) _fileCard(hit)],
          ),
        if (activities.isNotEmpty)
          _Section(
            label: 'Activities',
            children: [for (final hit in activities) _activityCard(hit)],
          ),
        if (commits.isNotEmpty)
          _Section(
            label: 'Commits',
            children: [for (final hit in commits) _commitCard(hit)],
          ),
      ],
    );
  }

  Widget _fileCard(FileHit hit) {
    return _ResultCard(
      icon: Icons.insert_drive_file_outlined,
      title: hit.file.displayName,
      path: '${hit.subjectName} > ${hit.activityTitle}',
      onTap: () => context.push('/files/${hit.file.id}/history'),
    );
  }

  Widget _activityCard(ActivityHit hit) {
    return _ResultCard(
      icon: Icons.assignment_outlined,
      title: hit.activity.title,
      path: hit.subjectName,
      onTap: () => context.push('/activities/${hit.activity.id}'),
    );
  }

  Widget _commitCard(CommitHit hit) {
    return _ResultCard(
      icon: Icons.history,
      title: 'v${hit.commit.versionNo} - ${hit.commit.message}',
      path: '${hit.subjectName} > ${hit.activityTitle} > ${hit.fileName}',
      onTap: () => context.push('/files/${hit.commit.fileId}/history'),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.mutedText,
            ),
          ),
        ),
        ...children,
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.icon,
    required this.title,
    required this.path,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
