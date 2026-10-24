import 'package:drift/drift.dart';
import 'package:subtrack/data/db/app_database.dart';

/// An activity with rolled-up counts for its card ("N files - latest vN").
class ActivityListItem {
  const ActivityListItem({
    required this.activity,
    required this.fileCount,
    required this.latestVersion,
  });

  final Activity activity;
  final int fileCount;
  final int? latestVersion;
}

/// An activity heading towards its deadline, with its subject's name.
class UpcomingActivity {
  const UpcomingActivity({required this.activity, required this.subjectName});

  final Activity activity;
  final String subjectName;
}

class SemesterActivityItem {
  const SemesterActivityItem({
    required this.activity,
    required this.subjectName,
    required this.fileCount,
    required this.latestVersion,
  });

  final Activity activity;
  final String subjectName;
  final int fileCount;
  final int? latestVersion;
}

class ActivityRepo {
  ActivityRepo(this.db);

  final AppDatabase db;

  static const statuses = <String>[
    'draft',
    'in_progress',
    'final',
    'submitted',
  ];

  void _checkStatus(String status) {
    if (!statuses.contains(status)) {
      throw ArgumentError('Unknown status: $status');
    }
  }

  Stream<List<Activity>> watchBySubject(int subjectId) {
    final query = db.select(db.activities)
      ..where((a) => a.subjectId.equals(subjectId))
      ..orderBy([(a) => OrderingTerm.desc(a.id)]);
    return query.watch();
  }

  Stream<Activity?> watchById(int id) {
    return (db.select(
      db.activities,
    )..where((a) => a.id.equals(id))).watchSingleOrNull();
  }

