import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/core/format.dart';
import 'package:subtrack/core/hashing.dart';
import 'package:subtrack/core/mime.dart';
import 'package:subtrack/features/files/file_pick.dart';
import 'package:subtrack/features/files/file_providers.dart';
import 'package:subtrack/shared/card_button.dart';

/// Screen 8 from AGENTS.md section 14: pick the updated file, see the new
/// content hash, write a message, commit as the next version.
class CommitPage extends ConsumerStatefulWidget {
  const CommitPage({required this.fileId, super.key});

  final String fileId;

  @override
  ConsumerState<CommitPage> createState() => _CommitPageState();
}

class _CommitPageState extends ConsumerState<CommitPage> {
  late final int _fileId = int.tryParse(widget.fileId) ?? -1;

  final _message = TextEditingController();
  PickedUpload? _picked;
  String? _hash;
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

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

  Future<void> _pick() async {
    try {
      final picked = await ref.read(filePickerProvider)(context);
      if (picked == null || !mounted) return;
      setState(() {
        _picked = picked;
        _hash = sha256Hex(picked.bytes);
      });
    } catch (e) {
      _snack('Could not pick a file: $e');
    }
  }

  Future<void> _commit() async {
    final picked = _picked;
    final hash = _hash;
    final message = _message.text.trim();
    if (picked == null || hash == null || message.isEmpty) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(blobStoreProvider).saveBytes(picked.bytes);
      final commits = ref.read(commitRepoProvider);
      // Re-read the version in case something changed while this screen
      // was open (single device, but cheap to be correct).
      final versionNo = await commits.nextVersionNo(_fileId);
      await commits.create(
        fileId: _fileId,
        versionNo: versionNo,
        message: message,
        blobHash: hash,
        sizeBytes: picked.bytes.length,
        mimeType: mimeForName(picked.name),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Committed as v$versionNo.')),
      );
      _back();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Could not commit: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(fileItemProvider(_fileId)).value;
    final name = item?.file.displayName;
    final current = item?.currentCommit;
    final nextVersionNo = (current?.versionNo ?? 0) + 1;
    final picked = _picked;
    final identical = _hash != null && _hash == current?.blobHash;
    final canCommit =
        picked != null && _message.text.trim().isNotEmpty && !_busy;

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
                          name ?? 'Commit new version',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Commit new version',
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
              Expanded(
                child: ListView(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Next version ',
                            style: TextStyle(color: AppColors.mutedText),
                          ),
                          TextSpan(
                            text: 'v$nextVersionNo',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PickCard(picked: picked, enabled: !_busy, onPick: _pick),
                    if (picked != null && _hash != null) ...[
                      const SizedBox(height: 12),
                      _HashBanner(
                        identical: identical,
                        hash: _hash!,
                        currentVersionNo: current?.versionNo,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: _message,
                      enabled: !_busy,
                      maxLength: 72,
                      maxLines: 3,
                      minLines: 1,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Commit message',
                        hintText: 'What changed?',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: canCommit ? _commit : null,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Commit as v$nextVersionNo'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : _back,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The picked file, with a button to choose or change it (mockup 8).
class _PickCard extends StatelessWidget {
  const _PickCard({
    required this.picked,
    required this.enabled,
    required this.onPick,
  });

  final PickedUpload? picked;
  final bool enabled;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final picked = this.picked;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'File to commit',
              style: TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: picked == null
                      ? const Text('No file picked yet.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              picked.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              formatBytes(picked.bytes.length),
                              style: const TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 8),
                CardButton(
                  label: picked == null ? 'Choose file' : 'Change file',
                  onPressed: enabled ? onPick : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Hash banner (mockup 8): teal when the content is new, amber when it is
/// identical to the current version.
class _HashBanner extends StatelessWidget {
  const _HashBanner({
    required this.identical,
    required this.hash,
    required this.currentVersionNo,
  });

  final bool identical;
  final String hash;
  final int? currentVersionNo;

  @override
  Widget build(BuildContext context) {
    final (text, bg, icon, label) = identical
        ? (
            AppColors.deadlineText,
            AppColors.deadlineBg,
            Icons.warning_amber_outlined,
            'This file is identical to the current version'
                '${currentVersionNo == null ? '' : ' (v$currentVersionNo)'}.',
          )
        : (
            AppColors.finalText,
            AppColors.finalBg,
            Icons.check_circle_outline,
            'New content detected — SHA-256 ${hash.substring(0, 12)}…',
          );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: text),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(color: text, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
