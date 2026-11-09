import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/activity_repo.dart';
import 'package:subtrack/features/dashboard/calendar_event_dialog.dart';
import 'package:subtrack/features/dashboard/calendar_event_providers.dart';
import 'package:subtrack/features/dashboard/calendar_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/shared/chips.dart';
import 'package:subtrack/shared/ui_components.dart';

final _monthFormat = DateFormat('MMMM yyyy');
final _dayFormat = DateFormat('EEEE, MMMM d');

const _weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// Stable `yyyy-MM-dd` id for a (local) day, used for grouping deadlines
/// and for test keys.
String calendarDayId(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Key of a day cell in the month grid (also used by tests to tap a day).
String calendarDayKey(DateTime day) => 'calendar-day-${calendarDayId(day)}';

/// Key of the deadline dot inside a day cell (also used by tests).
Key calendarMarkerKey(DateTime day) =>
    ValueKey('calendar-marker-${calendarDayId(day)}');

/// Screen 10 from AGENTS.md section 14: a month view of the chosen
/// semester with a marker on every day that has a deadline. Tapping a day
/// lists that day's activities below the grid.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _month = _firstOfMonth(DateTime.now());
  DateTime? _selected = _today();

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _firstOfMonth(DateTime day) => DateTime(day.year, day.month);

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final semesterId = ref.watch(selectedSemesterProvider);
    final activitiesAsync = ref.watch(calendarActivitiesProvider);
    final eventsAsync = ref.watch(calendarEventsProvider);
    final activities = activitiesAsync.value ?? const <UpcomingActivity>[];
    final events = eventsAsync.value ?? const <CalendarEvent>[];

    final byDay = <String, List<UpcomingActivity>>{};
    for (final item in activities) {
      final deadline = item.activity.deadline;
      if (deadline == null) {
        continue;
      }
      byDay.putIfAbsent(calendarDayId(deadline), () => []).add(item);
    }
    final eventDays = <String>{};
    final eventsByDay = <String, List<CalendarEvent>>{};
    for (final event in events) {
      final start = DateTime(
        event.startsAt.year,
        event.startsAt.month,
        event.startsAt.day,
      );
      final end = event.endsAt == null
          ? start
          : DateTime(
              event.endsAt!.year,
              event.endsAt!.month,
              event.endsAt!.day,
            );
      for (
        var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))
      ) {
        final id = calendarDayId(day);
        eventDays.add(id);
        eventsByDay.putIfAbsent(id, () => []).add(event);
      }
    }

    final selected = _selected;
    final dayItems = selected == null
        ? const <UpcomingActivity>[]
        : (byDay[calendarDayId(selected)] ?? const <UpcomingActivity>[]);
    final selectedEvents = selected == null
        ? const <CalendarEvent>[]
        : (eventsByDay[calendarDayId(selected)] ?? const <CalendarEvent>[]);

    Future<void> editEvent({CalendarEvent? event}) async {
      if (semesterId == null) return;
      final messenger = ScaffoldMessenger.of(context);
      final draft = await showCalendarEventDialog(
        context,
        initialDate: selected ?? _today(),
        event: event,
      );
      if (draft == null || !mounted) return;
      try {
        final repo = ref.read(calendarEventRepoProvider);
        if (event == null) {
          await repo.create(
            semesterId: semesterId,
            title: draft.title,
            startsAt: draft.startsAt,
            endsAt: draft.endsAt,
            notes: draft.notes,
          );
        } else {
          await repo.update(
            id: event.id,
            title: draft.title,
            startsAt: draft.startsAt,
            endsAt: draft.endsAt,
            notes: draft.notes,
          );
        }
      } catch (error) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Could not save event: $error')),
          );
        }
      }
    }

    Future<void> deleteEvent(CalendarEvent event) async {
      final messenger = ScaffoldMessenger.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete event?'),
          content: Text('Delete "${event.title}" from this calendar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await ref.read(calendarEventRepoProvider).delete(event.id);
      } catch (error) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Could not delete event: $error')),
          );
        }
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                    onPressed: _back,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Calendar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${activities.length} '
                          '${activities.length == 1 ? 'deadline' : 'deadlines'}'
                          ' · ${events.length} '
                          '${events.length == 1 ? 'event' : 'events'}',
                          style: TextStyle(
                            color: context.palette.mutedText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add event',
                    onPressed: semesterId == null ? null : () => editEvent(),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (semesterId == null)
                const Expanded(child: _NoSemesterState())
              else if ((activitiesAsync.isLoading &&
                      !activitiesAsync.hasValue) ||
                  (eventsAsync.isLoading && !eventsAsync.hasValue))
                const Expanded(
                  child: AppLoadingState(message: 'Loading calendar...'),
                )
              else if ((activitiesAsync.hasError &&
                      !activitiesAsync.hasValue) ||
                  (eventsAsync.hasError && !eventsAsync.hasValue))
                Expanded(
                  child: AppErrorState(
                    message:
                        'Could not load calendar: '
                        '${activitiesAsync.error ?? eventsAsync.error}',
                  ),
                )
              else ...[
                _MonthCard(
                  month: _month,
                  selected: selected,
                  byDay: byDay,
                  eventDays: eventDays,
                  onPrevious: () => _shiftMonth(-1),
                  onNext: () => _shiftMonth(1),
                  onSelect: (day) => setState(() => _selected = day),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _DayList(
                    day: selected,
                    items: dayItems,
                    events: selectedEvents,
                    onEditEvent: (event) => editEvent(event: event),
                    onDeleteEvent: deleteEvent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The month grid card: month label with previous/next buttons, weekday
/// headers, and 5 to 6 week rows. Deadline days carry a dot marker; the
/// selected day is filled and today keeps a ring.
class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.selected,
    required this.byDay,
    required this.eventDays,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime? selected;
  final Map<String, List<UpcomingActivity>> byDay;
  final Set<String> eventDays;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous month',
                onPressed: onPrevious,
              ),
              Expanded(
                child: Text(
                  _monthFormat.format(month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next month',
                onPressed: onNext,
              ),
            ],
          ),
          Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: palette.mutedText),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ..._weeks(palette),
        ],
      ),
    );
  }

  List<Widget> _weeks(AppPalette palette) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Sunday-first grid: a Sunday (weekday 7) starts the row, else the
    // number of blanks that come before day 1.
    final leadingBlanks = first.weekday % 7;
    final cells = <DateTime?>[
      for (var i = 0; i < leadingBlanks; i++) null,
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(month.year, month.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final rows = <Widget>[];
    for (var start = 0; start < cells.length; start += 7) {
      rows.add(
        Row(
          children: [
            for (var column = 0; column < 7; column++)
              Expanded(child: _dayCell(cells[start + column], palette)),
          ],
        ),
      );
    }
    return rows;
  }

  Widget _dayCell(DateTime? day, AppPalette palette) {
    if (day == null) {
      return const SizedBox(height: 44);
    }
    final isToday = _sameDay(day, DateTime.now());
    final isSelected = selected != null && _sameDay(day, selected!);
    final dayId = calendarDayId(day);
    final hasDeadline = byDay.containsKey(dayId);
    final hasEvent = eventDays.contains(dayId);

    return SizedBox(
      height: 44,
      child: GestureDetector(
        key: ValueKey(calendarDayKey(day)),
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(day),
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? palette.accent : null,
              border: !isSelected && isToday
                  ? Border.all(color: palette.accent, width: 1.4)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? palette.onAccent : palette.text,
                    fontWeight: isToday || isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                SizedBox(
                  height: 4,
                  child: hasDeadline || hasEvent
                      ? SizedBox(
                          key: calendarMarkerKey(day),
                          width: 12,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (hasDeadline)
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? palette.onAccent
                                        : palette.deadlineText,
                                  ),
                                ),
                              if (hasDeadline && hasEvent)
                                const SizedBox(width: 2),
                              if (hasEvent)
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? palette.onAccent
                                        : palette.accentText,
                                  ),
                                ),
                            ],
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// The activities due on the selected day, or a hint when no day is chosen.
class _DayList extends StatelessWidget {
  const _DayList({
    required this.day,
    required this.items,
    required this.events,
    required this.onEditEvent,
    required this.onDeleteEvent,
  });

  final DateTime? day;
  final List<UpcomingActivity> items;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEditEvent;
  final ValueChanged<CalendarEvent> onDeleteEvent;

  @override
  Widget build(BuildContext context) {
    final day = this.day;
    if (day == null) {
      return Center(
        child: Text(
          'Tap a day to see its deadlines.',
          style: TextStyle(color: context.palette.mutedText),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _dayFormat.format(day),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty && events.isEmpty)
          const Expanded(
            child: EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nothing planned for this day.',
              message: 'Add an event or choose another date.',
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: items.length + events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index < items.length) {
                  return _DayActivityCard(item: items[index]);
                }
                final event = events[index - items.length];
                return _DayEventCard(
                  event: event,
                  onEdit: () => onEditEvent(event),
                  onDelete: () => onDeleteEvent(event),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _DayEventCard extends StatelessWidget {
  const _DayEventCard({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final startFormat = DateFormat('h:mm a');
    final timeLabel = event.endsAt == null
        ? startFormat.format(event.startsAt)
        : '${startFormat.format(event.startsAt)} – '
              '${startFormat.format(event.endsAt!)}';
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Icon(Icons.event_note_outlined, color: context.palette.accentText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  timeLabel,
                  style: TextStyle(color: context.palette.mutedText),
                ),
                if (event.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.notes,
                    style: TextStyle(
                      color: context.palette.mutedText,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Event actions',
            onSelected: (action) {
              if (action == 'edit') onEdit();
              if (action == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayActivityCard extends StatelessWidget {
  const _DayActivityCard({required this.item});

  final UpcomingActivity item;

  @override
  Widget build(BuildContext context) {
    final activity = item.activity;
    return AppCard(
      onTap: () => context.push('/activities/${activity.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.subjectName,
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                StatusChip(status: activity.status),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.palette.mutedText),
        ],
      ),
    );
  }
}

class _NoSemesterState extends StatelessWidget {
  const _NoSemesterState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Choose a semester first.'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push('/semesters'),
            child: const Text('Choose semester'),
          ),
        ],
      ),
    );
  }
}