  /// Newest first, with file count and highest version number per activity.
  Stream<List<ActivityListItem>> watchWithCounts(int subjectId) {
    final fileCount = db.files.id.count(distinct: true);
    final latestVersion = db.commits.versionNo.max();
    final query =
        db.select(db.activities).join([
            leftOuterJoin(
              db.files,
              db.files.activityId.equalsExp(db.activities.id),
            ),
            leftOuterJoin(db.commits, db.commits.fileId.equalsExp(db.files.id)),
          ])
          ..where(db.activities.subjectId.equals(subjectId))
          ..addColumns([fileCount, latestVersion])
          ..orderBy([OrderingTerm.desc(db.activities.id)])
          ..groupBy([db.activities.id]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ActivityListItem(
              activity: row.readTable(db.activities),
              fileCount: row.read(fileCount) ?? 0,
              latestVersion: row.read(latestVersion),
            ),
          )
          .toList(),
    );
  }

  /// Nearest future deadlines in [semesterId] for the Due soon card.
  /// Past or null deadlines and archived activities are excluded.
  Stream<List<UpcomingActivity>> watchUpcoming(
    int semesterId, {
    int limit = 3,
  }) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final query =
        db.select(db.activities).join([
            innerJoin(
              db.subjects,
              db.subjects.id.equalsExp(db.activities.subjectId),
            ),
          ])
          ..where(
            db.subjects.semesterId.equals(semesterId) &
                db.activities.isArchived.equals(false) &
                db.activities.deadline.isNotNull(),
          )
          ..orderBy([OrderingTerm.asc(db.activities.deadline)]);
    // Small data per semester, so the future-only filter runs here.
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => UpcomingActivity(
              activity: row.readTable(db.activities),
              subjectName: row.readTable(db.subjects).name,
            ),
          )
          .where((u) => !u.activity.deadline!.isBefore(startOfDay))
          .take(limit)
          .toList(),
    );
  }

  /// The Home dashboard's Due very soon list: not submitted, has a
  /// deadline, earliest first — so overdue items come first. Unlike
  /// [watchUpcoming], past deadlines are included.
  Stream<List<UpcomingActivity>> watchDueSoon(int semesterId, {int limit = 3}) {
    final query =
        db.select(db.activities).join([
            innerJoin(
              db.subjects,
              db.subjects.id.equalsExp(db.activities.subjectId),
            ),
          ])
          ..where(
            db.subjects.semesterId.equals(semesterId) &
                db.activities.isArchived.equals(false) &
                db.activities.deadline.isNotNull() &
                db.activities.status.isNotIn(const ['submitted']),
          )
          ..orderBy([OrderingTerm.asc(db.activities.deadline)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => UpcomingActivity(
              activity: row.readTable(db.activities),
              subjectName: row.readTable(db.subjects).name,
            ),
          )
          .take(limit)
          .toList(),
    );
  }

  /// Undone activity counts per status inside a semester, for the Home
  /// dashboard's segmented bar. Archived activities are not counted.
  Stream<Map<String, int>> watchStatusCounts(int semesterId) {
    final count = db.activities.id.count();
    final query =
        db.select(db.activities).join([
            innerJoin(
              db.subjects,
              db.subjects.id.equalsExp(db.activities.subjectId),
            ),
          ])
          ..where(
            db.subjects.semesterId.equals(semesterId) &
                db.activities.isArchived.equals(false),
          )
          ..addColumns([count])
          ..groupBy([db.activities.status]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.readTable(db.activities).status: row.read(count) ?? 0,
      },
    );
  }

  /// Every activity in a semester (across subjects) for the All activities
  /// screen, with the subject's name and per-activity counts.
  Stream<List<SemesterActivityItem>> watchAllInSemester(int semesterId) {
    final fileCount = db.files.id.count(distinct: true);
    final latestVersion = db.commits.versionNo.max();
    final query =
        db.select(db.activities).join([
            innerJoin(
              db.subjects,
              db.subjects.id.equalsExp(db.activities.subjectId),
            ),
            leftOuterJoin(
              db.files,
              db.files.activityId.equalsExp(db.activities.id),
            ),
            leftOuterJoin(db.commits, db.commits.fileId.equalsExp(db.files.id)),
          ])
          ..where(
            db.subjects.semesterId.equals(semesterId) &
                db.activities.isArchived.equals(false),
          )
          ..addColumns([fileCount, latestVersion])
          ..groupBy([db.activities.id]);
    return query.watch().map((rows) {
      final items = rows
          .map(
            (row) => SemesterActivityItem(
              activity: row.readTable(db.activities),
              subjectName: row.readTable(db.subjects).name,
              fileCount: row.read(fileCount) ?? 0,
              latestVersion: row.read(latestVersion),
            ),
          )
          .toList();
      // Deadlines first (earliest on top), everything without one last.
      items.sort((a, b) {
        final da = a.activity.deadline;
        final dbv = b.activity.deadline;
        if (da == null && dbv == null) {
          return b.activity.id.compareTo(a.activity.id);
        }
        if (da == null) return 1;
        if (dbv == null) return -1;
        return da.compareTo(dbv);
      });
      return items;
    });
  }

  Future<int> create({
    required int subjectId,
    required String title,
    String notes = '',
    DateTime? deadline,
    String status = 'draft',
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Activity title is required.');
    }
    _checkStatus(status);
    return db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(
            subjectId: subjectId,
            title: trimmed,
            notes: Value(notes.trim()),
            deadline: Value(deadline),
            status: Value(status),
          ),
        );
  }

  /// Writes only the non-null fields. Use [setDeadline] to move or clear a
  /// deadline, since null here means "leave unchanged".
  Future<void> updateDetails({
    required int id,
    String? title,
    String? notes,
    DateTime? deadline,
    String? status,
  }) async {
    if (title != null && title.trim().isEmpty) {
      throw ArgumentError('Activity title is required.');
    }
    if (status != null) _checkStatus(status);
    await (db.update(db.activities)..where((a) => a.id.equals(id))).write(
      ActivitiesCompanion(
        title: title == null ? const Value.absent() : Value(title.trim()),
        notes: notes == null ? const Value.absent() : Value(notes.trim()),
        deadline: deadline == null ? const Value.absent() : Value(deadline),
        status: status == null ? const Value.absent() : Value(status),
      ),
    );
  }

  /// Moves or clears (null) the deadline.
  Future<void> setDeadline(int id, DateTime? deadline) async {
    await (db.update(db.activities)..where((a) => a.id.equals(id))).write(
      ActivitiesCompanion(deadline: Value(deadline)),
    );
  }

  Future<void> setArchived(int id, bool archived) async {
    await (db.update(db.activities)..where((a) => a.id.equals(id))).write(
      ActivitiesCompanion(isArchived: Value(archived)),
    );
  }

  Future<void> delete(int id) async {
    await (db.delete(db.activities)..where((a) => a.id.equals(id))).go();
  }
}
