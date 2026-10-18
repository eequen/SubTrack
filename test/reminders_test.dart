import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';
import 'package:subtrack/features/reminders/reminder_service.dart';

void main() {
  late AppDatabase db;
  late ReminderService service;
  late int subjectId;

  /// Whole-minute base so the stored value (drift keeps seconds) compares
  /// exactly with what the query returns.
  final now = DateTime.now();
  final base = DateTime(now.year, now.month, now.day, now.hour, now.minute);

  setUp(() async {
    db = AppDatabase.memory();
    service = ReminderService(db);
    final semesterId = await SemesterRepo(db).create(
      term: 'first',
      schoolYear: '2026-2027',
      startDate: DateTime(2026, 8, 18),
      endDate: DateTime(2026, 12, 19),
    );
    subjectId = await SubjectRepo(db)
        .create(semesterId: semesterId, name: 'CP1', color: 0xFF3B4BDB);
  });

  tearDown(() => db.close());

  Future<int> addActivity(
    String title, {
    DateTime? deadline,
    String status = 'draft',
    bool archived = false,
    int? inSubject,
  }) {
    return db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(
            subjectId: inSubject ?? subjectId,
            title: title,
            deadline: Value(deadline),
            status: Value(status),
            isArchived: Value(archived),
          ),
        );
  }

  test('keeps only future, active deadlines', () async {
    final soon = base.add(const Duration(hours: 2));
    await addActivity('Due soon', deadline: soon);
    await addActivity('No deadline');
    await addActivity(
      'Past due',
      deadline: base.subtract(const Duration(hours: 1)),
    );
    await addActivity('Archived', deadline: soon, archived: true);
    await addActivity('Submitted', deadline: soon, status: 'submitted');

    final upcoming = await service.upcoming();
    expect(upcoming.map((d) => d.title), ['Due soon']);
    expect(upcoming.single.subjectName, 'CP1');
    expect(upcoming.single.deadline, soon);
  });

  test('keeps the activity id for the notification', () async {
    final id = await addActivity(
      'Due soon',
      deadline: base.add(const Duration(hours: 1)),
    );
    expect((await service.upcoming()).single.activityId, id);
  });

  test('orders nearest first and spans semesters', () async {
    final other = await SemesterRepo(db).create(
      term: 'second',
      schoolYear: '2026-2027',
      startDate: DateTime(2027, 1, 11),
      endDate: DateTime(2027, 5, 29),
    );
    final math = await SubjectRepo(db)
        .create(semesterId: other, name: 'Math', color: 0xFF0B7A6B);
    await addActivity('Later', deadline: base.add(const Duration(hours: 3)));
    await addActivity('Nearest', deadline: base.add(const Duration(hours: 1)));
    await addActivity(
      'Middle',
      deadline: base.add(const Duration(hours: 2)),
      inSubject: math,
    );

    final upcoming = await service.upcoming();
    expect(upcoming.map((d) => d.title), ['Nearest', 'Middle', 'Later']);
    expect(upcoming[1].subjectName, 'Math');
  });
}
