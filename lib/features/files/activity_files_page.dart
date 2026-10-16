import 'package:flutter/material.dart';
import 'package:subtrack/shared/stub_body.dart';

class ActivityFilesPage extends StatelessWidget {
  const ActivityFilesPage({required this.activityId, super.key});

  final String activityId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StubBody(title: 'Activity files', subtitle: activityId),
    );
  }
}
