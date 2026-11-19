import 'package:drift/drift.dart';
import 'package:subtrack/data/db/app_database.dart';

class CalendarEventRepo {
  CalendarEventRepo(this.db);

  final AppDatabase db;

  Stream<List<CalendarEvent>> watchInSemester(int semesterId) {
    final query = db.select(db.calendarEvents)
      ..where((event) => event.semesterId.equals(semesterId))
      ..orderBy([(event) => OrderingTerm.asc(event.startsAt)]);
    return query.watch();
  }

  Stream<List<CalendarEvent>> watchUpcoming(int semesterId, {int limit = 3}) {
    final now = DateTime.now();
    final query = db.select(db.calendarEvents)
      ..where(
        (event) =>
            event.semesterId.equals(semesterId) &
            event.startsAt.isBiggerOrEqualValue(now),
      )
      ..orderBy([(event) => OrderingTerm.asc(event.startsAt)])
      ..limit(limit);
    return query.watch();
  }

  Future<int> create({
    required int semesterId,
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    String notes = '',
  }) async {
    _validate(title, startsAt, endsAt);
    return db
        .into(db.calendarEvents)
        .insert(
          CalendarEventsCompanion.insert(
            semesterId: semesterId,
            title: title.trim(),
            startsAt: startsAt,
            endsAt: Value(endsAt),
            notes: Value(notes.trim()),
          ),
        );
  }

  Future<void> update({
    required int id,
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    String notes = '',
  }) async {
    _validate(title, startsAt, endsAt);
    await (db.update(
      db.calendarEvents,
    )..where((event) => event.id.equals(id))).write(
      CalendarEventsCompanion(
        title: Value(title.trim()),
        startsAt: Value(startsAt),
        endsAt: Value(endsAt),
        notes: Value(notes.trim()),
      ),
    );
  }

  Future<void> delete(int id) async {
    await (db.delete(
      db.calendarEvents,
    )..where((event) => event.id.equals(id))).go();
  }

  void _validate(String title, DateTime startsAt, DateTime? endsAt) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Event title is required.');
    }
    if (endsAt != null && !endsAt.isAfter(startsAt)) {
      throw ArgumentError.value(
        endsAt,
        'endsAt',
        'End time must be after start time.',
      );
    }
  }
}
