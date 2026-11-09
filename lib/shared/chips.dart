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

/// Status pill used on activity cards (mockup 5).
class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, this.onTap, super.key});

  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (text, bg) = statusColors(status, context.palette);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        statusLabel(status),
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: text, fontWeight: FontWeight.w700),
      ),
    );
    if (onTap == null) return chip;
    return Semantics(
      button: true,
      label: 'Set status: ${statusLabel(status)}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(child: chip),
          ),
        ),
      ),
    );
  }
}

/// Green "Current" pill (mockups 3 and 7) marking the latest version
/// or the latest semester.
class CurrentChip extends StatelessWidget {
  const CurrentChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.palette.finalBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        'Current',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.palette.finalText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Blue-violet "Editing" pill for a file with an unfinished external edit
/// (AGENTS.md Phase 5B).
class EditingChip extends StatelessWidget {
  const EditingChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.palette.inProgressBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        'Editing',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.palette.inProgressText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Amber deadline pill (mockups 4, 5, 6).
class DeadlineChip extends StatelessWidget {
  const DeadlineChip({required this.deadline, super.key});

  final DateTime deadline;

  static final _format = DateFormat('MMM d');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.palette.deadlineBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        _format.format(deadline),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.palette.deadlineText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
