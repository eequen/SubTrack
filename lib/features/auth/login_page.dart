import 'package:flutter/material.dart';
import 'package:subtrack/shared/stub_body.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: StubBody(
        title: 'SubTrack',
        subtitle: 'Every subject, every version, safely kept.',
      ),
    );
  }
}
