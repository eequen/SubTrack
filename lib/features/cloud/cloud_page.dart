import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/repositories/backup_repo.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/backup/backup_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';

/// Screen 10 from AGENTS.md section 14: Cloud backup.
///
/// Phase 4 delivers the local .zip export and import; the cloud buttons,
/// storage bar, and settings arrive in Phase 5.
class CloudPage extends ConsumerStatefulWidget {
  const CloudPage({super.key});

  @override
  ConsumerState<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends ConsumerState<CloudPage> {
  bool _exporting = false;
  bool _importing = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Export (AGENTS.md section 9, task 4) and hand the .zip to the share
  /// sheet so the student can keep it anywhere.
  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await ref.read(backupRepoProvider).export();
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'SubTrack backup'),
      );
      _snack('Backup exported.');
    } catch (e) {
      _snack('Could not export backup: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Import (AGENTS.md section 9, task 5): validate, ask for confirmation,
  /// then replace. An invalid zip never touches any data.
  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final picked = await ref.read(backupPickerProvider)();
      if (picked == null) return;
      final repo = ref.read(backupRepoProvider);
      final contents = await repo.validate(picked.bytes);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import backup?'),
          content: Text(
            'This replaces everything in the app with the backup.\n\n'
            'Semesters: ${contents.semesters} · '
            'Subjects: ${contents.subjects} · '
            'Activities: ${contents.activities} · '
            'Versions: ${contents.commits}\n\n'
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await repo.import(picked.bytes);
      // The backup brings its own semesters; the student chooses again.
      await ref.read(selectedSemesterProvider.notifier).select(null);
      _snack('Backup imported. Choose a semester to see it.');
    } on InvalidBackupException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Could not import backup: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authControllerProvider)?.email ?? '';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cloud backup',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Signed in as $email',
                style: const TextStyle(color: AppColors.mutedText),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Local backup (.zip)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Copies every subject, activity, file, and version '
                      'into one .zip you can keep anywhere.',
                      style: TextStyle(color: AppColors.mutedText),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _exporting ? null : _export,
                      child: Text(
                        _exporting
                            ? 'Exporting...'
                            : 'Export local backup (.zip)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _importing ? null : _import,
                      child: Text(
                        _importing
                            ? 'Importing...'
                            : 'Import local backup (.zip)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Backup is manual. Nothing leaves the phone unless '
                      'you share the .zip.',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              OutlinedButton(
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
