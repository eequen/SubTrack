import 'package:flutter/material.dart';
import 'package:subtrack/app/router.dart';
import 'package:subtrack/app/theme.dart';

class SubTrackApp extends StatelessWidget {
  const SubTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SubTrack',
      theme: AppTheme.light(),
      routerConfig: buildRouter(),
    );
  }
}
