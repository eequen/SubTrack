import 'package:flutter/material.dart';
import 'package:subtrack/shared/stub_body.dart';

class CommitPage extends StatelessWidget {
  const CommitPage({required this.fileId, super.key});

  final String fileId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StubBody(title: 'Commit new version', subtitle: fileId),
    );
  }
}
