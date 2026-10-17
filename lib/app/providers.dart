import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/features/auth/auth_providers.dart';

/// One database file per signed-in user (AGENTS.md section 8).
/// Lives outside `features/` because every feature needs it.
final databaseProvider = Provider<AppDatabase>((ref) {
  final email = ref.watch(authControllerProvider)?.email ?? 'signed-out';
  final db = AppDatabase.forUser(email);
  ref.onDispose(() => db.close());
  return db;
});
