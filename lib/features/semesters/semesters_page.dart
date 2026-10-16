import 'package:flutter/material.dart';
import 'package:subtrack/shared/stub_body.dart';

class SemestersPage extends StatelessWidget {
  const SemestersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: StubBody(title: 'Choose semester'));
  }
}
