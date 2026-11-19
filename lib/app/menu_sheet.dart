import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/shared/ui_components.dart';

/// The semester-style sheet behind the centre navigation button. The menu
/// items are the five places that are not Home or Cloud.
Future<void> showAppMenu(BuildContext context, {required bool hasSemester}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _AppMenuSheet(
      hasSemester: hasSemester,
      onSelected: (route) {
        Navigator.of(sheetContext).pop();
        if (!hasSemester) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Choose a semester first.')),
          );
          context.go('/home');
          return;
        }
        context.go(route);
      },
    ),
  );
}

class _AppMenuSheet extends StatelessWidget {
  const _AppMenuSheet({required this.hasSemester, required this.onSelected});

  final bool hasSemester;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Menu',
      trailing: IconButton(
        tooltip: 'Close',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hasSemester
                ? 'Open a place in your semester.'
                : 'Choose a semester from Home to unlock your subjects.',
            style: TextStyle(color: context.palette.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _MenuItem(
            icon: Icons.menu_book_outlined,
            title: 'Subjects',
            subtitle: 'Subjects, activities, and files',
            enabled: hasSemester,
            onTap: () => onSelected('/subjects'),
          ),
          _MenuItem(
            icon: Icons.calendar_month_outlined,
            title: 'Calendar',
            subtitle: 'Deadlines and local events',
            enabled: hasSemester,
            onTap: () => onSelected('/calendar'),
          ),
          _MenuItem(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'Appearance, account, and backup',
            enabled: true,
            onTap: () => onSelected('/profile'),
          ),
          _MenuItem(
            icon: Icons.style_outlined,
            title: 'Flashcards',
            subtitle: 'Local decks and AI import',
            enabled: hasSemester,
            onTap: () => onSelected('/flashcards'),
          ),
          _MenuItem(
            icon: Icons.folder_copy_outlined,
            title: 'File manager',
            subtitle: 'Lessons, flashcards, and activities',
            enabled: hasSemester,
            onTap: () => onSelected('/file-manager'),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: palette.card,
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: palette.accentText),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          enabled ? subtitle : 'Choose a semester first',
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: enabled ? palette.mutedText : palette.cardBorder,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
