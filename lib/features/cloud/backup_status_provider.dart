import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/features/auth/auth_providers.dart';

class LocalBackupPending extends Notifier<bool> {
  late String _key;

  @override
  bool build() {
    final userId = ref.watch(authControllerProvider)?.id ?? 'signed-out';
    _key = 'subtrack_local_backup_pending:$userId';
    return ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;
  }

  Future<void> markPending() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, true);
    state = true;
  }

  Future<void> markBackedUp() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, false);
    state = false;
  }
}

final localBackupPendingProvider = NotifierProvider<LocalBackupPending, bool>(
  LocalBackupPending.new,
);
