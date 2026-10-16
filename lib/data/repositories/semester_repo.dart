import 'package:drift/drift.dart';
import 'package:subtrack/data/db/app_database.dart';

/// Human label for a stored term value (`first`, `second`, `summer`).
String semesterLabel(String term) {
  switch (term) {
    case 'first':
      return '1st Semester';
    case 'second':
      return '2nd Semester';
    case 'summer':
      return 'Summer';
    default:
      return term;
  }
}

class SemesterListItem {
  const SemesterListItem({
    required this.semester,
    required this.subjectCount,
    required this.fileCount,
  });

  final Semester semester;
  final int subjectCount;
  final int fileCount;
}

class SemesterRepo {
  SemesterRepo(this.db);

  final AppDatabase db;

  Stream<List<Semester>> watchAll() {
    return (db.select(
      db.semesters,
    )..orderBy([(s) => OrderingTerm.desc(s.id)])).watch();
  }

  Stream<Semester?> watchById(int id) {
    return (db.select(
      db.semesters,
    )..where((s) => s.id.equals(id))).watchSingleOrNull();
  }

  Future<Semester?> getById(int id) {
    return (db.select(
      db.semesters,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  Stream<List<SemesterListItem>> watchAllWithCounts() {
    final subjectCount = db.subjects.id.count(distinct: true);
    final fileCount = db.files.id.count(distinct: true);
    final query = db.select(db.semesters).join([
      leftOuterJoin(
        db.subjects,
        db.subjects.semesterId.equalsExp(db.semesters.id),
      ),
      leftOuterJoin(
        db.activities,
        db.activities.subjectId.equalsExp(db.subjects.id),
      ),
      leftOuterJoin(db.files, db.files.activityId.equalsExp(db.activities.id)),
    ]);
    query
      ..addColumns([subjectCount, fileCount])
      ..orderBy([OrderingTerm.desc(db.semesters.id)])
      ..groupBy([db.semesters.id]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => SemesterListItem(
              semester: row.readTable(db.semesters),
              subjectCount: row.read(subjectCount) ?? 0,
              fileCount: row.read(fileCount) ?? 0,
            ),
          )
          .toList(),
    );
  }

  Future<int> create({
    required String term,
    required String schoolYear,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (schoolYear.trim().isEmpty) {
      throw ArgumentError('School year is required.');
    }
    if (!endDate.isAfter(startDate)) {
      throw ArgumentError('End date must be after start date.');
    }
    return db
        .into(db.semesters)
        .insert(
          SemestersCompanion.insert(
            term: term,
            schoolYear: schoolYear.trim(),
            startDate: startDate,
            endDate: endDate,
          ),
        );
  }

  Future<void> delete(int id) {
    return (db.delete(db.semesters)..where((s) => s.id.equals(id))).go();
  }
}
