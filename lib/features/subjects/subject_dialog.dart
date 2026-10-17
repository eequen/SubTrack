import 'package:flutter/material.dart';
import 'package:subtrack/app/theme.dart';

/// What the user typed in the New subject dialog.
class SubjectFormResult {
  const SubjectFormResult({
    required this.name,
    required this.color,
    required this.icon,
  });

  final String name;
  final int color;
  final String icon;
}

/// Screen 4 dialog: name, badge color, optional icon.
/// Returns null when cancelled.
Future<SubjectFormResult?> showNewSubjectDialog(BuildContext context) {
  return showDialog<SubjectFormResult>(
    context: context,
    builder: (context) => const _NewSubjectDialog(),
  );
}

/// Rename dialog; returns null when cancelled or the name is invalid.
Future<String?> showRenameSubjectDialog(
  BuildContext context, {
  required String currentName,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _RenameSubjectDialog(currentName: currentName),
  );
}

class _NewSubjectDialog extends StatefulWidget {
  const _NewSubjectDialog();

  @override
  State<_NewSubjectDialog> createState() => _NewSubjectDialogState();
}

class _NewSubjectDialogState extends State<_NewSubjectDialog> {
  final _nameController = TextEditingController();
  final _iconController = TextEditingController();
  int _colorIndex = 0;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Subject name is required.');
      return;
    }
    Navigator.of(context).pop(
      SubjectFormResult(
        name: name,
        color: AppColors.subjectBadges[_colorIndex].toARGB32(),
        icon: _iconController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New subject'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              maxLength: 60,
            ),
            const SizedBox(height: 8),
            const Text('Badge color'),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < AppColors.subjectBadges.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() => _colorIndex = i),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.subjectBadges[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == _colorIndex
                                ? AppColors.text
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: i == _colorIndex
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _iconController,
              decoration: const InputDecoration(
                labelText: 'Icon (optional)',
                hintText: 'e.g. 📘 or CP',
              ),
              maxLength: 4,
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Create subject')),
      ],
    );
  }
}

class _RenameSubjectDialog extends StatefulWidget {
  const _RenameSubjectDialog({required this.currentName});

  final String currentName;

  @override
  State<_RenameSubjectDialog> createState() => _RenameSubjectDialogState();
}

class _RenameSubjectDialogState extends State<_RenameSubjectDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Subject name is required.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename subject'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
            maxLength: 60,
            onSubmitted: (_) => _save(),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
