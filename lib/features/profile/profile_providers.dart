import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/profile_repo.dart';
import 'package:subtrack/features/auth/auth_providers.dart';

final profileRepoProvider = Provider<ProfileRepo>((ref) {
  return ProfileRepo(
    ref.watch(databaseProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

/// The signed-in account's local profile row (AGENTS.md section 8).
/// Creates it on first run and emits again on every save. Theme,
/// notifications, and the backup check boxes all read from here so each
/// account keeps its own settings.
final profileProvider = StreamProvider<DbProfile?>((ref) async* {
  final user = ref.watch(authControllerProvider);
  final repo = ref.watch(profileRepoProvider);
  if (user == null) return;

  // The username can be empty for sessions restored offline; fall back to
  // the email/identifier so the row is never blank.
  final username = user.username.isNotEmpty ? user.username : user.email;
  await repo.ensure(userId: user.id, username: username);
  yield* repo.watch(user.id);
});
