import 'package:subtrack/data/db/app_database.dart';

/// Method signatures only; CRUD lands in Phase 2.
class SubjectRepo {
  SubjectRepo(this.db);

  final AppDatabase db;

  Stream<List<Subject>> watchBySemester(int semesterId) =>
      throw UnimplementedError();

  Future<int> create({
    required int semesterId,
    required String name,
    required int color,
    String icon = '',
  }) => throw UnimplementedError();

  Future<void> rename(int id, String name) => throw UnimplementedError();

  Future<void> setArchived(int id, bool archived) => throw UnimplementedError();

  Future<void> delete(int id) => throw UnimplementedError();
}
