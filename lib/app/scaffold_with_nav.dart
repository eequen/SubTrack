import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/features/edit/edit_providers.dart';
import 'package:subtrack/shared/editorial.dart';

/// Bottom navigation shell: Search, Home (middle), Profile. Visible on the
/// home branch screens, Search, Profile, and Cloud backup (AGENTS.md
/// section 14). Hidden on login, signup, semesters, and commit screens,
/// which live outside the shell.
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
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.background,
          border: Border(top: BorderSide(color: context.palette.cardBorder)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _goBranch,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
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
    this.number,
    this.highlighted = false,
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? number;
  final bool highlighted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final ink = highlighted ? palette.accentText : palette.text;

    Widget tile = Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: highlighted ? palette.accent : palette.cardBorder,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      child: Row(
        children: [
          if (number != null) ...[
            IndexStamp(
              number!,
              size: 26,
              color: highlighted ? palette.accentText : palette.mutedText,
            ),
            const SizedBox(width: 9),
          ],
          Icon(icon, size: 20, color: ink),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(color: ink),
                ),
                if (highlighted)
                  Text(
                    'Start here',
                    style: textTheme.labelSmall?.copyWith(
                      color: palette.accentText,
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!enabled) {
      tile = Opacity(opacity: 0.42, child: tile);
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
