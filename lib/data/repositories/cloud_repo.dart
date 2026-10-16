import 'package:subtrack/data/db/app_database.dart';

/// Manual cloud backup lands in Phase 5.
class CloudRepo {
  CloudRepo(this.db);

  final AppDatabase db;
}
