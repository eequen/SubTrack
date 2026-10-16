import 'package:flutter/material.dart';
import 'package:subtrack/shared/stub_body.dart';

class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StubBody(title: 'Activities', subtitle: subjectId),
    );
  }
}
