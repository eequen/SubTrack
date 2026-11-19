import 'package:flutter/material.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/flashcard_repo.dart';
import 'package:subtrack/shared/ui_components.dart';

Future<String?> showDeckNameDialog(
  BuildContext context, {
  String title = 'New deck',
  String initialName = '',
  String action = 'Create deck',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _DeckNameDialog(title: title, initialName: initialName, action: action),
  );
}

class _DeckNameDialog extends StatefulWidget {
  const _DeckNameDialog({
    required this.title,
    required this.initialName,
    required this.action,
  });

  final String title;
  final String initialName;
  final String action;

  @override
  State<_DeckNameDialog> createState() => _DeckNameDialogState();
}

class _DeckNameDialogState extends State<_DeckNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Deck name is required.');
      return;
    }
    if (FlashcardRepo.codePointLength(name) > FlashcardRepo.maxNameLength) {
      setState(
        () =>
            _error = 'Use ${FlashcardRepo.maxNameLength} characters or fewer.',
      );
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: 'Deck name', errorText: _error),
        maxLength: FlashcardRepo.maxNameLength,
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: Text(widget.action)),
      ],
    );
  }
}

/// A compact subject chooser used before creating or importing a deck.
Future<int?> showSubjectPicker(
  BuildContext context, {
  required List<Subject> subjects,
  String title = 'Choose subject',
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SheetScaffold(
      title: title,
      trailing: IconButton(
        tooltip: 'Close',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: subjects.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final subject = subjects[index];
            return Material(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                  side: BorderSide(color: context.palette.cardBorder),
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color(subject.color),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    subject.name.trim().isEmpty
                        ? '?'
                        : subject.name.trim()[0].toUpperCase(),
                    style: TextStyle(
                      color: context.palette.onAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  subject.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pop(subject.id),
              ),
            );
          },
        ),
      ),
    ),
  );
}

Future<CardDraft?> showCardEditorDialog(
  BuildContext context, {
  CardDraft? initial,
}) {
  return showDialog<CardDraft>(
    context: context,
    builder: (context) => _CardEditorDialog(initial: initial),
  );
}

class _CardEditorDialog extends StatefulWidget {
  const _CardEditorDialog({this.initial});

  final CardDraft? initial;

  @override
  State<_CardEditorDialog> createState() => _CardEditorDialogState();
}

class _CardEditorDialogState extends State<_CardEditorDialog> {
  late final TextEditingController _front = TextEditingController(
    text: widget.initial?.front ?? '',
  );
  late final TextEditingController _back = TextEditingController(
    text: widget.initial?.back ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    super.dispose();
  }

  void _save() {
    final front = _front.text.trim();
    final back = _back.text.trim();
    if (front.isEmpty || back.isEmpty) {
      setState(() => _error = 'Both the front and the back are required.');
      return;
    }
    if (FlashcardRepo.codePointLength(front) > FlashcardRepo.maxFrontLength ||
        FlashcardRepo.codePointLength(back) > FlashcardRepo.maxBackLength) {
      setState(
        () => _error =
            'Keep the front to ${FlashcardRepo.maxFrontLength} characters '
            'and the back to ${FlashcardRepo.maxBackLength}.',
      );
      return;
    }
    Navigator.of(context).pop(CardDraft(front: front, back: back));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add card' : 'Edit card'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _front,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Front'),
              maxLength: FlashcardRepo.maxFrontLength,
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _back,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Back'),
              maxLength: FlashcardRepo.maxBackLength,
              maxLines: 6,
              minLines: 2,
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
        ElevatedButton(onPressed: _save, child: const Text('Save card')),
      ],
    );
  }
}
