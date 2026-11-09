import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/features/cloud/backup_status_provider.dart';
import 'package:subtrack/features/edit/edit_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';

/// Bottom navigation shell for Cloud, Subjects, Home, Calendar, and Profile.
class ScaffoldWithNav extends ConsumerWidget {
  const ScaffoldWithNav({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Once per app start, drop edit sessions whose working copy vanished.
    ref.watch(editSessionCleanupProvider);
    final hasSemester = ref.watch(selectedSemesterProvider) != null;
    final backupPending = ref.watch(localBackupPendingProvider);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (backupPending)
            Material(
              color: context.palette.deadlineBg,
              child: InkWell(
                onTap: () => context.go('/cloud'),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          color: context.palette.deadlineText,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Recent changes haven’t been backed up',
                            style: TextStyle(
                              color: context.palette.deadlineText,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          'Back up',
                          style: TextStyle(
                            color: context.palette.deadlineText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              if (!hasSemester && (index == 1 || index == 3)) return;
              _goBranch(index);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.cloud_outlined),
                selectedIcon: Icon(Icons.cloud),
                label: 'Cloud',
              ),
              NavigationDestination(
                icon: Opacity(
                  opacity: hasSemester ? 1 : 0.4,
                  child: const Icon(Icons.menu_book_outlined),
                ),
                selectedIcon: Opacity(
                  opacity: hasSemester ? 1 : 0.4,
                  child: const Icon(Icons.menu_book),
                ),
                label: 'Subjects',
              ),
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Opacity(
                  opacity: hasSemester ? 1 : 0.4,
                  child: const Icon(Icons.calendar_month_outlined),
                ),
                selectedIcon: Opacity(
                  opacity: hasSemester ? 1 : 0.4,
                  child: const Icon(Icons.calendar_month),
                ),
                label: 'Calendar',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A quick-access tile on the Home dashboard (icons for Semesters,
/// Subjects, Activities, Calendar). Highlighted with a ring and the
/// "Start here" label in the new-user state.
class QuickAccessTile extends StatelessWidget {
  const QuickAccessTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: context.palette.card,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      border: Border.all(
        color: highlighted
            ? context.palette.accent
            : context.palette.cardBorder,
        width: highlighted ? 2 : 1,
      ),
    );

    Widget tile = Container(
      decoration: decoration,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Column(
        children: [
          Icon(
            icon,
            color: highlighted ? context.palette.accent : context.palette.text,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.palette.text),
          ),
          if (highlighted) ...[
            const SizedBox(height: 2),
            Text(
              'Start here',
              style: TextStyle(fontSize: 11, color: context.palette.accent),
            ),
          ],
        ],
      ),
    );

    if (!enabled) {
      tile = Opacity(opacity: 0.45, child: tile);
      return IgnorePointer(child: tile);
    }
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: tile,
      ),
    );
  }
}
