import 'package:flutter_test/flutter_test.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/calendar_event_repo.dart';

void main() {
  test(
    'calendar events are semester-scoped and support update/delete',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final semesterId = await db
          .into(db.semesters)
          .insert(
            SemestersCompanion.insert(
              term: 'first',
              schoolYear: '2026-2027',
              startDate: DateTime(2026, 8, 1),
              endDate: DateTime(2026, 12, 15),
            ),
          );
      final repo = CalendarEventRepo(db);
      final id = await repo.create(
        semesterId: semesterId,
        title: '  Science fair  ',
        startsAt: DateTime(2026, 9, 5, 10),
        notes: '  Bring a poster.  ',
      );

      final event = (await repo.watchInSemester(semesterId).first).single;
      expect(event.id, id);
      expect(event.title, 'Science fair');
      expect(event.notes, 'Bring a poster.');
      expect(event.endsAt, isNull);

      await repo.update(
        id: id,
        title: 'Science fair setup',
        startsAt: DateTime(2026, 9, 5, 9),
        endsAt: DateTime(2026, 9, 5, 11),
      );
      final updated = (await repo.watchInSemester(semesterId).first).single;
      expect(updated.title, 'Science fair setup');
      expect(updated.startsAt, DateTime(2026, 9, 5, 9));
      expect(updated.endsAt, DateTime(2026, 9, 5, 11));

      await repo.delete(id);
      expect(await db.select(db.calendarEvents).get(), isEmpty);
    },
  );

  test('rejects empty titles and an end time before the start', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final semesterId = await db
        .into(db.semesters)
        .insert(
          SemestersCompanion.insert(
            term: 'first',
            schoolYear: '2026-2027',
            startDate: DateTime(2026, 8, 1),
            endDate: DateTime(2026, 12, 15),
          ),
        );
    final repo = CalendarEventRepo(db);

    await expectLater(
      repo.create(
        semesterId: semesterId,
        title: ' ',
        startsAt: DateTime(2026, 9, 5, 10),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repo.create(
        semesterId: semesterId,
        title: 'Science fair',
        startsAt: DateTime(2026, 9, 5, 10),
        endsAt: DateTime(2026, 9, 5, 10),
      ),
      throwsArgumentError,
    );
    expect(await db.select(db.calendarEvents).get(), isEmpty);
  });
}
