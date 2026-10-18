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

/// (text, background) pair for a status, from AGENTS.md section 14.
(Color, Color) statusColors(String status) {
  switch (status) {
    case 'in_progress':
      return (AppColors.inProgressText, AppColors.inProgressBg);
    case 'final':
      return (AppColors.finalText, AppColors.finalBg);
    case 'submitted':
      return (AppColors.submittedText, AppColors.submittedBg);
    default:
      return (AppColors.draftText, AppColors.draftBg);
  }
}

/// Status pill used on activity cards (mockup 5).
class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (text, bg) = statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(color: text, fontSize: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.finalBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Current',
        style: TextStyle(color: AppColors.finalText, fontSize: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.deadlineBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _format.format(deadline),
        style: const TextStyle(color: AppColors.deadlineText, fontSize: 12),
      ),
    );
  }
}
