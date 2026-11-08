import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/core/hashing.dart';
import 'package:subtrack/core/mime.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/file_repo.dart';
import 'package:subtrack/features/edit/edit_providers.dart';
import 'package:subtrack/features/edit/editor_service.dart';
import 'package:subtrack/features/files/file_pick.dart';
import 'package:subtrack/features/files/file_providers.dart';
import 'package:subtrack/features/history/commit_page.dart';

/// Phase 5B edit flow: copies a version into a private working copy, opens
/// it in an external editor, and turns the result into a new commit.
///
/// The history is never modified here. A session stays unfinished until the
/// student commits or discards it, and the files screen shows an Editing
/// badge while it exists.
class EditPage extends ConsumerStatefulWidget {
  const EditPage({required this.fileId, this.baseCommitId, super.key});

  final String fileId;

  /// The version the student tapped Edit on; ignored when a session already
  /// exists, because one file has at most one working copy in practice.
  final int? baseCommitId;

  @override
  ConsumerState<EditPage> createState() => _EditPageState();
}

class _EditPageState extends ConsumerState<EditPage>
    with WidgetsBindingObserver {
  late final int _fileId = int.tryParse(widget.fileId) ?? -1;

  EditSession? _session;
  Commit? _base;
  String? _displayName;
  int? _activityId;
  bool _loading = true;
  bool _busy = false;
  bool _checking = false;
  bool _awaitingReturn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from Word/WPS: hash the working copy and act on the result.
    if (state == AppLifecycleState.resumed && _awaitingReturn) {
      _awaitingReturn = false;
      _checkForChanges();
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendly(Object error) {
    if (error is EditorException) return error.message;
    if (error is StateError) return error.message;
    return '$error';
  }

  Future<void> _start() async {
    if (_fileId <= 0) {
      setState(() {
        _loading = false;
        _error = 'File not found.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final item = await ref.read(fileRepoProvider).watchById(_fileId).first;
      if (item == null) throw StateError('File not found.');

      final commits = ref.read(commitRepoProvider);
      final repo = ref.read(editSessionRepoProvider);

      // One unfinished edit per file: resume it instead of making another
      // working copy, even when the student tapped Edit on another version.
      var session = await repo.findForFile(_fileId);
      if (session != null && !await File(session.workingPath).exists()) {
        await repo.discard(session.id);
        session = null;
      }

      Commit? base;
      if (session != null) {
        base = await commits.getById(session.baseCommitId);
        if (base == null || base.fileId != _fileId) {
          await repo.discard(session.id);
          session = null;
          base = await _requestedBase(item);
        }
      } else {
        base = await _requestedBase(item);
      }
      if (base == null) throw StateError('Version not found.');

      session ??= await repo.start(
        fileId: _fileId,
        baseCommitId: base.id,
        displayName: item.file.displayName,
      );

      if (!mounted) return;
      setState(() {
        _session = session;
        _base = base;
        _displayName = item.file.displayName;
        _activityId = item.file.activityId;
        _loading = false;
      });
      await _openEditor();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendly(e);
      });
    }
  }

  Future<Commit?> _requestedBase(FileListItem item) async {
    final requested = widget.baseCommitId;
    if (requested == null) return item.currentCommit;
    final commit = await ref.read(commitRepoProvider).getById(requested);
    return commit != null && commit.fileId == _fileId ? commit : null;
  }

  Future<void> _openEditor() async {
    final session = _session;
    if (session == null || _busy) return;
    setState(() {
      _busy = true;
      // Set before the intent: the editor may pause and resume the app
      // quickly if the student dismisses the chooser.
      _awaitingReturn = true;
    });
    try {
      await ref
          .read(editorServiceProvider)
          .openForEdit(
            path: session.workingPath,
            mimeType: mimeForName(
              _displayName ?? p.basename(session.workingPath),
            ),
          );
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _awaitingReturn = false;
      });
      _snack(_friendly(e));
    }
  }

  Future<void> _checkForChanges() async {
    final session = _session;
    final base = _base;
    if (session == null || base == null || _checking) return;
    setState(() => _checking = true);
    try {
      final file = File(session.workingPath);
      if (!await file.exists()) {
        await ref.read(editSessionRepoProvider).discard(session.id);
        if (!mounted) return;
        _snack('The working copy is gone. Start the edit again.');
        _back();
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _checking = false);

      if (sha256Hex(bytes) == base.blobHash) {
        final choice = await _askUnchanged();
        if (!mounted) return;
        if (choice == 'keep') {
          await _openEditor();
        } else if (choice == 'discard') {
          await _confirmDiscard();
        } else if (choice == 'pick') {
          await _pickElsewhere();
        }
        return;
      }
      await _commitPicked(
        PickedUpload(
          bytes: bytes,
          name: _displayName ?? p.basename(session.workingPath),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      _snack('Could not check the file: ${_friendly(e)}');
    }
  }

  Future<String?> _askUnchanged() {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No changes detected'),
        content: const Text(
          'The working copy is unchanged. Some editors, including Word, '
          'save a copy instead of updating the original. Pick the saved '
          'file, keep editing, or discard this working copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('keep'),
            child: const Text('Keep editing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('pick'),
            child: const Text('Pick saved copy'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDiscard() async {
    final session = _session;
    if (session == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this edit?'),
        content: const Text(
          'The working copy is deleted and no version is created. '
          'Your existing versions stay exactly as they are.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(editSessionRepoProvider).discard(session.id);
    if (!mounted) return;
    _snack('Edit discarded.');
    _back();
  }

  Future<void> _pickElsewhere() async {
    try {
      final picked = await ref.read(filePickerProvider)(context);
      if (picked == null || !mounted) return;
      await _commitPicked(picked);
    } catch (e) {
      _snack('Could not pick a file: ${_friendly(e)}');
    }
  }

  Future<void> _commitPicked(PickedUpload picked) async {
    final base = _base;
    final session = _session;
    if (base == null || session == null) return;
    setState(() => _busy = true);
    final returnPath = _activityId == null
        ? '/home'
        : '/activities/$_activityId';
    await context.push(
      '/files/$_fileId/commit',
      extra: CommitArgs(
        picked: picked,
        basedOnCommitId: base.id,
        baseVersionNo: base.versionNo,
        sessionId: session.id,
        prefillMessage: 'Edited from v${base.versionNo}',
        returnPath: returnPath,
      ),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
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
                    onPressed: _busy ? null : _back,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName ?? 'Edit file',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Edit in another app',
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
              Expanded(child: _content()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: context.palette.mutedText,
            ),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _start, child: const Text('Try again')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _back, child: const Text('Cancel')),
          ],
        ),
      );
    }
    final base = _base;
    if (base == null) return const SizedBox.shrink();

    return ListView(
      children: [
        _InfoBanner(
          text: _awaitingReturn
              ? 'Waiting for your editor. Save the file there, then come '
                    'back to SubTrack.'
              : 'Save the file in your editor, then come back. Nothing in '
                    'the history changes until you commit.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editing v${base.versionNo}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _displayName ?? '',
                  style: TextStyle(color: context.palette.mutedText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'SubTrack made a private copy for this edit. Committing '
                  'creates a new version; no existing version is changed.',
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _busy || _checking ? null : _checkForChanges,
          icon: _checking
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.fact_check_outlined),
          label: const Text('Check for changes'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy || _checking ? null : _openEditor,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open editor again'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy || _checking ? null : _pickElsewhere,
          child: const Text('I saved it elsewhere, pick the file'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy || _checking ? null : _confirmDiscard,
          child: Text(
            'Discard edit',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.inProgressBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: context.palette.inProgressText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.palette.inProgressText,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
