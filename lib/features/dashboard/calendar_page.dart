import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/repositories/activity_repo.dart';
import 'package:subtrack/features/dashboard/calendar_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/shared/chips.dart';

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
    final activities =
        ref.watch(calendarActivitiesProvider).value ??
        const <UpcomingActivity>[];

    final byDay = <String, List<UpcomingActivity>>{};
    for (final item in activities) {
      final deadline = item.activity.deadline;
      if (deadline == null) {
        continue;
      }
      byDay.putIfAbsent(calendarDayId(deadline), () => []).add(item);
    }

    final selected = _selected;
    final dayItems = selected == null
        ? const <UpcomingActivity>[]
        : (byDay[calendarDayId(selected)] ?? const <UpcomingActivity>[]);

    final count = activities.length;

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
                          count == 1 ? '1 deadline' : '$count deadlines',
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (semesterId == null)
                const Expanded(child: _NoSemesterState())
              else ...[
                _MonthCard(
                  month: _month,
                  selected: selected,
                  byDay: byDay,
                  onPrevious: () => _shiftMonth(-1),
                  onNext: () => _shiftMonth(1),
                  onSelect: (day) => setState(() => _selected = day),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _DayList(day: selected, items: dayItems),
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
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime? selected;
  final Map<String, List<UpcomingActivity>> byDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
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
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ..._weeks(),
        ],
      ),
    );
  }

  List<Widget> _weeks() {
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
              Expanded(child: _dayCell(cells[start + column])),
          ],
        ),
      );
    }
    return rows;
  }

  Widget _dayCell(DateTime? day) {
    if (day == null) {
      return const SizedBox(height: 44);
    }
    final isToday = _sameDay(day, DateTime.now());
    final isSelected = selected != null && _sameDay(day, selected!);
    final hasDeadline = byDay.containsKey(calendarDayId(day));

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
              color: isSelected ? AppColors.accent : null,
              border: !isSelected && isToday
                  ? Border.all(color: AppColors.accent, width: 1.4)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.white : AppColors.text,
                    fontWeight: isToday || isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                SizedBox(
                  height: 4,
                  child: hasDeadline
                      ? Container(
                          key: calendarMarkerKey(day),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? Colors.white : AppColors.accent,
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
  const _DayList({required this.day, required this.items});

  final DateTime? day;
  final List<UpcomingActivity> items;

  @override
  Widget build(BuildContext context) {
    final day = this.day;
    if (day == null) {
      return const Center(
        child: Text(
          'Tap a day to see its deadlines.',
          style: TextStyle(color: AppColors.mutedText),
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
        if (items.isEmpty)
          const Text(
            'No deadlines on this day.',
            style: TextStyle(color: AppColors.mutedText),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _DayActivityCard(item: items[index]),
            ),
          ),
      ],
    );
  }
}

class _DayActivityCard extends StatelessWidget {
  const _DayActivityCard({required this.item});

  final UpcomingActivity item;

  @override
  Widget build(BuildContext context) {
    final activity = item.activity;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: () => context.push('/activities/${activity.id}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subjectName,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    StatusChip(status: activity.status),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.mutedText),
            ],
          ),
        ),
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
