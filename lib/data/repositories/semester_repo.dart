import 'package:subtrack/data/db/app_database.dart';

/// Method signatures only; CRUD lands in Phase 2.
class SemesterRepo {
  SemesterRepo(this.db);

  final AppDatabase db;

  Stream<List<Semester>> watchAll() => throw UnimplementedError();

  Future<int> create({
    required String term,
    required String schoolYear,
    required DateTime startDate,
    required DateTime endDate,
  }) => throw UnimplementedError();

  Future<void> delete(int id) => throw UnimplementedError();
}
