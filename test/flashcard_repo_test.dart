import 'package:flutter_test/flutter_test.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/flashcard_repo.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';

void main() {
  late AppDatabase db;
  late FlashcardRepo repo;
  late int semesterId;
  late int subjectId;

  setUp(() async {
    db = AppDatabase.memory();
    repo = FlashcardRepo(db);
    semesterId = await SemesterRepo(db).create(
      term: 'first',
      schoolYear: '2026-2027',
      startDate: DateTime(2026, 8, 18),
      endDate: DateTime(2026, 12, 19),
    );
    subjectId = await SubjectRepo(db)
        .create(semesterId: semesterId, name: 'Biology', color: 0xFF3B4BDB);
  });

  tearDown(() => db.close());

  test('creates a deck with ordered cards and counts them', () async {
    final deckId = await repo.createDeck(
      subjectId: subjectId,
      name: '  Cell Biology  ',
      cards: const [
        CardDraft(front: 'Powerhouse?', back: 'Mitochondrion'),
        CardDraft(front: 'Membrane?', back: 'Controls entry'),
      ],
    );

    final decks = await repo.watchDecksBySubject(subjectId).first;
    expect(decks.single.deck.name, 'Cell Biology');
    expect(decks.single.cardCount, 2);

    final cards = await repo.watchCards(deckId).first;
    expect(cards.map((c) => c.front), ['Powerhouse?', 'Membrane?']);
    expect(cards.map((c) => c.position), [0, 1]);
  });

  test('adds, edits, and deletes a card', () async {
    final deckId = await repo.createDeck(
      subjectId: subjectId,
      name: 'Verbs',
      cards: const [CardDraft(front: 'run', back: 'ran')],
    );
    final first = (await repo.getCards(deckId)).single;

    await repo.updateCard(
      first.id,
      const CardDraft(front: 'run', back: 'to move'),
    );
    final cardId = await repo.addCard(
      deckId,
      const CardDraft(front: 'eat', back: 'ate'),
    );
    var cards = await repo.getCards(deckId);
    expect(cards.first.back, 'to move');
    expect(cards.last.position, 1);

    await repo.deleteCard(cardId);
    cards = await repo.getCards(deckId);
    expect(cards, hasLength(1));
  });

  test('deleting a subject cascades to decks and cards', () async {
    await repo.createDeck(
      subjectId: subjectId,
      name: 'Cells',
      cards: const [CardDraft(front: 'a', back: 'b')],
    );
    await SubjectRepo(db).delete(subjectId);
    expect(await db.select(db.decks).get(), isEmpty);
    expect(await db.select(db.cards).get(), isEmpty);
  });

  test('lists decks in a semester with their subject name', () async {
    await repo.createDeck(subjectId: subjectId, name: 'Cells');
    final items = await repo.watchDecksInSemester(semesterId).first;
    expect(items.single.subjectName, 'Biology');
    expect(items.single.deck.name, 'Cells');
  });

  test('rejects invalid deck names and empty cards', () async {
    await expectLater(
      repo.createDeck(subjectId: subjectId, name: '   '),
      throwsArgumentError,
    );
    await expectLater(
      repo.createDeck(
        subjectId: subjectId,
        name: 'Deck',
        cards: const [CardDraft(front: '', back: 'x')],
      ),
      throwsArgumentError,
    );
    await expectLater(
      repo.createDeck(subjectId: subjectId, name: List.filled(81, 'x').join()),
      throwsArgumentError,
    );
  });
}
