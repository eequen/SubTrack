import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/app/theme.dart';

/// Label for a stored status value (draft, in_progress, final, submitted).
String statusLabel(String status) {
  switch (status) {
    case 'in_progress':
      return 'In progress';
    case 'final':
      return 'Final';
    case 'submitted':
      return 'Submitted';
    default:
      return 'Draft';
  }
}

/// (text, background) pair for a status, from AGENTS.md section 14. The
/// chip colors are independent of the accent but flip for dark mode.
(Color, Color) statusColors(String status, AppPalette palette) {
  switch (status) {
    case 'in_progress':
      return (palette.inProgressText, palette.inProgressBg);
    case 'final':
      return (palette.finalText, palette.finalBg);
    case 'submitted':
      return (palette.submittedText, palette.submittedBg);
    default:
      return (palette.draftText, palette.draftBg);
  }
}

/// Rubber-stamp style chip used across the editorial cards.
class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.text,
    required this.textColor,
    required this.background,
  });

  final String text;
  final Color textColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: textColor.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: textColor, letterSpacing: 0.45, height: 1.1),
      ),
    );
  }
}

/// Status stamp used on activity cards (mockup 5).
class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (text, bg) = statusColors(status, context.palette);
    return _Stamp(text: statusLabel(status), textColor: text, background: bg);
  }
}

/// Green "Current" stamp (mockups 3 and 7) marking the latest version
/// or the latest semester.
class CurrentChip extends StatelessWidget {
  const CurrentChip({super.key});

  @override
  Widget build(BuildContext context) {
    return _Stamp(
      text: 'Current',
      textColor: context.palette.finalText,
      background: context.palette.finalBg,
    );
  }
}

/// Blue "Editing" stamp for a file with an unfinished external edit
/// (AGENTS.md Phase 5B).
class EditingChip extends StatelessWidget {
  const EditingChip({super.key});

  @override
  Widget build(BuildContext context) {
    return _Stamp(
      text: 'Editing',
      textColor: context.palette.inProgressText,
      background: context.palette.inProgressBg,
    );
  }
}

/// Amber deadline stamp (mockups 4, 5, 6).
class DeadlineChip extends StatelessWidget {
  const DeadlineChip({required this.deadline, super.key});

  final DateTime deadline;

  static final _format = DateFormat('MMM d');

  @override
  Widget build(BuildContext context) {
    return _Stamp(
      text: _format.format(deadline),
      textColor: context.palette.deadlineText,
      background: context.palette.deadlineBg,
    );
  }
}
