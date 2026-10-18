import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:timezone/timezone.dart' as tz;

/// An activity that is due, ready to become a notification.
class UpcomingDeadline {
  const UpcomingDeadline({
    required this.activityId,
    required this.title,
    required this.subjectName,
    required this.deadline,
  });

  final int activityId;
  final String title;
  final String subjectName;
  final DateTime deadline;
}

/// Schedules deadline reminders as local notifications (Phase 4).
///
/// The database is the source of truth: [syncAll] clears everything this
/// app scheduled and creates one notification per activity that is due in
/// the future (any semester, not archived, not submitted). Call it after
/// any change that can move a deadline. Failures are logged, never thrown:
/// reminders are best-effort and must not break the main flows.
class ReminderService {
  ReminderService(this.db, {FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final AppDatabase db;
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _channelId = 'deadlines';

  /// Activities with a future deadline, nearest first.
  Future<List<UpcomingDeadline>> upcoming() async {
    final now = DateTime.now();
    final query =
        db.select(db.activities).join([
            innerJoin(
              db.subjects,
              db.subjects.id.equalsExp(db.activities.subjectId),
            ),
          ])
          ..where(
            db.activities.deadline.isNotNull() &
                db.activities.isArchived.equals(false) &
                db.activities.status.equals('submitted').not(),
          )
          ..orderBy([OrderingTerm.asc(db.activities.deadline)]);
    final rows = await query.get();
    return [
      for (final row in rows)
        UpcomingDeadline(
          activityId: row.readTable(db.activities).id,
          title: row.readTable(db.activities).title,
          subjectName: row.readTable(db.subjects).name,
          deadline: row.readTable(db.activities).deadline!,
        ),
    ].where((d) => d.deadline.isAfter(now)).toList();
  }

  /// Asks for the notification permission. On Android 13+ this shows the
  /// system dialog the first time; before that it just reports whether
  /// notifications are enabled for the app.
  Future<bool> requestPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (e) {
      debugPrint('Reminders: permission request failed: $e');
      return false;
    }
  }

  /// Re-creates every reminder from the current database state.
  Future<void> syncAll() async {
    final List<UpcomingDeadline> deadlines;
    try {
      deadlines = await upcoming();
    } catch (e) {
      debugPrint('Reminders: could not read deadlines: $e');
      return;
    }
    try {
      await _ensureInitialized();
      await _plugin.cancelAll();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      // Exact alarms when the platform allows them; otherwise Android fires
      // them at roughly the right time, which is fine for a reminder.
      final exact = await android?.canScheduleExactNotifications() ?? false;
      for (final deadline in deadlines) {
        try {
          await _schedule(deadline, exact: exact);
        } catch (e) {
          debugPrint('Reminders: could not schedule "${deadline.title}": $e');
        }
      }
    } catch (e) {
      debugPrint('Reminders: sync failed: $e');
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  Future<void> _schedule(UpcomingDeadline deadline, {required bool exact}) {
    // The stored deadline is local wall-clock time. Going through tz.UTC
    // keeps the exact instant: the plugin sends the location name to
    // Android, which converts it back, so no timezone database is needed.
    final when = tz.TZDateTime.from(deadline.deadline, tz.UTC);
    return _plugin.zonedSchedule(
      id: deadline.activityId,
      title: deadline.title,
      body: '${deadline.subjectName} - deadline reached',
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Deadlines',
          channelDescription: 'Reminders for activity deadlines',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
