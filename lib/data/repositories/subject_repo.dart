import 'package:drift/drift.dart';
import 'package:subtrack/data/db/app_database.dart';

/// A subject with rolled-up counts for the list screen.
class SubjectListItem {
  const SubjectListItem({
    required this.subject,
    required this.activityCount,
    required this.fileCount,
  });

  final Subject subject;
  final int activityCount;
  final int fileCount;
}

class SubjectRepo {
  SubjectRepo(this.db);

  final AppDatabase db;

  Stream<List<Subject>> watchBySemester(int semesterId) {
    final query = db.select(db.subjects)
      ..where((s) => s.semesterId.equals(semesterId))
      ..orderBy([
        (s) => OrderingTerm.asc(s.isArchived),
        (s) => OrderingTerm.asc(s.name),
      ]);
    return query.watch();
  }

  /// Active subjects first, then archived, each sorted by name.
  Stream<List<SubjectListItem>> watchWithCounts(int semesterId) {
    final activityCount = db.activities.id.count(distinct: true);
    final fileCount = db.files.id.count(distinct: true);
    final query =
        db.select(db.subjects).join([
            leftOuterJoin(
              db.activities,
              db.activities.subjectId.equalsExp(db.subjects.id),
            ),
            leftOuterJoin(
              db.files,
              db.files.activityId.equalsExp(db.activities.id),
            ),
          ])
          ..where(db.subjects.semesterId.equals(semesterId))
          ..addColumns([activityCount, fileCount])
          ..orderBy([
            OrderingTerm.asc(db.subjects.isArchived),
            OrderingTerm.asc(db.subjects.name),
          ])
          ..groupBy([db.subjects.id]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => SubjectListItem(
              subject: row.readTable(db.subjects),
              activityCount: row.read(activityCount) ?? 0,
              fileCount: row.read(fileCount) ?? 0,
            ),
          )
          .toList(),
    );
  }

  Stream<Subject?> watchById(int id) {
    return (db.select(
      db.subjects,
    )..where((s) => s.id.equals(id))).watchSingleOrNull();
  }

  Future<int> create({
    required int semesterId,
    required String name,
    required int color,
    String icon = '',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Subject name is required.');
    }
    return db
        .into(db.subjects)
        .insert(
          SubjectsCompanion.insert(
            semesterId: semesterId,
            name: trimmed,
            color: color,
            icon: Value(icon.trim()),
          ),
        );
  }

  Future<void> rename(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Subject name is required.');
    }
    await (db.update(db.subjects)..where((s) => s.id.equals(id))).write(
      SubjectsCompanion(name: Value(trimmed)),
    );
  }

  Future<void> setArchived(int id, bool archived) async {
    await (db.update(db.subjects)..where((s) => s.id.equals(id))).write(
      SubjectsCompanion(isArchived: Value(archived)),
    );
  }

  Future<void> delete(int id) async {
    await (db.delete(db.subjects)..where((s) => s.id.equals(id))).go();
  }
}
