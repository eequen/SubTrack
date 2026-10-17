import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/features/auth/auth_providers.dart';

final semesterRepoProvider = Provider<SemesterRepo>((ref) {
  return SemesterRepo(ref.watch(databaseProvider));
});

final semestersProvider = StreamProvider<List<SemesterListItem>>((ref) {
  return ref.watch(semesterRepoProvider).watchAllWithCounts();
});

/// The last chosen semester, persisted per user.
class SelectedSemester extends Notifier<int?> {
  String get _key {
    final email = ref.watch(authControllerProvider)?.email ?? 'signed-out';
    return 'selected_semester:$email';
  }

  SharedPreferences get _prefs => ref.watch(sharedPreferencesProvider);

  @override
  int? build() => _prefs.getInt(_key);

  Future<void> select(int? id) async {
    if (id == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setInt(_key, id);
    }
    state = id;
  }
}

final selectedSemesterProvider = NotifierProvider<SelectedSemester, int?>(
  SelectedSemester.new,
);
