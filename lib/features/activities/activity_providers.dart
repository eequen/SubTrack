import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/activity_repo.dart';

final activityRepoProvider = Provider<ActivityRepo>((ref) {
  return ActivityRepo(ref.watch(databaseProvider));
});

/// One activity by id, for the files screen header.
final activityProvider = StreamProvider.family<Activity?, int>((ref, id) {
  return ref.watch(activityRepoProvider).watchById(id);
});

final activitiesProvider = StreamProvider.family<List<ActivityListItem>, int>((
  ref,
  subjectId,
) {
  return ref.watch(activityRepoProvider).watchWithCounts(subjectId);
});

/// Nearest deadlines per semester, for the Due soon card on Subjects.
final upcomingProvider = StreamProvider.family<List<UpcomingActivity>, int>((
  ref,
  semesterId,
) {
  return ref.watch(activityRepoProvider).watchUpcoming(semesterId);
});
