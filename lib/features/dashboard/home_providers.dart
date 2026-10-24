import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/data/repositories/activity_repo.dart';
import 'package:subtrack/features/activities/activity_providers.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/profile/profile_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';

/// The name shown on the Home dashboard's welcome row: the display name
/// from the profile row, else the username, else the identifier's local
/// part. Never reaches for the network.
final displayNameProvider = Provider<String>((ref) {
  final profile = ref.watch(profileProvider).value;
  final fromProfile = profile?.displayName ?? '';
  if (fromProfile.trim().isNotEmpty) {
    return fromProfile.trim();
  }
  final username = ref.watch(authControllerProvider)?.username ?? '';
  if (username.isNotEmpty) {
    return username;
  }
  final email = ref.watch(authControllerProvider)?.email ?? '';
  return email.contains('@') ? email.split('@').first : email;
});

/// The next 3 not-submitted activities with deadlines in the chosen
/// semester, soonest first (overdue first of all). Empty until a semester
/// is chosen.
final dueSoonProvider = StreamProvider<List<UpcomingActivity>>((ref) {
  final semesterId = ref.watch(selectedSemesterProvider);
  if (semesterId == null) {
    return Stream<List<UpcomingActivity>>.value(const []);
  }
  return ref.watch(activityRepoProvider).watchDueSoon(semesterId);
});

/// Undone activity counts per status in the chosen semester, for the
/// segmented bar. Empty until a semester is chosen.
final statusCountsProvider = StreamProvider<Map<String, int>>((ref) {
  final semesterId = ref.watch(selectedSemesterProvider);
  if (semesterId == null) {
    return Stream<Map<String, int>>.value(const {});
  }
  return ref.watch(activityRepoProvider).watchStatusCounts(semesterId);
});
