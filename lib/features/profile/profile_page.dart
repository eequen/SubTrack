import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/dashboard/home_providers.dart';
import 'package:subtrack/features/profile/profile_providers.dart';

/// Screen 15 from AGENTS.md section 14: Profile and settings.
///
/// This first slice carries the profile card and the Cloud backup row;
/// the appearance, notification, and account sections land with their
/// features in the following tasks (theme switching, notifications,
/// password change, sign out, delete cloud data). Account actions live
/// only here, never on other screens.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);
    final displayName = ref.watch(displayNameProvider);
    final profile = ref.watch(profileProvider).value;
    final username = profile?.username.isNotEmpty == true
        ? profile!.username
        : (user?.username.isNotEmpty == true ? user!.username : user?.email);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          children: [
            const Text(
              'Profile',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.accent,
                    foregroundImage:
                        profile == null ||
                            profile.avatarPath == null ||
                            profile.avatarPath!.isEmpty
                        ? null
                        : FileImage(File(profile.avatarPath!)),
                    child: Text(
                      displayName.isEmpty ? 'S' : displayName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@$username',
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('Cloud backup and restore'),
            const SizedBox(height: 8),
            Card(
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                side: const BorderSide(color: AppColors.cardBorder),
              ),
              child: ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: const Text('Cloud backup and restore'),
                subtitle: const Text('Manual backup, storage, restore'),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.mutedText,
                ),
                onTap: () => context.push('/cloud'),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SubTrack version 1.0.0',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
