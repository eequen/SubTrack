import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/calendar_event_repo.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';

final calendarEventRepoProvider = Provider<CalendarEventRepo>(
  (ref) => CalendarEventRepo(ref.watch(databaseProvider)),
);

final calendarEventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  final semesterId = ref.watch(selectedSemesterProvider);
  if (semesterId == null) {
    return Stream.value(const <CalendarEvent>[]);
  }
  return ref.watch(calendarEventRepoProvider).watchInSemester(semesterId);
});

final upcomingCalendarEventsProvider = StreamProvider<List<CalendarEvent>>((
  ref,
) {
  final semesterId = ref.watch(selectedSemesterProvider);
  if (semesterId == null) {
    return Stream.value(const <CalendarEvent>[]);
  }
  return ref.watch(calendarEventRepoProvider).watchUpcoming(semesterId);
});
