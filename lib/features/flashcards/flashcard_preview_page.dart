import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/core/flashcards_parser.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/flashcard_repo.dart';
import 'package:subtrack/features/cloud/backup_status_provider.dart';
import 'package:subtrack/features/flashcards/flashcard_dialogs.dart';
import 'package:subtrack/features/flashcards/flashcard_providers.dart';
import 'package:subtrack/shared/ui_components.dart';

/// The validated import plus the subject choices, passed through `extra`
/// from the import screen so the preview route stays a normal page.
class FlashcardPreviewArgs {
  const FlashcardPreviewArgs({
    required this.subjectId,
    required this.subjects,
    required this.deck,
  });

  final int subjectId;
  final List<Subject> subjects;
  final ParsedDeck deck;
}

class FlashcardPreviewPage extends ConsumerStatefulWidget {
  const FlashcardPreviewPage({required this.args, super.key});

  final FlashcardPreviewArgs? args;

  @override
  ConsumerState<FlashcardPreviewPage> createState() =>
      _FlashcardPreviewPageState();
}

class _FlashcardPreviewPageState extends ConsumerState<FlashcardPreviewPage> {
  late final TextEditingController _name;
  late int _subjectId;
  late List<ParsedCard> _cards;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    _name = TextEditingController(text: args?.deck.name ?? '');
    _subjectId = args?.subjectId ?? -1;
    _cards = List.of(args?.deck.cards ?? const []);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editCard(int index) async {
    final card = _cards[index];
    final result = await showCardEditorDialog(
      context,
      initial: CardDraft(front: card.front, back: card.back),
    );
    if (result == null || !mounted) return;
    setState(() {
      _cards[index] = ParsedCard(front: result.front, back: result.back);
    });
  }

  Future<void> _addCard() async {
    final result = await showCardEditorDialog(context);
    if (result == null || !mounted) return;
    setState(() {
      _cards.add(ParsedCard(front: result.front, back: result.back));
    });
  }

  Future<void> _save() async {
    final args = widget.args;
    if (args == null) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Give the deck a name.');
      return;
    }
    if (FlashcardRepo.codePointLength(name) > FlashcardRepo.maxNameLength) {
      _snack('Use ${FlashcardRepo.maxNameLength} characters or fewer.');
      return;
    }
    if (_cards.isEmpty) {
      _snack('Add at least one card.');
      return;
    }
    if (!args.subjects.any((subject) => subject.id == _subjectId)) {
      _snack('Choose a subject for this deck.');
      return;
    }
    setState(() => _saving = true);
    try {
      final deckId = await ref
          .read(flashcardRepoProvider)
          .createDeck(
            subjectId: _subjectId,
            name: name,
            source: 'ai_import',
            cards: [
              for (final card in _cards)
                CardDraft(front: card.front, back: card.back),
            ],
          );
      await ref.read(localBackupPendingProvider.notifier).markPending();
      if (mounted) context.go('/decks/$deckId');
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Could not save deck: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    if (args == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: () => context.go('/flashcards'),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              const Expanded(
                child: AppErrorState(
                  message:
                      'This preview expired. Paste the AI reply again to '
                      'generate a new preview.',
                ),
              ),
            ],
          ),
        ),
      );
    }
    final skipped = args.deck.skippedDuplicates;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: _saving ? null : () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Expanded(
                    child: Text(
                      'Review import',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${_cards.length} ${_cards.length == 1 ? 'card' : 'cards'}',
                    style: TextStyle(
                      color: context.palette.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.screenPadding,
                  8,
                  AppTheme.screenPadding,
                  28,
                ),
                children: [
                  if (skipped > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.palette.deadlineBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: context.palette.deadlineText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Skipped $skipped duplicate '
                              '${skipped == 1 ? 'card' : 'cards'} while '
                              'importing.',
                              style: TextStyle(
                                color: context.palette.deadlineText,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Text(
                    'Deck details',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Deck name',
                          ),
                          maxLength: FlashcardRepo.maxNameLength,
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          initialValue:
                              args.subjects.any(
                                (subject) => subject.id == _subjectId,
                              )
                              ? _subjectId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                          ),
                          items: [
                            for (final subject in args.subjects)
                              DropdownMenuItem(
                                value: subject.id,
                                child: Text(
                                  subject.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _subjectId = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Cards',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addCard,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add card'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_cards.isEmpty)
                    const EmptyState(
                      icon: Icons.style_outlined,
                      title: 'No cards left',
                      message:
                          'Add a card, or go back and paste the reply again.',
                    )
                  else
                    for (var index = 0; index < _cards.length; index++) ...[
                      _PreviewCard(
                        index: index,
                        card: _cards[index],
                        onEdit: () => _editCard(index),
                        onDelete: () {
                          setState(() => _cards.removeAt(index));
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: 'Save deck',
                    icon: Icons.save_outlined,
                    loading: _saving,
                    onPressed: _save,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Saved on this phone. Use the local backup export to keep '
                    'a copy; flashcards are not sent to the cloud.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.palette.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.index,
    required this.card,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final ParsedCard card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onEdit,
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.palette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: context.palette.accentText,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.front,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  card.back,
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove card',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
        ],
      ),
    );
  }
}
