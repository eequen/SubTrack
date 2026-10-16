import 'package:flutter/material.dart';
import 'package:subtrack/shared/stub_body.dart';

class SubjectsPage extends StatelessWidget {
  const SubjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: StubBody(title: 'My Subjects'));
  }
}
