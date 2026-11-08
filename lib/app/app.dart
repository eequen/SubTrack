import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/profile/profile_providers.dart';

class SubTrackApp extends ConsumerWidget {
  const SubTrackApp({super.key});

  static ThemeMode _themeMode(String? stored) {
    switch (stored) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Theme and accent come from the signed-in account's profile row, so a
    // change applies immediately and survives a restart (AGENTS.md 5A).
    // Signed out, the defaults (system, indigo) apply.
    final profile = ref.watch(profileProvider).value;
    final accent = accentByKey(profile?.accentKey);
    return MaterialApp.router(
      title: 'SubTrack',
      theme: AppTheme.light(accent.key),
      darkTheme: AppTheme.dark(accent.key),
      themeMode: _themeMode(profile?.themeMode),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
