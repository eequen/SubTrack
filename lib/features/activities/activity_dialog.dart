import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/data/repositories/activity_repo.dart';
import 'package:subtrack/shared/chips.dart';

/// What the user entered in the New/Edit activity dialog.
class ActivityFormResult {
  const ActivityFormResult({
    required this.title,
    required this.notes,
    required this.deadline,
    required this.status,
  });

  final String title;
  final String notes;
  final DateTime? deadline;
  final String status;
}

final _dateFormat = DateFormat('MMM d, yyyy');

/// Create dialog; returns null when cancelled.
Future<ActivityFormResult?> showNewActivityDialog(BuildContext context) {
  return showDialog<ActivityFormResult>(
    context: context,
    builder: (context) => const _ActivityDialog(),
  );
}

/// Edit dialog, prefilled from the current values; null when cancelled.
Future<ActivityFormResult?> showEditActivityDialog(
  BuildContext context, {
  required String title,
  required String notes,
  required DateTime? deadline,
  required String status,
}) {
  return showDialog<ActivityFormResult>(
    context: context,
    builder: (context) => _ActivityDialog(
      initialTitle: title,
      initialNotes: notes,
      initialDeadline: deadline,
      initialStatus: status,
    ),
  );
}

class _ActivityDialog extends StatefulWidget {
  const _ActivityDialog({
    this.initialTitle = '',
    this.initialNotes = '',
    this.initialDeadline,
    this.initialStatus = 'draft',
  });

  final String initialTitle;
  final String initialNotes;
  final DateTime? initialDeadline;
  final String initialStatus;

  @override
  State<_ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<_ActivityDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late DateTime? _deadline;
  late String _status;
  String? _error;

  bool get _isEdit => widget.initialTitle.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _notesController = TextEditingController(text: widget.initialNotes);
    _deadline = widget.initialDeadline;
    _status = widget.initialStatus;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Activity title is required.');
      return;
    }
    Navigator.of(context).pop(
      ActivityFormResult(
        title: title,
        notes: _notesController.text.trim(),
        deadline: _deadline,
        status: _status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit activity' : 'New activity'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: !_isEdit,
              decoration: const InputDecoration(labelText: 'Title'),
              maxLength: 80,
            ),
            const SizedBox(height: 4),
            const Text('Status'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final status in ActivityRepo.statuses)
                  ChoiceChip(
                    label: Text(statusLabel(status)),
                    selected: _status == status,
                    selectedColor: statusColors(status).$2,
                    labelStyle: TextStyle(
                      color: _status == status ? statusColors(status).$1 : null,
                    ),
                    onSelected: (_) => setState(() => _status = status),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(
                    _deadline == null
                        ? 'Set deadline'
                        : _dateFormat.format(_deadline!),
                  ),
                ),
                if (_deadline != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _deadline = null),
                    child: const Text('Clear'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLength: 500,
              maxLines: 3,
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
        ElevatedButton(
          onPressed: _save,
          child: Text(_isEdit ? 'Save' : 'Create activity'),
        ),
      ],
    );
  }
}
