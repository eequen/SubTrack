import 'package:drift/drift.dart';
import 'package:subtrack/data/db/app_database.dart';

/// A deck with its card count for the flashcards lists.
class DeckListItem {
  const DeckListItem({required this.deck, required this.cardCount});

  final Deck deck;
  final int cardCount;
}

/// A deck in the chosen semester, with its subject's name.
class SemesterDeckItem {
  const SemesterDeckItem({
    required this.deck,
    required this.subjectName,
    required this.cardCount,
  });

  final Deck deck;
  final String subjectName;
  final int cardCount;
}

/// A card before it is inserted or edited.
class CardDraft {
  const CardDraft({required this.front, required this.back});

  final String front;
  final String back;
}

/// Flashcards are local-only (AGENTS.md section 9; docs/flashcards_ai_import.md).
/// They are included in the local `.zip` backup and excluded from Supabase.
class FlashcardRepo {
  FlashcardRepo(this.db);

  final AppDatabase db;

  static const sources = <String>['manual', 'ai_import'];
  static const maxNameLength = 80;
  static const maxFrontLength = 180;
  static const maxBackLength = 500;

  static int codePointLength(String value) => value.runes.length;

  static String _name(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Deck name is required.');
    }
    if (codePointLength(trimmed) > maxNameLength) {
      throw ArgumentError(
        'Deck name must be $maxNameLength characters or less.',
      );
    }
    return trimmed;
  }

  static CardDraft _card(CardDraft draft) {
    final front = draft.front.trim();
    final back = draft.back.trim();
    if (front.isEmpty) {
      throw ArgumentError('The card front is required.');
    }
    if (back.isEmpty) {
      throw ArgumentError('The card back is required.');
    }
    if (codePointLength(front) > maxFrontLength) {
      throw ArgumentError('The card front is too long.');
    }
    if (codePointLength(back) > maxBackLength) {
      throw ArgumentError('The card back is too long.');
    }
    return CardDraft(front: front, back: back);
  }

  void _checkSource(String source) {
    if (!sources.contains(source)) {
      throw ArgumentError('Unknown deck source: $source');
    }
  }

  /// Decks in one subject, newest first, with card counts.
  Stream<List<DeckListItem>> watchDecksBySubject(int subjectId) {
    final count = db.cards.id.count();
    final query =
        db.select(db.decks).join([
            leftOuterJoin(db.cards, db.cards.deckId.equalsExp(db.decks.id)),
          ])
          ..where(db.decks.subjectId.equals(subjectId))
          ..addColumns([count])
          ..groupBy([db.decks.id])
          ..orderBy([
            OrderingTerm.desc(db.decks.createdAt),
            OrderingTerm.desc(db.decks.id),
          ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => DeckListItem(
              deck: row.readTable(db.decks),
              cardCount: row.read(count) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// Every deck in the chosen semester, grouped later by the screen.
  Stream<List<SemesterDeckItem>> watchDecksInSemester(int semesterId) {
    final count = db.cards.id.count();
    final query =
        db.select(db.decks).join([
            innerJoin(
              db.subjects,
              db.subjects.id.equalsExp(db.decks.subjectId),
            ),
            leftOuterJoin(db.cards, db.cards.deckId.equalsExp(db.decks.id)),
          ])
          ..where(db.subjects.semesterId.equals(semesterId))
          ..addColumns([count])
          ..groupBy([db.decks.id])
          ..orderBy([
            OrderingTerm.asc(db.subjects.name),
            OrderingTerm.desc(db.decks.createdAt),
            OrderingTerm.desc(db.decks.id),
          ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => SemesterDeckItem(
              deck: row.readTable(db.decks),
              subjectName: row.readTable(db.subjects).name,
              cardCount: row.read(count) ?? 0,
            ),
          )
          .toList(),
    );
  }

  Stream<Deck?> watchDeck(int deckId) {
    return (db.select(
      db.decks,
    )..where((d) => d.id.equals(deckId))).watchSingleOrNull();
  }

  Future<Deck?> getDeck(int deckId) {
    return (db.select(
      db.decks,
    )..where((d) => d.id.equals(deckId))).getSingleOrNull();
  }

  /// Cards in their saved order.
  Stream<List<DbCard>> watchCards(int deckId) {
    final query = db.select(db.cards)
      ..where((c) => c.deckId.equals(deckId))
      ..orderBy([
        (c) => OrderingTerm.asc(c.position),
        (c) => OrderingTerm.asc(c.id),
      ]);
    return query.watch();
  }

  Future<List<DbCard>> getCards(int deckId) {
    final query = db.select(db.cards)
      ..where((c) => c.deckId.equals(deckId))
      ..orderBy([
        (c) => OrderingTerm.asc(c.position),
        (c) => OrderingTerm.asc(c.id),
      ]);
    return query.get();
  }

  /// Inserts a deck and all of [cards] in one transaction.
  Future<int> createDeck({
    required int subjectId,
    required String name,
    String source = 'manual',
    List<CardDraft> cards = const [],
  }) async {
    final trimmed = _name(name);
    _checkSource(source);
    final checked = [for (final card in cards) _card(card)];
    return db.transaction(() async {
      final deckId = await db
          .into(db.decks)
          .insert(
            DecksCompanion.insert(
              subjectId: subjectId,
              name: trimmed,
              source: Value(source),
            ),
          );
      for (final (index, card) in checked.indexed) {
        await db
            .into(db.cards)
            .insert(
              CardsCompanion.insert(
                deckId: deckId,
                front: card.front,
                back: card.back,
                position: Value(index),
              ),
            );
      }
      return deckId;
    });
  }

  Future<void> renameDeck(int deckId, String name) async {
    final trimmed = _name(name);
    await (db.update(db.decks)..where((d) => d.id.equals(deckId))).write(
      DecksCompanion(name: Value(trimmed)),
    );
  }

  Future<void> deleteDeck(int deckId) async {
    await (db.delete(db.decks)..where((d) => d.id.equals(deckId))).go();
  }

  Future<int> addCard(int deckId, CardDraft draft) async {
    final card = _card(draft);
    final max = db.cards.position.max();
    final row =
        await (db.selectOnly(db.cards)
              ..addColumns([max])
              ..where(db.cards.deckId.equals(deckId)))
            .getSingle();
    final position = (row.read(max) ?? -1) + 1;
    return db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            deckId: deckId,
            front: card.front,
            back: card.back,
            position: Value(position),
          ),
        );
  }

  Future<void> updateCard(int cardId, CardDraft draft) async {
    final card = _card(draft);
    await (db.update(db.cards)..where((c) => c.id.equals(cardId))).write(
      CardsCompanion(front: Value(card.front), back: Value(card.back)),
    );
  }

  Future<void> deleteCard(int cardId) async {
    await (db.delete(db.cards)..where((c) => c.id.equals(cardId))).go();
  }
}
