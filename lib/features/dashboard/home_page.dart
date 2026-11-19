import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/activity_repo.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/features/dashboard/home_providers.dart';
import 'package:subtrack/features/dashboard/calendar_event_providers.dart';
import 'package:subtrack/features/profile/profile_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/features/semesters/semesters_page.dart';
import 'package:subtrack/shared/brand_logo.dart';
import 'package:subtrack/shared/ui_components.dart';

final _dueSoonFormat = DateFormat('MMM d');

/// "Overdue - Oct 20" for past dates, "Today"/"Tomorrow" or "Oct 27"
/// otherwise.
String dueLabel(DateTime deadline) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(deadline.year, deadline.month, deadline.day);
  final days = due.difference(today).inDays;
  if (days < 0) {
    return 'Overdue - ${_dueSoonFormat.format(deadline)}';
  }
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return _dueSoonFormat.format(deadline);
}

bool isOverdue(DateTime? deadline) {
  if (deadline == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return deadline.isBefore(today);
}

/// Screen 3 and 4 from AGENTS.md section 14: the Home dashboard.
///
/// Returning students see the chosen semester's pill, progress, and due
/// activities. A student without a chosen semester gets an amber pill and
/// a dashed "add your first semester" card.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final displayName = ref.watch(displayNameProvider);
    final profile = ref.watch(profileProvider).value;

    final selectedId = ref.watch(selectedSemesterProvider);
    final semestersAsync = ref.watch(semestersProvider);
    if (semestersAsync.isLoading && !semestersAsync.hasValue) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Loading your semesters...'),
        ),
      );
    }
    if (semestersAsync.hasError && !semestersAsync.hasValue) {
      return Scaffold(
        body: SafeArea(
          child: AppErrorState(
            message: 'Could not load semesters: ${semestersAsync.error}',
          ),
        ),
      );
    }
    final semesters = semestersAsync.value ?? const <SemesterListItem>[];
    SemesterListItem? current;
    for (final s in semesters) {
      if (s.semester.id == selectedId) {
        current = s;
        break;
      }
    }
    final isNewUser = current == null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              decoration: BoxDecoration(
                color: context.palette.card,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BrandLogo.wordmark(height: 28),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Search',
                        onPressed: () => context.go('/search'),
                        icon: const Icon(Icons.search),
                      ),
                      const SizedBox(width: 4),
                      _ProfileAvatar(
                        profilePath: profile?.avatarPath,
                        name: displayName,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isNewUser ? 'Welcome,' : 'Welcome back,',
                    style: textTheme.bodyMedium?.copyWith(
                      color: context.palette.mutedText,
                    ),
                  ),
                  Text(
                    displayName,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.palette.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  _SemesterPill(
                    isNewUser: isNewUser,
                    current: current,
                    onTap: () => showSemesterChooser(context),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: isNewUser
                    ? const _FirstSemesterCard()
                    : const _ThisSemesterSection(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _DueSoonSection(isNewUser: isNewUser),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _UpcomingEventsSection(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profilePath, required this.name});

  final String? profilePath;
  final String name;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/profile'),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: context.palette.accent,
        foregroundColor: context.palette.onAccent,
        foregroundImage: profilePath == null || profilePath!.isEmpty
            ? null
            : FileImage(File(profilePath!)),
        child: Text(
          name.isEmpty ? 'S' : name[0].toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
    );
  }
}

class _SemesterPill extends StatelessWidget {
  const _SemesterPill({
    required this.isNewUser,
    required this.current,
    required this.onTap,
  });

  final bool isNewUser;
  final SemesterListItem? current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = this.current;
    final (bg, fg, label) = isNewUser || current == null
        ? (
            context.palette.deadlineBg,
            context.palette.deadlineText,
            'No semester yet',
          )
        : (
            context.palette.accent.withValues(alpha: 0.12),
            context.palette.accentText,
            '${semesterLabel(current.semester.term)} - SY '
                '${current.semester.schoolYear}',
          );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down, color: fg, size: 18),
          ],
        ),
      ),
    );
  }
}

class _DueSoonSection extends ConsumerWidget {
  const _DueSoonSection({required this.isNewUser});

  final bool isNewUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueAsync = ref.watch(dueSoonProvider);
    final due = dueAsync.value ?? const <UpcomingActivity>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Due very soon',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/activities?filter=due'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (dueAsync.isLoading && !dueAsync.hasValue)
          const SizedBox(
            height: 96,
            child: AppLoadingState(message: 'Loading deadlines...'),
          )
        else if (dueAsync.hasError && !dueAsync.hasValue)
          SizedBox(
            height: 112,
            child: AppErrorState(
              message: 'Could not load deadlines: ${dueAsync.error}',
            ),
          )
        else if (due.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(color: context.palette.cardBorder),
            ),
            child: Text(
              isNewUser
                  ? 'No deadlines. Add a semester first.'
                  : 'Nothing due soon.',
              style: TextStyle(color: context.palette.mutedText),
            ),
          )
        else
          for (final (index, item) in due.indexed) ...[
            if (index > 0) const SizedBox(height: 10),
            _DueCard(item: item),
          ],
      ],
    );
  }
}

