import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtrack/core/flashcards_parser.dart';

void main() {
  test('parses the documented JSON contract', () {
    final deck = parseFlashcardImport(
      jsonEncode({
        'schema': 'subtrack.cards.v1',
        'deck': '  Cell Biology  ',
        'cards': [
          {'front': 'Powerhouse?', 'back': 'Mitochondrion'},
          {'front': 'Membrane?', 'back': 'Controls entry'},
        ],
      }),
    );
    expect(deck.name, 'Cell Biology');
    expect(deck.cards, hasLength(2));
    expect(deck.cards.first.back, 'Mitochondrion');
    expect(deck.skippedDuplicates, 0);
  });

  test('accepts code fences and surrounding commentary', () {
    const reply =
        'Here are your cards:\n```json\n'
        '{"schema":"subtrack.cards.v1","deck":"Verbs",'
        '"cards":[{"front":"run","back":"ran"}]}\n```\nGood luck!';
    final deck = parseFlashcardImport(reply);
    expect(deck.name, 'Verbs');
    expect(deck.cards.single.front, 'run');
  });

  test('falls back to Q/A blocks', () {
    const reply =
        'Q: What is the powerhouse of the cell?\n'
        'A: The mitochondrion.\n'
        'A: It makes ATP.\n\n'
        'Q: What does the membrane do?\n'
        'A: Controls what enters.';
    final deck = parseFlashcardImport(reply);
    expect(deck.name, 'Imported cards');
    expect(deck.cards, hasLength(2));
    expect(deck.cards.first.back, 'The mitochondrion.\nIt makes ATP.');
  });

  test('skips duplicate fronts and keeps the first card', () {
    final deck = parseFlashcardImport(
      jsonEncode({
        'schema': 'subtrack.cards.v1',
        'deck': 'Dupes',
        'cards': [
          {'front': 'What is DNA?', 'back': 'Genetic material'},
          {'front': '  what is dna? ', 'back': 'Duplicate'},
          {'front': 'What is RNA?', 'back': 'A copy'},
        ],
      }),
    );
    expect(deck.cards, hasLength(2));
    expect(deck.skippedDuplicates, 1);
    expect(deck.cards.first.back, 'Genetic material');
  });

  test('reports wrong schema, unreadable, and no cards', () {
    expect(
      () => parseFlashcardImport(
        '{"schema":"other.v1","cards":[{"front":"a","back":"b"}]}',
      ),
      throwsA(
        isA<FlashcardParseException>().having(
          (e) => e.code,
          'code',
          'wrong_schema',
        ),
      ),
    );
    expect(
      () => parseFlashcardImport(
        '{"schema":"subtrack.cards.v1","error":"cannot read document"}',
      ),
      throwsA(
        isA<FlashcardParseException>().having(
          (e) => e.code,
          'code',
          'unreadable',
        ),
      ),
    );
    expect(
      () => parseFlashcardImport('{"schema":"subtrack.cards.v1","cards":[]}'),
      throwsA(
        isA<FlashcardParseException>().having(
          (e) => e.code,
          'code',
          'no_cards',
        ),
      ),
    );
  });

  test('rejects HTML but allows Dart generics and math', () {
    final deck = parseFlashcardImport(
      jsonEncode({
        'schema': 'subtrack.cards.v1',
        'cards': [
          {'front': 'List<E>', 'back': 'Future<void> and a < b'},
          {'front': 'safe', 'back': 'x < y'},
        ],
      }),
    );
    expect(deck.cards, hasLength(2));

    expect(
      () => parseFlashcardImport(
        jsonEncode({
          'schema': 'subtrack.cards.v1',
          'cards': [
            {'front': 'unsafe', 'back': '<script>alert(1)</script>'},
          ],
        }),
      ),
      throwsA(
        isA<FlashcardParseException>().having(
          (e) => e.code,
          'code',
          'html_not_allowed',
        ),
      ),
    );
  });

  test('enforces card limits', () {
    final longBack = List.filled(501, 'x').join();
    expect(
      () => parseFlashcardImport(
        jsonEncode({
          'schema': 'subtrack.cards.v1',
          'cards': [
            {'front': 'ok', 'back': longBack},
          ],
        }),
      ),
      throwsA(
        isA<FlashcardParseException>()
            .having((e) => e.code, 'code', 'card_too_long')
            .having((e) => e.message, 'message', contains('Card 1')),
      ),
    );

    final tooMany = List.generate(
      301,
      (index) => {'front': 'q$index', 'back': 'a$index'},
    );
    expect(
      () => parseFlashcardImport(
        jsonEncode({'schema': 'subtrack.cards.v1', 'cards': tooMany}),
      ),
      throwsA(
        isA<FlashcardParseException>().having(
          (e) => e.code,
          'code',
          'too_many_cards',
        ),
      ),
    );
  });

  test('rejects input over 200 KB', () {
    final huge = List.filled(201 * 1024, 'x').join();
    expect(
      () => parseFlashcardImport(huge),
      throwsA(
        isA<FlashcardParseException>().having(
          (e) => e.code,
          'code',
          'too_large',
        ),
      ),
    );
  });

  test('missing fields have a friendly card number', () {
    expect(
      () => parseFlashcardImport(
        jsonEncode({
          'schema': 'subtrack.cards.v1',
          'cards': [
            {'front': 'ok', 'back': 'fine'},
            {'front': 'no back'},
          ],
        }),
      ),
      throwsA(
        isA<FlashcardParseException>()
            .having((e) => e.code, 'code', 'missing_field')
            .having((e) => e.message, 'message', contains('Card 2')),
      ),
    );
  });
}
