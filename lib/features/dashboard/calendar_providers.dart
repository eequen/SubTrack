import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/data/repositories/activity_repo.dart';
import 'package:subtrack/features/activities/activity_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';

/// Every deadline in the chosen semester, for the Calendar month view and
/// the selected day's list. Empty until a semester is chosen.
final calendarActivitiesProvider = StreamProvider<List<UpcomingActivity>>((
  ref,
) {
  final semesterId = ref.watch(selectedSemesterProvider);
  if (semesterId == null) {
    return Stream<List<UpcomingActivity>>.value(const []);
  }
  return ref.watch(activityRepoProvider).watchDeadlinesInSemester(semesterId);
});
