import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/features/cloud/cloud_providers.dart';
import 'package:subtrack/features/dashboard/home_providers.dart';
import 'package:subtrack/features/profile/profile_providers.dart';
import 'package:subtrack/features/reminders/reminder_providers.dart';

/// Screen 15 from AGENTS.md section 14: Profile and settings.
///
/// The only home for account actions (AGENTS.md constraint 13): appearance,
/// notifications, the cloud row, change password, sign out, and delete
/// cloud data.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);
    final profile = ref.watch(profileProvider).value;
    final displayName = ref.watch(displayNameProvider);
    final username = profile == null || profile.username.isEmpty
        ? (user?.username.isNotEmpty == true ? user!.username : user?.email)
        : profile.username;
    final themeMode = profile?.themeMode ?? 'system';
    final accentKey = profile?.accentKey ?? accentOptions.first.key;
    final prefs = ref.watch(sharedPreferencesProvider);
    final lastRaw = prefs.getString('subtrack_last_cloud_backup');
    final lastBackup = lastRaw == null
        ? 'No backup yet · manual only'
        : 'Last backup: '
              '${DateFormat('MMM d, y h:mm a').format(DateTime.parse(lastRaw).toLocal())}';

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
            _ProfileCard(
              displayName: displayName,
              username: username ?? '',
              avatarPath: profile?.avatarPath,
              onEdit: () => context.push('/profile/edit'),
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Appearance'),
            _SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Theme',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (mode, label) in const [
                            ('light', 'Light'),
                            ('dark', 'Dark'),
                            ('system', 'System'),
                          ])
                            ChoiceChip(
                              key: ValueKey('theme-$mode'),
                              label: Text(label),
                              selected: themeMode == mode,
                              onSelected: (_) =>
                                  _update(ref, context, themeMode: mode),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Accent',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          for (final option in accentOptions)
                            _AccentDot(
                              option: option,
                              selected: accentKey == option.key,
                              onTap: () =>
                                  _update(ref, context, accentKey: option.key),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Buttons, links, the active tab, and your avatar.',
                        style: TextStyle(
                          color: context.palette.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Notifications'),
            _SettingsCard(
              children: [
                SwitchListTile(
                  key: const ValueKey('toggle-deadlines'),
                  title: const Text('Deadline reminders'),
                  subtitle: const Text('A reminder when an activity is due'),
                  value: profile?.remindDeadlines ?? true,
                  onChanged: (value) => _setRemindDeadlines(
                    context,
                    ref,
                    weeklyEnabled: profile?.remindBackupWeekly ?? true,
                    value: value,
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  key: const ValueKey('toggle-backup'),
                  title: const Text('Weekly backup reminder'),
                  subtitle: const Text('A weekly nudge to back up your work'),
                  value: profile?.remindBackupWeekly ?? true,
                  onChanged: (value) => _setWeeklyReminder(ref, context, value),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Cloud backup and restore'),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('Cloud backup and restore'),
                  subtitle: Text(lastBackup),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.palette.mutedText,
                  ),
                  onTap: () => context.push('/cloud'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Account'),
            _SettingsCard(
              children: [
                ListTile(
                  key: const ValueKey('change-password'),
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change password'),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.palette.mutedText,
                  ),
                  onTap: () => _changePassword(context),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('sign-out'),
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: () => _signOut(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('delete-cloud-data'),
                  leading: Icon(
                    Icons.delete_outline,
                    color: context.palette.overdue,
                  ),
                  title: Text(
                    'Delete cloud data',
                    style: TextStyle(color: context.palette.overdue),
                  ),
                  onTap: () => _deleteCloudData(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'SubTrack version 1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.palette.mutedText, fontSize: 12),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Saves one appearance/notification field; the profile stream re-emits,
  /// so the theme and switches update immediately.
  Future<void> _update(
    WidgetRef ref,
    BuildContext context, {
    String? themeMode,
    String? accentKey,
    bool? remindDeadlines,
    bool? remindBackupWeekly,
  }) async {
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    try {
      await ref
          .read(profileRepoProvider)
          .update(
            user.id,
            themeMode: themeMode,
            accentKey: accentKey,
            remindDeadlines: remindDeadlines,
            remindBackupWeekly: remindBackupWeekly,
          );
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not save: $e');
    }
  }

  Future<void> _setRemindDeadlines(
    BuildContext context,
    WidgetRef ref, {
    required bool weeklyEnabled,
    required bool value,
  }) async {
    await _update(ref, context, remindDeadlines: value);
    final reminders = ref.read(reminderServiceProvider);
    if (value) {
      await reminders.requestPermission();
      await reminders.syncAll();
    } else {
      await reminders.clear();
    }
    // Both calls drop every scheduled notification; put the weekly nudge
    // back when it is still enabled.
    if (weeklyEnabled) {
      await reminders.syncWeeklyBackupReminder(true);
    }
  }

  Future<void> _setWeeklyReminder(
    WidgetRef ref,
    BuildContext context,
    bool value,
  ) async {
    await _update(ref, context, remindBackupWeekly: value);
    if (value) {
      await ref.read(reminderServiceProvider).requestPermission();
    }
    await ref.read(reminderServiceProvider).syncWeeklyBackupReminder(value);
  }

  Future<void> _changePassword(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && context.mounted) {
      _snack(context, 'Password changed.');
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your work stays on this phone. Log in again anytime — cloud '
          'backup is manual.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('sign-out-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(authControllerProvider.notifier).signOut();
  }

  Future<void> _deleteCloudData(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authControllerProvider);
    final profile = ref.read(profileProvider).value;
    final username = profile != null && profile.username.isNotEmpty
        ? profile.username
        : (user?.email ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteCloudDataDialog(username: username),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(cloudRepoProvider).deleteAllCloudData();
      await ref
          .read(sharedPreferencesProvider)
          .remove('subtrack_last_cloud_backup');
      if (context.mounted) _snack(context, 'Cloud data deleted.');
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not delete cloud data: $e');
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.displayName,
    required this.username,
    required this.avatarPath,
    required this.onEdit,
  });

  final String displayName;
  final String username;
  final String? avatarPath;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = avatarPath != null && avatarPath!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: context.palette.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: context.palette.accent,
            foregroundImage: hasPhoto ? FileImage(File(avatarPath!)) : null,
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
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
        ],
      ),
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AccentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _accentLabel(option.key),
      child: InkWell(
        key: ValueKey('accent-${option.key}'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: option.light,
            border: Border.all(
              color: selected ? context.palette.text : Colors.transparent,
              width: 2,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}

String _accentLabel(String key) =>
    key.isEmpty ? key : key[0].toUpperCase() + key.substring(1);

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(color: context.palette.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: context.palette.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Two password fields; validates locally, then asks the auth service.
class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _password.text;
    if (password.length < 8) {
      setState(() => _error = 'Passwords need at least 8 characters.');
      return;
    }
    if (password != _confirm.text) {
      setState(() => _error = 'The passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(newPassword: password);
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not change the password: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('new-password'),
            controller: _password,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('confirm-password'),
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: context.palette.overdue, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('change-password-submit'),
          onPressed: _busy ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Typing the username is the confirmation (AGENTS.md screen 15).
class _DeleteCloudDataDialog extends StatefulWidget {
  const _DeleteCloudDataDialog({required this.username});

  final String username;

  @override
  State<_DeleteCloudDataDialog> createState() => _DeleteCloudDataDialogState();
}

class _DeleteCloudDataDialogState extends State<_DeleteCloudDataDialog> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _matches =>
      widget.username.trim().isNotEmpty &&
      _typed.text.trim().toLowerCase() == widget.username.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete cloud data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This removes your backed-up subjects, activities, files, and '
            'versions from the cloud. Work on this phone stays.',
          ),
          const SizedBox(height: 12),
          Text(
            'Type ${widget.username} to confirm.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('delete-confirm-field'),
            controller: _typed,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: widget.username),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('delete-confirm-button'),
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
