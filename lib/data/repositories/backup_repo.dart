import 'package:subtrack/data/db/app_database.dart';

/// Local .zip export/import lands in Phase 4.
class BackupRepo {
  BackupRepo(this.db);

  final AppDatabase db;
}