class _DueCard extends StatelessWidget {
  const _DueCard({required this.item});

  final UpcomingActivity item;

  @override
  Widget build(BuildContext context) {
    final overdue = isOverdue(item.activity.deadline);
    final dueColor = overdue
        ? context.palette.overdue
        : context.palette.deadlineText;

    return AppCard(
      onTap: () => context.push('/activities/${item.activity.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.activity.title,
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
              ],
            ),
          ),
          Text(
            dueLabel(item.activity.deadline ?? DateTime.now()),
            style: TextStyle(
              color: dueColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingEventsSection extends ConsumerWidget {
  const _UpcomingEventsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingCalendarEventsProvider);
    final events = eventsAsync.value ?? const <CalendarEvent>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Upcoming events',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/calendar'),
              child: const Text('Calendar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (eventsAsync.isLoading && !eventsAsync.hasValue)
          const SizedBox(
            height: 88,
            child: AppLoadingState(message: 'Loading events...'),
          )
        else if (eventsAsync.hasError && !eventsAsync.hasValue)
          SizedBox(
            height: 96,
            child: AppErrorState(
              message: 'Could not load events: ${eventsAsync.error}',
            ),
          )
        else if (events.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(color: context.palette.cardBorder),
            ),
            child: Text(
              'No upcoming events.',
              style: TextStyle(color: context.palette.mutedText),
            ),
          )
        else
          for (final (index, event) in events.indexed) ...[
            if (index > 0) const SizedBox(height: 10),
            _UpcomingEventCard(event: event),
          ],
      ],
    );
  }
}

class _UpcomingEventCard extends StatelessWidget {
  const _UpcomingEventCard({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.go('/calendar'),
      padding: const EdgeInsets.all(14),
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
                  DateFormat('EEE, MMM d · h:mm a').format(event.startsAt),
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Status chip colors for the legend (independent of the accent).
List<(String, String, Color)> _statusLegend(AppPalette palette) => [
  ('draft', 'Draft', palette.draftText),
  ('in_progress', 'In progress', palette.inProgressText),
  ('final', 'Final', palette.finalText),
  ('submitted', 'Submitted', palette.submittedText),
];

/// This-semester progress: a segmented bar and per-status counts.
class _ThisSemesterSection extends ConsumerWidget {
  const _ThisSemesterSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(statusCountsProvider);
    final counts = countsAsync.value ?? const <String, int>{};
    final total = counts.values.fold(0, (sum, n) => sum + n);
    final legend = _statusLegend(context.palette);

    return AppCard(
      onTap: () => context.go('/activities'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'This semester',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Text(
                total == 1 ? '1 activity' : '$total activities',
                style: TextStyle(
                  color: context.palette.mutedText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (countsAsync.isLoading && !countsAsync.hasValue)
            const LinearProgressIndicator()
          else if (countsAsync.hasError && !countsAsync.hasValue)
            Text(
              'Could not load activity progress: ${countsAsync.error}',
              style: TextStyle(color: context.palette.overdue),
            )
          else
            _SegmentedBar(counts: counts),
          const SizedBox(height: 12),
          if (!countsAsync.hasError)
            Row(
              children: [
                for (final (status, label, color) in legend) ...[
                  if (status != 'draft') const SizedBox(width: 6),
                  Expanded(
                    child: _LegendEntry(
                      label: label,
                      color: color,
                      count: counts[status] ?? 0,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final segments = _statusLegend(context.palette)
        .map((entry) => (entry.$3, counts[entry.$1] ?? 0))
        .where((segment) => segment.$2 > 0)
        .toList();

    if (segments.isEmpty) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: context.palette.draftBg,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            for (final (color, count) in segments)
              Expanded(
                flex: count,
                child: Container(color: color),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.label,
    required this.color,
    required this.count,
  });

  final String label;
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.mutedText,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const SizedBox(width: 12),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: context.palette.text,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FirstSemesterCard extends StatelessWidget {
  const _FirstSemesterCard();

  @override
  Widget build(BuildContext context) {
    return DashedCard(
      onTap: () => showSemesterChooser(context),
      borderColor: context.palette.accent.withValues(alpha: 0.6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        width: double.infinity,
        child: Column(
          children: [
            Icon(Icons.add, color: context.palette.accent),
            const SizedBox(height: 6),
            Text(
              'Add your first semester',
              style: TextStyle(
                color: context.palette.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Group your subjects by term',
              style: TextStyle(color: context.palette.mutedText, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
