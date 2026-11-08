import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/features/auth/auth_providers.dart';

/// One database file per signed-in user (AGENTS.md section 8).
/// Lives outside `features/` because every feature needs it.
final databaseProvider = Provider<AppDatabase>((ref) {
  final userId = ref.watch(authControllerProvider)?.id ?? 'signed-out';
  final db = AppDatabase.forUser(userId);
  ref.onDispose(() => db.close());
  return db;
});
