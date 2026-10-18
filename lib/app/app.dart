import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/features/auth/auth_providers.dart';

class SubTrackApp extends ConsumerWidget {
  const SubTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SubTrack',
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
