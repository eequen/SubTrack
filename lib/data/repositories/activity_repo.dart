import 'package:subtrack/data/db/app_database.dart';

/// Method signatures only; CRUD lands in Phase 2.
class ActivityRepo {
  ActivityRepo(this.db);

  final AppDatabase db;

  Stream<List<Activity>> watchBySubject(int subjectId) =>
      throw UnimplementedError();

  Future<int> create({
    required int subjectId,
    required String title,
    String notes = '',
    DateTime? deadline,
    String status = 'draft',
  }) => throw UnimplementedError();

  Future<void> updateDetails({
    required int id,
    String? title,
    String? notes,
    DateTime? deadline,
    String? status,
  }) => throw UnimplementedError();

  Future<void> setArchived(int id, bool archived) => throw UnimplementedError();

  Future<void> delete(int id) => throw UnimplementedError();
}
