import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/flashcard_repo.dart';

final flashcardRepoProvider = Provider<FlashcardRepo>((ref) {
  return FlashcardRepo(ref.watch(databaseProvider));
});

/// Decks of one subject, newest first, with card counts.
final decksBySubjectProvider = StreamProvider.family<List<DeckListItem>, int>((
  ref,
  subjectId,
) {
  return ref.watch(flashcardRepoProvider).watchDecksBySubject(subjectId);
});

/// Every deck in one semester, with the subject name for the global list.
final decksInSemesterProvider =
    StreamProvider.family<List<SemesterDeckItem>, int>((ref, semesterId) {
      return ref.watch(flashcardRepoProvider).watchDecksInSemester(semesterId);
    });

final deckProvider = StreamProvider.family<Deck?, int>((ref, deckId) {
  return ref.watch(flashcardRepoProvider).watchDeck(deckId);
});

final cardsProvider = StreamProvider.family<List<DbCard>, int>((ref, deckId) {
  return ref.watch(flashcardRepoProvider).watchCards(deckId);
});
