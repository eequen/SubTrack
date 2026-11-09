import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/features/reminders/reminder_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/shared/ui_components.dart';

final _rangeFormat = DateFormat('MMM d');
final _yearFormat = DateFormat('yyyy');

String _dateRange(DateTime start, DateTime end) {
  return '${_rangeFormat.format(start)} - ${_rangeFormat.format(end)}, ${_yearFormat.format(end)}';
}

Future<void> showSemesterChooser(BuildContext context) async {
  final createNew = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SemesterChooserSheet(
      onSelected: (_) => Navigator.of(sheetContext).pop(false),
      onCreate: () => Navigator.of(sheetContext).pop(true),
      onClose: () => Navigator.of(sheetContext).pop(false),
    ),
  );
  if (createNew == true && context.mounted) {
    context.push('/semesters/new');
  }
}

/// Deep-link route for the semester chooser sheet.
class SemestersPage extends StatelessWidget {
  const SemestersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SemesterChooserSheet(),
          ),
        ),
      ),
    );
  }
}

/// Shared chooser content used both as a modal on Home and at `/semesters`.
class SemesterChooserSheet extends ConsumerStatefulWidget {
  const SemesterChooserSheet({
    this.onSelected,
    this.onCreate,
    this.onClose,
    super.key,
  });

  final ValueChanged<int>? onSelected;
  final VoidCallback? onCreate;
  final VoidCallback? onClose;

  @override
  ConsumerState<SemesterChooserSheet> createState() =>
      _SemesterChooserSheetState();
}

class _SemesterChooserSheetState extends ConsumerState<SemesterChooserSheet> {
  bool _editing = false;

  Future<void> _select(int id) async {
    await ref.read(selectedSemesterProvider.notifier).select(id);
    if (!mounted) return;
    if (widget.onSelected != null) {
      widget.onSelected!(id);
    } else {
      context.go('/home');
    }
  }

  Future<void> _delete(SemesterListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete semester?'),
        content: const Text(
          'This deletes its subjects, activities, files, and versions. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final selected = ref.read(selectedSemesterProvider);
      await ref.read(semesterRepoProvider).delete(item.semester.id);
      if (selected == item.semester.id) {
        await ref.read(selectedSemesterProvider.notifier).select(null);
      }
      await ref.read(reminderServiceProvider).syncAll();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete semester: $error')),
      );
    }
  }

  void _create() {
    if (widget.onCreate != null) {
      widget.onCreate!();
    } else {
      context.go('/semesters/new');
    }
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final semesters = ref.watch(semestersProvider);
    final selectedId = ref.watch(selectedSemesterProvider);

    return SheetScaffold(
      title: 'Choose semester',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => setState(() => _editing = !_editing),
            child: Text(_editing ? 'Done' : 'Edit'),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: _close,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      child: semesters.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Could not load semesters: $error',
            style: TextStyle(color: context.palette.overdue),
          ),
        ),
        data: (items) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  'No semesters yet. Add one to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.palette.mutedText),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.52,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final semester = item.semester;
                    final isCurrent = semester.id == selectedId;
                    return AppCard(
                      borderColor: isCurrent
                          ? context.palette.accent
                          : context.palette.cardBorder,
                      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                      onTap: _editing ? null : () => _select(semester.id),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${semesterLabel(semester.term)} · SY '
                                  '${semester.schoolYear}',
                                  style: TextStyle(
                                    color: context.palette.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_dateRange(semester.startDate, semester.endDate)}'
                                  ' · ${item.subjectCount} subjects'
                                  ' · ${item.fileCount} files',
                                  style: TextStyle(
                                    color: context.palette.mutedText,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_editing)
                            IconButton(
                              tooltip: 'Delete semester',
                              onPressed: () => _delete(item),
                              color: context.palette.overdue,
                              icon: const Icon(Icons.delete_outline),
                            )
                          else if (isCurrent)
                            Icon(
                              Icons.check_circle,
                              color: context.palette.accent,
                            )
                          else
                            Icon(
                              Icons.chevron_right,
                              color: context.palette.mutedText,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'New semester',
              onPressed: _create,
              icon: Icons.add,
            ),
          ],
        ),
      ),
    );
  }
}
