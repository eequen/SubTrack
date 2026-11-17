import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/flashcard_repo.dart';
import 'package:subtrack/features/cloud/backup_status_provider.dart';
import 'package:subtrack/features/flashcards/flashcard_dialogs.dart';
import 'package:subtrack/features/flashcards/flashcard_providers.dart';
import 'package:subtrack/features/subjects/subject_providers.dart';
import 'package:subtrack/shared/ui_components.dart';

class DeckDetailPage extends ConsumerStatefulWidget {
  const DeckDetailPage({required this.deckId, super.key});

  final String deckId;

  @override
  ConsumerState<DeckDetailPage> createState() => _DeckDetailPageState();
}

class _DeckDetailPageState extends ConsumerState<DeckDetailPage> {
  late final int _deckId = int.tryParse(widget.deckId) ?? -1;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/flashcards');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addCard() async {
    final result = await showCardEditorDialog(context);
    if (result == null || !mounted) return;
    try {
      await ref.read(flashcardRepoProvider).addCard(_deckId, result);
      await ref.read(localBackupPendingProvider.notifier).markPending();
    } catch (error) {
      _snack('Could not add card: $error');
    }
  }

  Future<void> _editCard(DbCard card) async {
    final result = await showCardEditorDialog(
      context,
      initial: CardDraft(front: card.front, back: card.back),
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(flashcardRepoProvider).updateCard(card.id, result);
      await ref.read(localBackupPendingProvider.notifier).markPending();
    } catch (error) {
      _snack('Could not save card: $error');
    }
  }

  Future<void> _deleteCard(DbCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete card?'),
        content: Text('"${card.front}" will be removed from this deck.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(flashcardRepoProvider).deleteCard(card.id);
    await ref.read(localBackupPendingProvider.notifier).markPending();
  }

  Future<void> _rename(Deck deck) async {
    final name = await showDeckNameDialog(
      context,
      title: 'Rename deck',
      initialName: deck.name,
      action: 'Save name',
    );
    if (name == null || !mounted) return;
    await ref.read(flashcardRepoProvider).renameDeck(deck.id, name);
    await ref.read(localBackupPendingProvider.notifier).markPending();
  }

  Future<void> _deleteDeck(Deck deck) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete deck?'),
        content: Text(
          '"${deck.name}" and all of its cards will be deleted. This cannot '
          'be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(flashcardRepoProvider).deleteDeck(deck.id);
    await ref.read(localBackupPendingProvider.notifier).markPending();
    if (mounted) context.go('/flashcards');
  }

  @override
  Widget build(BuildContext context) {
    final deckAsync = ref.watch(deckProvider(_deckId));
    final cardsAsync = ref.watch(cardsProvider(_deckId));
    return Scaffold(
      body: SafeArea(
        child: deckAsync.when(
          loading: () => const AppLoadingState(message: 'Loading deck...'),
          error: (error, _) =>
              AppErrorState(message: 'Could not load deck: $error'),
          data: (deck) {
            if (deck == null) {
              return const AppErrorState(message: 'Deck not found.');
            }
            final subject = ref.watch(subjectProvider(deck.subjectId)).value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back',
                        onPressed: _back,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deck.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            if (subject != null)
                              Text(
                                subject.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.palette.mutedText,
                                  fontSize: 12,
                                ),
                              ),
                            Text(
                              '${cardsAsync.value?.length ?? 0} '
                              '${cardsAsync.value?.length == 1 ? 'card' : 'cards'}',
                              style: TextStyle(
                                color: context.palette.mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Deck actions',
                        onSelected: (value) {
                          if (value == 'rename') _rename(deck);
                          if (value == 'delete') _deleteDeck(deck);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text('Rename deck'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete deck'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.screenPadding,
                    10,
                    AppTheme.screenPadding,
                    12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: cardsAsync.value?.isEmpty ?? true
                              ? null
                              : () => context.push('/decks/${deck.id}/study'),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Study'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _addCard,
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Add card'),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: cardsAsync.when(
                    loading: () =>
                        const AppLoadingState(message: 'Loading cards...'),
                    error: (error, _) =>
                        AppErrorState(message: 'Could not load cards: $error'),
                    data: (cards) {
                      if (cards.isEmpty) {
                        return const EmptyState(
                          icon: Icons.style_outlined,
                          title: 'No cards yet',
                          message:
                              'Add a card by hand, or import a deck with AI.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.screenPadding,
                          4,
                          AppTheme.screenPadding,
                          24,
                        ),
                        itemCount: cards.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _CardTile(
                          index: index,
                          card: cards[index],
                          onTap: () => _editCard(cards[index]),
                          onDelete: () => _deleteCard(cards[index]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.index,
    required this.card,
    required this.onTap,
    required this.onDelete,
  });

  final int index;
  final DbCard card;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.palette.cardBorder.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: context.palette.mutedText,
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
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  card.back,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete card',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
        ],
      ),
    );
  }
}
