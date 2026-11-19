import 'package:flutter/material.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/repositories/activity_repo.dart';
import 'package:subtrack/shared/chips.dart';
import 'package:subtrack/shared/ui_components.dart';

Future<String?> showStatusSheet(
  BuildContext context, {
  required String currentStatus,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatusSheet(currentStatus: currentStatus),
  );
}

class StatusSheet extends StatelessWidget {
  const StatusSheet({required this.currentStatus, super.key});

  final String currentStatus;

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Set status',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final status in ActivityRepo.statuses)
            ListTile(
              title: StatusChip(status: status),
              trailing: status == currentStatus
                  ? Icon(Icons.check_circle, color: context.palette.accent)
                  : null,
              onTap: () => Navigator.of(context).pop(status),
            ),
        ],
      ),
    );
  }
}
