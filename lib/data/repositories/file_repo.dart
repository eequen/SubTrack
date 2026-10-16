import 'package:subtrack/data/db/app_database.dart';

/// Method signatures only; upload flow lands in Phase 2.
class FileRepo {
  FileRepo(this.db);

  final AppDatabase db;

  Stream<List<DbFile>> watchByActivity(int activityId) =>
      throw UnimplementedError();

  Future<int> create({required int activityId, required String displayName}) =>
      throw UnimplementedError();

  Future<void> setCurrentCommit(int fileId, int commitId) =>
      throw UnimplementedError();

  Future<void> delete(int id) => throw UnimplementedError();
}
