import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/repositories/search_repo.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';

final searchRepoProvider = Provider<SearchRepo>((ref) {
  return SearchRepo(ref.watch(databaseProvider));
});

/// What the Search screen is looking for, updated on every keystroke.
class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

final searchQueryProvider = NotifierProvider<SearchQuery, String>(
  SearchQuery.new,
);

/// Results for the chosen semester and the current query. While a new
/// query runs, `AsyncValue.value` keeps the previous results available, so
/// the list does not blink on every keystroke.
final searchResultsProvider = FutureProvider<SearchResults>((ref) {
  final semesterId = ref.watch(selectedSemesterProvider);
  final query = ref.watch(searchQueryProvider);
  if (semesterId == null) return SearchResults.empty;
  return ref.watch(searchRepoProvider).search(semesterId, query);
});
