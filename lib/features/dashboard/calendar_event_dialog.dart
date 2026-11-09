import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/shared/ui_components.dart';

class CalendarEventDraft {
  const CalendarEventDraft({
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.notes,
  });

  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String notes;
}

Future<CalendarEventDraft?> showCalendarEventDialog(
  BuildContext context, {
  required DateTime initialDate,
  CalendarEvent? event,
}) {
  return showModalBottomSheet<CalendarEventDraft>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _CalendarEventForm(initialDate: initialDate, event: event),
  );
}

class _CalendarEventForm extends StatefulWidget {
  const _CalendarEventForm({required this.initialDate, this.event});

  final DateTime initialDate;
  final CalendarEvent? event;

  @override
  State<_CalendarEventForm> createState() => _CalendarEventFormState();
}

class _CalendarEventFormState extends State<_CalendarEventForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late DateTime _startsAt;
  late DateTime? _endsAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');
    _notesController = TextEditingController(text: event?.notes ?? '');
    _startsAt =
        event?.startsAt ??
        DateTime(
          widget.initialDate.year,
          widget.initialDate.month,
          widget.initialDate.day,
          9,
        );
    _endsAt = event?.endsAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool end}) async {
    final current = end
        ? (_endsAt ?? _startsAt.add(const Duration(hours: 1)))
        : _startsAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (end) {
        _endsAt = picked;
      } else {
        _startsAt = picked;
      }
      _error = null;
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter an event title.');
      return;
    }
    if (_endsAt != null && !_endsAt!.isAfter(_startsAt)) {
      setState(() => _error = 'End time must be after start time.');
      return;
    }
    Navigator.of(context).pop(
      CalendarEventDraft(
        title: title,
        startsAt: _startsAt,
        endsAt: _endsAt,
        notes: _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('EEE, MMM d · h:mm a');
    final hasEnd = _endsAt != null;
    return SheetScaffold(
      title: widget.event == null ? 'New calendar event' : 'Edit event',
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Event title'),
              ),
              const SizedBox(height: 12),
              _DateTimeButton(
                label: 'Starts',
                value: timeFormat.format(_startsAt),
                onPressed: () => _pickDateTime(end: false),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Add an end time'),
                value: hasEnd,
                onChanged: (value) => setState(() {
                  _endsAt = value
                      ? _startsAt.add(const Duration(hours: 1))
                      : null;
                  _error = null;
                }),
              ),
              if (hasEnd)
                _DateTimeButton(
                  label: 'Ends',
                  value: timeFormat.format(_endsAt!),
                  onPressed: () => _pickDateTime(end: true),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: context.palette.overdue)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _save,
                child: Text(widget.event == null ? 'Add event' : 'Save event'),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  const _DateTimeButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onPressed,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.event_outlined, color: context.palette.accentText),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(color: context.palette.mutedText),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar_outlined),
          ],
        ),
      ),
    );
  }
}
