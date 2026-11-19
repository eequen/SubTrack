import 'package:flutter/material.dart';
import 'package:subtrack/app/theme.dart';

/// What the student entered in the New/Edit lesson dialog.
class LessonFormResult {
  const LessonFormResult({required this.title, required this.notes});

  final String title;
  final String notes;
}

/// Lessons are subject-level folders with their own files and version
/// history. They never have a deadline or a status.
Future<LessonFormResult?> showLessonDialog(
  BuildContext context, {
  String initialTitle = '',
  String initialNotes = '',
}) {
  return showDialog<LessonFormResult>(
    context: context,
    builder: (context) =>
        _LessonDialog(initialTitle: initialTitle, initialNotes: initialNotes),
  );
}

class _LessonDialog extends StatefulWidget {
  const _LessonDialog({required this.initialTitle, required this.initialNotes});

  final String initialTitle;
  final String initialNotes;

  @override
  State<_LessonDialog> createState() => _LessonDialogState();
}

class _LessonDialogState extends State<_LessonDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  String? _error;

  bool get _isEdit => widget.initialTitle.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _notesController = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Lesson title is required.');
      return;
    }
    Navigator.of(
      context,
    ).pop(LessonFormResult(title: title, notes: _notesController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit lesson' : 'New lesson'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Lesson title'),
              maxLength: 80,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                helperText: 'Shared with every file in this lesson folder.',
              ),
              maxLength: 500,
              maxLines: 3,
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: context.palette.overdue)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(_isEdit ? 'Save' : 'Create lesson'),
        ),
      ],
    );
  }
}
