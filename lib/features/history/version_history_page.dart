import 'package:flutter/material.dart';
import 'package:subtrack/shared/stub_body.dart';

class VersionHistoryPage extends StatelessWidget {
  const VersionHistoryPage({required this.fileId, super.key});

  final String fileId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StubBody(title: 'Version history', subtitle: fileId),
    );
  }
}
