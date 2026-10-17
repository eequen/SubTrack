import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/core/format.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/features/files/file_providers.dart';
import 'package:subtrack/shared/card_button.dart';
import 'package:subtrack/shared/chips.dart';

final _dateFormat = DateFormat('MMM d, y · h:mm a');

/// Screen 7 from AGENTS.md section 14: version history of one file.
/// Restoring never deletes: it copies an old version into a new commit.
class VersionHistoryPage extends ConsumerStatefulWidget {
  const VersionHistoryPage({required this.fileId, super.key});

  final String fileId;

  @override
  ConsumerState<VersionHistoryPage> createState() => _VersionHistoryPageState();
}

class _VersionHistoryPageState extends ConsumerState<VersionHistoryPage> {
  late final int _fileId = int.tryParse(widget.fileId) ?? -1;

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

  Future<void> _open(String displayName, Commit commit) async {
    try {
      final file = await ref
          .read(blobStoreProvider)
          .exportForOpening(commit.blobHash, displayName);
      final status = await OpenFilex.open(file.path);
      if (status.type != ResultType.done) {
        _snack('No app found to open this file.');
      }
    } catch (e) {
      _snack('Could not open the file: $e');
    }
  }

  Future<void> _restore(Commit commit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore v${commit.versionNo}?'),
        content: Text(
          'This copies v${commit.versionNo} into a new version. '
          'Nothing is deleted — every version stays in the history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(commitRepoProvider)
          .restoreAsNewCommit(fileId: _fileId, fromCommitId: commit.id);
      _snack('Restored from v${commit.versionNo}.');
    } catch (e) {
      _snack('Could not restore: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(fileItemProvider(_fileId)).value;
    final commits = ref.watch(commitsProvider(_fileId));
    final name = item?.file.displayName;
    final currentCommitId = item?.file.currentCommitId;

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name ?? 'Version history',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Version history',
                          style: TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _RestoreBanner(),
              const SizedBox(height: 12),
              Expanded(
                child: commits.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Could not load: $e')),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Center(child: Text('No versions yet.'));
                    }
                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final commit = list[index];
                        return _CommitCard(
                          commit: commit,
                          isCurrent: commit.id == currentCommitId,
                          onOpen: name == null
                              ? null
                              : () => _open(name, commit),
                          onRestore: () => _restore(commit),
                        );
                      },
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

/// "Restoring creates a new version. Nothing is deleted." (mockup 7).
class _RestoreBanner extends StatelessWidget {
  const _RestoreBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inProgressBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.inProgressText),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Restoring creates a new version. Nothing is deleted.',
              style: TextStyle(color: AppColors.inProgressText, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommitCard extends StatelessWidget {
  const _CommitCard({
    required this.commit,
    required this.isCurrent,
    required this.onOpen,
    required this.onRestore,
  });

  final Commit commit;
  final bool isCurrent;
  final VoidCallback? onOpen;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'v${commit.versionNo} - ${commit.message}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  const CurrentChip(),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_dateFormat.format(commit.createdAt)}'
              ' · ${formatBytes(commit.sizeBytes)}',
              style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CardButton(label: 'Open', onPressed: onOpen),
                if (!isCurrent) ...[
                  const SizedBox(width: 8),
                  CardButton(label: 'Restore', onPressed: onRestore),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
