import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/menu_sheet.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/features/cloud/backup_status_provider.dart';
import 'package:subtrack/features/edit/edit_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';

/// Bottom navigation for Home, the centre Menu button, and Cloud.
///
/// The menu button is an action rather than a fifth destination: it opens a
/// sheet with Subjects, Calendar, Profile, Flashcards, and File manager.
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
    final index = navigationShell.currentIndex;
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
          _BottomBar(
            currentIndex: index,
            onHome: () => _goBranch(0),
            onCloud: () => _goBranch(2),
            onMenu: () => showAppMenu(context, hasSemester: hasSemester),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentIndex,
    required this.onHome,
    required this.onCloud,
    required this.onMenu,
  });

  final int currentIndex;
  final VoidCallback onHome;
  final VoidCallback onCloud;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.cardBorder)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 86,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _NavButton(
                  key: const Key('nav-home'),
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Home',
                  selected: currentIndex == 0,
                  onTap: onHome,
                ),
              ),
              SizedBox(
                width: 104,
                child: _MenuButton(
                  key: const Key('nav-menu'),
                  selected: currentIndex == 1,
                  onTap: onMenu,
                ),
              ),
              Expanded(
                child: _NavButton(
                  key: const Key('nav-cloud'),
                  icon: Icons.cloud_outlined,
                  selectedIcon: Icons.cloud_rounded,
                  label: 'Cloud',
                  selected: currentIndex == 2,
                  onTap: onCloud,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected ? palette.accentText : palette.mutedText;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 30,
                decoration: BoxDecoration(
                  color: selected
                      ? palette.accent.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  color: color,
                  size: 23,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.selected, required this.onTap, super.key});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Menu',
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? palette.accentText.withValues(alpha: 0.65)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Material(
                color: palette.accent,
                elevation: 5,
                shadowColor: palette.accent.withValues(alpha: 0.35),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Icon(
                    Icons.menu_rounded,
                    color: palette.onAccent,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Menu',
              style: TextStyle(
                color: selected ? palette.accentText : palette.mutedText,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
