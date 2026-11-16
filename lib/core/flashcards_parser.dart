import 'dart:convert';

/// One validated card from an external-AI reply.
class ParsedCard {
  const ParsedCard({required this.front, required this.back});

  final String front;
  final String back;
}

/// A validated deck that is ready for the preview screen. Nothing has been
/// written to the database yet.
class ParsedDeck {
  const ParsedDeck({
    required this.name,
    required this.cards,
    this.skippedDuplicates = 0,
  });

  final String name;
  final List<ParsedCard> cards;
  final int skippedDuplicates;
}

/// A reply that cannot be imported. [code] is the documented error code.
class FlashcardParseException implements Exception {
  const FlashcardParseException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

const _schema = 'subtrack.cards.v1';
const _maxBytes = 200 * 1024;
const _maxCards = 300;
const _maxDeckLength = 80;
const _maxFrontLength = 180;
const _maxBackLength = 500;
const _fallbackDeckName = 'Imported cards';

const _messages = <String, String>{
  'too_large':
      'That reply is too big to import. Ask the AI to split the document '
      'into smaller parts.',
  'parse_failed':
      "That doesn't look like the prompt's format. Copy the AI's whole reply, "
      'including the braces, and paste it again.',
  'wrong_schema':
      'Those cards were made for a different format version. Copy the prompt '
      'again and ask the AI to regenerate them.',
  'unreadable':
      "The AI couldn't read the document. Try a clearer PDF, a text-based "
      'PDF, or one chapter at a time.',
  'no_cards': 'No cards were found. Ask the AI to try again with 20-40 cards.',
  'missing_field':
      'A card is missing its front or back. Regenerate the reply with the '
      'prompt.',
  'card_too_long':
      'A card is too long. Ask the AI to shorten it, or edit it in the '
      'preview.',
  'html_not_allowed': 'A card contains HTML. Ask the AI for plain text.',
  'duplicate_only':
      'Every card in that reply was a duplicate. Ask the AI for a fresh deck.',
};

/// The exact prompt shipped in `docs/prompts/flashcards_v1.txt`.
const flashcardPromptV1 = '''You are creating study flashcards from the document attached to this message.

Follow these rules exactly:
1. Use ONLY facts stated in the document. Do not add outside knowledge.
2. Make 20 to 40 cards. One fact per card.
3. "front" is a short question or a term (maximum 180 characters).
4. "back" is the answer or definition (maximum 500 characters).
5. Write both sides in the same language as the document.
6. Do not duplicate cards. Do not include headers, page numbers, or your own comments.
7. Plain text only: no HTML, no markdown, no bullet symbols. You may use \\n for a line break inside "back".
8. "deck" is a short name for the document (maximum 80 characters).
9. Reply with ONE JSON object and nothing else. Do not wrap it in code fences.

Output exactly this shape:
{"schema":"subtrack.cards.v1","deck":"Short deck name","cards":[{"front":"Question or term","back":"Answer or definition"}]}

If you cannot read the attached document, reply with exactly:
{"schema":"subtrack.cards.v1","error":"cannot read document"}''';

const _htmlPattern =
    r'<\s*\/?\s*(a|b|br|div|span|img|script|style|p|i|u|table|tr|td|iframe|svg)(\s|\/|>)';
final _html = RegExp(_htmlPattern, caseSensitive: false);

int _length(String value) => value.runes.length;

FlashcardParseException _error(String code, [String? message]) =>
    FlashcardParseException(
      code,
      message ?? _messages[code] ?? _messages['parse_failed']!,
    );

/// Parses and validates a pasted AI reply. Throws [FlashcardParseException]
/// when nothing safe can be saved.
ParsedDeck parseFlashcardImport(String input) {
  if (utf8.encode(input).length > _maxBytes) {
    throw _error('too_large');
  }

  final cleaned = _clean(input);
  if (cleaned.isEmpty) throw _error('parse_failed');

  final jsonText = _jsonCandidate(cleaned);
  if (jsonText != null) {
    Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      decoded = null;
    }
    if (decoded != null) {
      if (decoded is! Map<String, dynamic>) {
        throw _error('parse_failed');
      }
      return _fromJson(decoded);
    }
  }

  // Some AI apps refuse to emit raw JSON. Try the documented Q/A fallback.
  return _fromQa(cleaned);
}

String _clean(String input) {
  var text = input.trim();
  final fence = RegExp(
    r'^```(?:json)?\s*([\s\S]*?)\s*```$',
    caseSensitive: false,
  ).firstMatch(text);
  if (fence != null) text = fence.group(1)!.trim();
  return text;
}

String? _jsonCandidate(String text) {
  if (text.startsWith('{') && text.endsWith('}')) return text;
  final first = text.indexOf('{');
  final last = text.lastIndexOf('}');
  if (first >= 0 && last > first) return text.substring(first, last + 1);
  return null;
}

