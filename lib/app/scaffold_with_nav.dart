import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/features/activities/activity_dialog.dart';
import 'package:subtrack/features/activities/activity_providers.dart';
import 'package:subtrack/features/edit/edit_providers.dart';
import 'package:subtrack/features/files/file_providers.dart';
import 'package:subtrack/features/reminders/reminder_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/features/subjects/subject_dialog.dart';
import 'package:subtrack/features/subjects/subject_providers.dart';
import 'package:subtrack/shared/ui_components.dart';

/// Bottom navigation shell for Home, Subjects, Calendar, and Profile.
class ScaffoldWithNav extends ConsumerWidget {
  const ScaffoldWithNav({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final uri = GoRouterState.of(context).uri;
    final path = uri.path;
    final parts = uri.pathSegments;
    final semesterId = ref.read(selectedSemesterProvider);

    if (path == '/home' || path == '/subjects') {
      if (semesterId == null) {
        context.push('/semesters');
      } else {
        await _createSubject(context, ref, semesterId);
      }
      return;
    }

    if (parts.length == 3 &&
        parts[0] == 'subjects' &&
        parts[2] == 'activities') {
      await _createActivity(context, ref, int.tryParse(parts[1]) ?? -1);
      return;
    }

    if (path == '/activities') {
      final subjectId = await _chooseSubject(context, ref);
      if (subjectId != null && context.mounted) {
        await _createActivity(context, ref, subjectId);
      }
      return;
    }

    if (parts.length == 2 && parts[0] == 'activities') {
      await _addFile(context, ref, int.tryParse(parts[1]) ?? -1);
      return;
    }

    final action = await _showAddChoices(context);
    if (!context.mounted) return;
    if (action == 'subject') {
      if (semesterId == null) {
        context.push('/semesters');
      } else {
        await _createSubject(context, ref, semesterId);
      }
    } else if (action == 'activity') {
      final subjectId = await _chooseSubject(context, ref);
      if (subjectId != null && context.mounted) {
        await _createActivity(context, ref, subjectId);
      }
    }
  }

  Future<void> _createSubject(
    BuildContext context,
    WidgetRef ref,
    int semesterId,
  ) async {
    final result = await showNewSubjectDialog(context);
    if (result == null || !context.mounted) return;
    try {
      await ref
          .read(subjectRepoProvider)
          .create(
            semesterId: semesterId,
            name: result.name,
            color: result.color,
            icon: result.icon,
          );
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, 'Could not create subject: $error');
    }
  }

  Future<void> _createActivity(
    BuildContext context,
    WidgetRef ref,
    int subjectId,
  ) async {
    if (subjectId <= 0) return;
    final result = await showNewActivityDialog(context);
    if (result == null || !context.mounted) return;
    try {
      await ref
          .read(activityRepoProvider)
          .create(
            subjectId: subjectId,
            title: result.title,
            notes: result.notes,
            deadline: result.deadline,
            status: result.status,
          );
      final reminders = ref.read(reminderServiceProvider);
      if (result.deadline?.isAfter(DateTime.now()) == true) {
        await reminders.requestPermission();
      }
      await reminders.syncAll();
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, 'Could not create activity: $error');
    }
  }

  Future<int?> _chooseSubject(BuildContext context, WidgetRef ref) async {
    final semesterId = ref.read(selectedSemesterProvider);
    if (semesterId == null) {
      _showMessage(context, 'Choose a semester first.');
      return null;
    }

    try {
      final subjects = await ref.read(subjectsProvider(semesterId).future);
      if (!context.mounted) return null;
      if (subjects.isEmpty) {
        _showMessage(context, 'Create a subject before adding an activity.');
        return null;
      }
      return await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SheetScaffold(
          title: 'Choose a subject',
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.55,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: subjects.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final subject = subjects[index].subject;
                return AppCard(
                  padding: EdgeInsets.zero,
                  onTap: () => Navigator.of(context).pop(subject.id),
                  child: ListTile(
                    title: Text(subject.name),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: context.palette.mutedText,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return null;
      _showMessage(context, 'Could not load subjects: $error');
      return null;
    }
  }

  Future<void> _addFile(
    BuildContext context,
    WidgetRef ref,
    int activityId,
  ) async {
    if (activityId <= 0) return;
    try {
      final picked = await ref.read(filePickerProvider)(context);
      if (picked == null || !context.mounted) return;
      await ref
          .read(fileRepoProvider)
          .upload(
            activityId: activityId,
            bytes: picked.bytes,
            displayName: picked.name,
          );
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, 'Could not add file: $error');
    }
  }

  Future<String?> _showAddChoices(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SheetScaffold(
        title: 'Add to SubTrack',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.menu_book_outlined,
                color: context.palette.accent,
              ),
              title: const Text('New subject'),
              onTap: () => Navigator.of(context).pop('subject'),
            ),
            ListTile(
              leading: Icon(
                Icons.assignment_outlined,
                color: context.palette.accent,
              ),
              title: const Text('New activity'),
              onTap: () => Navigator.of(context).pop('activity'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Once per app start, drop edit sessions whose working copy vanished.
    ref.watch(editSessionCleanupProvider);
    final hasSemester = ref.watch(selectedSemesterProvider) != null;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SizedBox(
        height: 84,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (index) {
                  if (!hasSemester && (index == 1 || index == 2)) return;
                  _goBranch(index);
                },
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home),
                    label: 'Home',
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
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline),
                    selectedIcon: const Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
            Positioned(
              top: -8,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: FloatingActionButton(
                    heroTag: 'navigation-add',
                    tooltip: 'Add',
                    onPressed: () => _add(context, ref),
                    backgroundColor: context.palette.accent,
                    foregroundColor: context.palette.onAccent,
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.add, size: 36),
                  ),
                ),
              ),
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
