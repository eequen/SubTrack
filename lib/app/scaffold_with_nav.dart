import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';

/// Bottom navigation shell: Search, Home (middle), Profile. Visible on the
/// home branch screens, Search, Profile, and Cloud backup (AGENTS.md
/// section 14). Hidden on login, signup, semesters, and commit screens,
/// which live outside the shell.
class ScaffoldWithNav extends StatelessWidget {
  const ScaffoldWithNav({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
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
