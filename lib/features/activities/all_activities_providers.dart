import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/data/repositories/activity_repo.dart';
import 'package:subtrack/features/activities/activity_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';

/// The item type used on the All activities screen; defined in
/// [ActivityRepo].
typedef AllActivitiesItem = SemesterActivityItem;

/// Every activity in the chosen semester across all subjects, deadlines
/// first. Empty until a semester is chosen.
final allActivitiesProvider = StreamProvider<List<AllActivitiesItem>>((ref) {
  final semesterId = ref.watch(selectedSemesterProvider);
  if (semesterId == null) {
    return Stream<List<AllActivitiesItem>>.value(const []);
  }
  return ref.watch(activityRepoProvider).watchAllInSemester(semesterId);
});
