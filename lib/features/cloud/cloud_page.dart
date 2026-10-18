import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/repositories/backup_repo.dart';
import 'package:subtrack/data/repositories/cloud_repo.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/backup/backup_providers.dart';
import 'package:subtrack/features/cloud/cloud_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';

/// Screen 10 from AGENTS.md section 14: Cloud backup.
///
/// Phase 5 delivers the manual Back up now and Restore from cloud buttons,
/// the storage bar, and the backup settings. Backup stays manual: nothing
/// is uploaded until the student presses the button.
class CloudPage extends ConsumerStatefulWidget {
  const CloudPage({super.key});

  @override
  ConsumerState<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends ConsumerState<CloudPage> {
  bool _exporting = false;
  bool _importing = false;
  bool _backingUp = false;
  bool _restoring = false;
  bool _cancelRequested = false;
  String? _progressText;

  /// Screen 10 settings; defaults per AGENTS.md (Wi-Fi only on, older
  /// versions off).
  bool _wifiOnly = true;
  bool _includeOlder = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _wifiOnly = prefs.getBool('subtrack_backup_wifi_only') ?? true;
    _includeOlder = prefs.getBool('subtrack_include_older_versions') ?? false;
  }

  bool get _busy => _backingUp || _restoring;

  String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  void _setWifiOnly(bool value) {
    setState(() => _wifiOnly = value);
    ref
        .read(sharedPreferencesProvider)
        .setBool('subtrack_backup_wifi_only', value);
  }

