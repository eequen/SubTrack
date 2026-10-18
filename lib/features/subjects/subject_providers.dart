import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';

final subjectRepoProvider = Provider<SubjectRepo>((ref) {
  return SubjectRepo(ref.watch(databaseProvider));
});

final subjectsProvider = StreamProvider.family<List<SubjectListItem>, int>((
  ref,
  semesterId,
) {
  return ref.watch(subjectRepoProvider).watchWithCounts(semesterId);
});