ParsedDeck _fromJson(Map<String, dynamic> json) {
  final error = json['error'];
  final cardsValue = json['cards'];
  if (error != null && cardsValue != null) {
    throw _error('parse_failed');
  }
  if (error != null) {
    if (error is! String ||
        error.trim().isEmpty ||
        _length(error.trim()) > 300) {
      throw _error('unreadable');
    }
    throw _error('unreadable');
  }
  if (json['schema'] != _schema) throw _error('wrong_schema');
  if (cardsValue is! List) throw _error('no_cards');
  if (cardsValue.isEmpty) throw _error('no_cards');
  if (cardsValue.length > _maxCards) {
    throw FlashcardParseException(
      'too_many_cards',
      "That's ${cardsValue.length} cards; the limit is 300. Ask the AI to "
          'split the document into two decks.',
    );
  }

  final rawName = json['deck'];
  var name = _fallbackDeckName;
  if (rawName is String && rawName.trim().isNotEmpty) {
    final trimmed = rawName.trim();
    if (_length(trimmed) > _maxDeckLength) {
      throw _error('card_too_long', 'The deck name is too long.');
    }
    name = trimmed;
  }

  final cards = <ParsedCard>[];
  final seen = <String>{};
  var skipped = 0;
  for (var index = 0; index < cardsValue.length; index++) {
    final raw = cardsValue[index];
    if (raw is! Map) throw _missing(index, 'front');
    final front = raw['front'];
    final back = raw['back'];
    if (front is! String || front.trim().isEmpty) {
      throw _missing(index, 'front');
    }
    if (back is! String || back.trim().isEmpty) {
      throw _missing(index, 'back');
    }
    final card = _validateCard(index, front, back);
    final key = _normalizeFront(card.front);
    if (!seen.add(key)) {
      skipped++;
      continue;
    }
    cards.add(card);
  }
  if (cards.isEmpty) throw _error('duplicate_only');
  return ParsedDeck(name: name, cards: cards, skippedDuplicates: skipped);
}

ParsedDeck _fromQa(String text) {
  final cards = <ParsedCard>[];
  String? front;
  final back = <String>[];

  void finish() {
    if (front == null) return;
    if (back.isEmpty) {
      throw _error(
        'missing_field',
        'A card is missing its back. Regenerate the reply with the prompt.',
      );
    }
    cards.add(_validateCard(cards.length, front!, back.join('\n')));
    front = null;
    back.clear();
  }

  for (final rawLine in text.split('\n')) {
    final line = rawLine.trimRight();
    final q = RegExp(
      r'^\s*q\s*:\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (q != null) {
      finish();
      front = q.group(1)!.trim();
      continue;
    }
    final a = RegExp(
      r'^\s*a\s*:\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (a != null && front != null) {
      back.add(a.group(1)!.trim());
      continue;
    }
    if (line.trim().isEmpty) {
      if (front != null) finish();
      continue;
    }
    // Unknown prose before the first Q/A pair is ignored; prose inside a card
    // is treated as part of the answer so pasted notes are not lost.
    if (front != null && back.isNotEmpty) back.add(line.trim());
  }
  finish();
  if (cards.isEmpty) throw _error('parse_failed');
  if (cards.length > _maxCards) {
    throw FlashcardParseException(
      'too_many_cards',
      "That's ${cards.length} cards; the limit is 300. Ask the AI to split "
          'the document into two decks.',
    );
  }

  final unique = <ParsedCard>[];
  final seen = <String>{};
  var skipped = 0;
  for (final card in cards) {
    if (!seen.add(_normalizeFront(card.front))) {
      skipped++;
      continue;
    }
    unique.add(card);
  }
  if (unique.isEmpty) throw _error('duplicate_only');
  return ParsedDeck(
    name: _fallbackDeckName,
    cards: unique,
    skippedDuplicates: skipped,
  );
}

ParsedCard _validateCard(int index, String front, String back) {
  final f = front.trim();
  final b = back.trim();
  if (f.isEmpty) throw _missing(index, 'front');
  if (b.isEmpty) throw _missing(index, 'back');
  if (_length(f) > _maxFrontLength || _length(b) > _maxBackLength) {
    throw FlashcardParseException(
      'card_too_long',
      'Card ${index + 1} is too long. Ask the AI to shorten it, or edit it '
          'in the preview.',
    );
  }
  if (_html.hasMatch(f) || _html.hasMatch(b)) {
    throw FlashcardParseException(
      'html_not_allowed',
      'Card ${index + 1} contains HTML. Ask the AI for plain text.',
    );
  }
  return ParsedCard(front: f, back: b);
}

FlashcardParseException _missing(int index, String field) {
  return FlashcardParseException(
    'missing_field',
    'Card ${index + 1} is missing its $field. Regenerate the reply with the '
        'prompt.',
  );
}

String _normalizeFront(String value) {
  var text = value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  const punctuation = '.,;:!?\'"“”‘’()[]{}<>«»…—–-';
  while (text.isNotEmpty && punctuation.contains(text[0])) {
    text = text.substring(1);
  }
  while (text.isNotEmpty && punctuation.contains(text[text.length - 1])) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}