  void _setIncludeOlder(bool value) {
    setState(() => _includeOlder = value);
    ref
        .read(sharedPreferencesProvider)
        .setBool('subtrack_include_older_versions', value);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Back up now (AGENTS.md section 9, Phase 5 task 5): manual upload with
  /// progress and cancel. Honours the Wi-Fi-only setting (constraint 7's
  /// free plan; screen 10).
  Future<void> _backupNow() async {
    if (_wifiOnly) {
      final networks = await ref.read(connectivityCheckProvider)();
      final onWifi =
          networks.contains(ConnectivityResult.wifi) ||
          networks.contains(ConnectivityResult.ethernet);
      if (!onWifi) {
        _snack('Wi-Fi only is on. Connect to Wi-Fi or untick it below.');
        return;
      }
    }
    setState(() {
      _backingUp = true;
      _cancelRequested = false;
      _progressText = null;
    });
    try {
      await ref
          .read(cloudRepoProvider)
          .backupNow(
            onProgress: (progress) {
              if (!mounted) return;
              setState(() {
                _progressText = switch (progress.phase) {
                  CloudBackupPhase.preparing => 'Preparing...',
                  CloudBackupPhase.metadata => 'Uploading details...',
                  CloudBackupPhase.blobs =>
                    progress.total == 0
                        ? null
                        : 'Uploading files ${progress.current} of '
                              '${progress.total}...',
                  CloudBackupPhase.done => null,
                };
              });
            },
            cancelled: () => _cancelRequested,
            includeOlderVersions: _includeOlder,
          );
      await ref
          .read(sharedPreferencesProvider)
          .setString(
            'subtrack_last_cloud_backup',
            DateTime.now().toUtc().toIso8601String(),
          );
      ref.invalidate(cloudUsageProvider);
      _snack('Backed up to the cloud.');
    } on CloudBackupCancelled {
      _snack('Backup cancelled.');
    } on CloudBackupException catch (e) {
      _snack(e.message);
    } on SocketException {
      _snack('No internet connection. Cloud backup needs the internet.');
    } catch (e) {
      _snack('Could not back up: $e');
    } finally {
      if (mounted) {
        setState(() {
          _backingUp = false;
          _progressText = null;
        });
      }
    }
  }

  /// Restore from cloud (AGENTS.md section 9, Phase 5 task 7): show what
  /// would come back, ask for confirmation, then replace everything on
  /// this device.
  Future<void> _restore() async {
    final BackupContents contents;
    try {
      contents = await ref.read(cloudRepoProvider).peekCloud();
    } on SocketException {
      _snack('No internet connection. Restore needs the internet.');
      return;
    } catch (e) {
      _snack('Could not check the cloud: $e');
      return;
    }
    if (contents.semesters == 0 && contents.commits == 0) {
      _snack('Nothing is in the cloud yet. Press Back up now first.');
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from cloud?'),
        content: Text(
          'This replaces everything in the app with the cloud backup.\n\n'
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
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _restoring = true;
      _cancelRequested = false;
      _progressText = null;
    });
    try {
      await ref
          .read(cloudRepoProvider)
          .restoreFromCloud(
            onProgress: (progress) {
              if (!mounted) return;
              setState(() {
                _progressText = switch (progress.phase) {
                  CloudRestorePhase.preparing => 'Checking the cloud...',
                  CloudRestorePhase.downloading =>
                    progress.total == 0
                        ? null
                        : 'Downloading files ${progress.current} of '
                              '${progress.total}...',
                  CloudRestorePhase.replacing => 'Putting everything back...',
                  CloudRestorePhase.done => null,
                };
              });
            },
            cancelled: () => _cancelRequested,
          );
      // The cloud brings its own semesters; the student chooses again.
      await ref.read(selectedSemesterProvider.notifier).select(null);
      _snack('Restored from the cloud. Choose a semester to see it.');
    } on CloudBackupCancelled {
      _snack('Restore cancelled.');
    } on CloudBackupException catch (e) {
      _snack(e.message);
    } on SocketException {
      _snack('No internet connection. Restore needs the internet.');
    } catch (e) {
      _snack('Could not restore: $e');
    } finally {
      if (mounted) {
        setState(() {
          _restoring = false;
          _progressText = null;
        });
      }
    }
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
    final prefs = ref.watch(sharedPreferencesProvider);
    final usage = ref.watch(cloudUsageProvider);
    final lastRaw = prefs.getString('subtrack_last_cloud_backup');
    final lastBackup = lastRaw == null
        ? 'No backup yet.'
        : 'Last backup: ${DateFormat('MMM d, y h:mm a').format(DateTime.parse(lastRaw).toLocal())}';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: SingleChildScrollView(
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
                        'Back up to the cloud',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Uploads the latest version of every file and all your '
                        'details to your private cloud storage.',
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                      const SizedBox(height: 12),
                      usage.when(
                        data: (used) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LinearProgressIndicator(
                              value: (used / cloudQuotaBytes).clamp(0.0, 1.0),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_mb(used)} / 100 MB used · $lastBackup',
                              style: const TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        loading: () => Text(
                          'Checking cloud storage... · $lastBackup',
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 12,
                          ),
                        ),
                        error: (error, stack) => Text(
                          'Could not check cloud storage. · $lastBackup',
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _busy ? null : _backupNow,
                        child: Text(
                          _backingUp ? 'Backing up...' : 'Back up now',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _busy ? null : _restore,
                        child: Text(
                          _restoring ? 'Restoring...' : 'Restore from cloud',
                        ),
                      ),
                      if (_backingUp || _restoring) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Expanded(child: LinearProgressIndicator()),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _cancelRequested = true),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                        if (_progressText != null)
                          Text(
                            _progressText!,
                            style: const TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 12,
                            ),
                          ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _wifiOnly,
                            onChanged: _busy
                                ? null
                                : (value) => _setWifiOnly(value ?? true),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _busy
                                  ? null
                                  : () => _setWifiOnly(!_wifiOnly),
                              child: const Text('Back up on Wi-Fi only'),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _includeOlder,
                            onChanged: _busy
                                ? null
                                : (value) => _setIncludeOlder(value ?? false),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _busy
                                  ? null
                                  : () => _setIncludeOlder(!_includeOlder),
                              child: const Text('Include older versions'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                const SizedBox(height: 24),
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
      ),
    );
  }
}
