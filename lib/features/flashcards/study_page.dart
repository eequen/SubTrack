import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/features/flashcards/flashcard_providers.dart';
import 'package:subtrack/shared/ui_components.dart';

/// Offline study mode: tap to flip, previous/next, and shuffle.
class StudyPage extends ConsumerWidget {
  const StudyPage({required this.deckId, super.key});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(deckId) ?? -1;
    final deck = ref.watch(deckProvider(id));
    final cards = ref.watch(cardsProvider(id));
    return Scaffold(
      body: SafeArea(
        child: deck.when(
          loading: () => const AppLoadingState(message: 'Loading study set...'),
          error: (error, _) =>
              AppErrorState(message: 'Could not load deck: $error'),
          data: (value) {
            if (value == null) {
              return const AppErrorState(message: 'Deck not found.');
            }
            return cards.when(
              loading: () =>
                  const AppLoadingState(message: 'Loading study set...'),
              error: (error, _) =>
                  AppErrorState(message: 'Could not load cards: $error'),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.style_outlined,
                    title: 'Nothing to study yet',
                    message: 'Add a card to this deck first.',
                  );
                }
                return _StudySession(
                  deckId: value.id,
                  deckName: value.name,
                  cards: items,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StudySession extends StatefulWidget {
  const _StudySession({
    required this.deckId,
    required this.deckName,
    required this.cards,
  });

  final int deckId;
  final String deckName;
  final List<DbCard> cards;

  @override
  State<_StudySession> createState() => _StudySessionState();
}

class _StudySessionState extends State<_StudySession> {
  late final List<DbCard> _cards = List.of(widget.cards);
  int _index = 0;
  bool _flipped = false;

  DbCard get _card => _cards[_index];

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/decks/${widget.deckId}');
    }
  }

  void _next() {
    if (_index >= _cards.length - 1) {
      _close();
      return;
    }
    setState(() {
      _index++;
      _flipped = false;
    });
  }

  void _previous() {
    if (_index == 0) return;
    setState(() {
      _index--;
      _flipped = false;
    });
  }

  void _shuffle() {
    setState(() {
      _cards.shuffle();
      _index = 0;
      _flipped = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isLast = _index == _cards.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Close study',
                onPressed: _close,
                icon: const Icon(Icons.close),
              ),
              Expanded(
                child: Text(
                  widget.deckName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Shuffle cards',
                onPressed: _shuffle,
                icon: const Icon(Icons.shuffle),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${_index + 1} / ${_cards.length}',
                style: TextStyle(
                  color: palette.mutedText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (_index + 1) / _cards.length,
                    minHeight: 7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _flipped = !_flipped),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.98, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: Container(
                  key: ValueKey(_flipped),
                  decoration: BoxDecoration(
                    color: palette.card,
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    border: Border.all(
                      color: _flipped
                          ? palette.accent.withValues(alpha: 0.55)
                          : palette.cardBorder,
                      width: _flipped ? 2 : 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 20,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _flipped ? 'BACK' : 'FRONT',
                        style: TextStyle(
                          color: _flipped
                              ? palette.accentText
                              : palette.mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _flipped ? _card.back : _card.front,
                            style: TextStyle(
                              color: palette.text,
                              fontSize: _flipped ? 18 : 24,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 16,
                            color: palette.mutedText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tap to flip',
                            style: TextStyle(
                              color: palette.mutedText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _index == 0 ? null : _previous,
                  child: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(isLast ? 'Done' : 'Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
