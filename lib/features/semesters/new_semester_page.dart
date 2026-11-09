import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/features/cloud/backup_status_provider.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/shared/ui_components.dart';

const _terms = [
  SegmentOption(value: 'first', label: '1st'),
  SegmentOption(value: 'second', label: '2nd'),
  SegmentOption(value: 'summer', label: 'Summer'),
];

final _dateFormat = DateFormat('MMM d, yyyy');

/// Screen 5 from the redesign: create a semester.
class NewSemesterPage extends ConsumerStatefulWidget {
  const NewSemesterPage({super.key});

  @override
  ConsumerState<NewSemesterPage> createState() => _NewSemesterPageState();
}

class _NewSemesterPageState extends ConsumerState<NewSemesterPage> {
  String _term = 'first';
  static const int _firstYear = 2020;
  static const int _lastStartYear = 2039;
  int _startYear = DateTime.now().year;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 120));
  bool _busy = false;
  String? _error;

  String get _schoolYear => '$_startYear-${_startYear + 1}';

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
      _error = null;
    });
  }

  void _stepYear(int delta) {
    setState(() {
      _startYear = (_startYear + delta)
          .clamp(_firstYear, _lastStartYear)
          .toInt();
    });
  }

  Future<void> _create() async {
    if (!_end.isAfter(_start)) {
      setState(() => _error = 'End date must be after the start date.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(semesterRepoProvider)
          .create(
            term: _term,
            schoolYear: _schoolYear,
            startDate: _start,
            endDate: _end,
          );
      await ref.read(localBackupPendingProvider.notifier).markPending();
      await ref.read(selectedSemesterProvider.notifier).select(id);
      if (mounted) context.go('/home');
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not create semester: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _cancel() => context.go('/semesters');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = semesterLabel(_term);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back to semesters',
                  onPressed: _cancel,
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                Text(
                  'New semester',
                  style: textTheme.titleLarge?.copyWith(
                    color: context.palette.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Semester', style: textTheme.titleMedium),
            const SizedBox(height: 10),
            SegmentedSelector(
              options: _terms,
              value: _term,
              onChanged: (term) => setState(() => _term = term),
            ),
            const SizedBox(height: 22),
            Text('School year', style: textTheme.titleMedium),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous school year',
                    onPressed: _startYear > _firstYear
                        ? () => _stepYear(-1)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Expanded(
                    child: Text(
                      '${_startYear.toString()} – ${_startYear + 1}',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        color: context.palette.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next school year',
                    onPressed: _startYear < _lastStartYear
                        ? () => _stepYear(1)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('Semester dates', style: textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DateCard(
                    label: 'Start date',
                    date: _start,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateCard(
                    label: 'End date',
                    date: _end,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text('Preview', style: textTheme.titleMedium),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label · SY $_schoolYear',
                    style: textTheme.titleMedium?.copyWith(
                      color: context.palette.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_dateFormat.format(_start)} - ${_dateFormat.format(_end)}',
                    style: TextStyle(color: context.palette.mutedText),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: TextStyle(color: context.palette.overdue)),
            ],
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Create semester',
              loading: _busy,
              onPressed: _busy ? null : _create,
            ),
            const SizedBox(height: 8),
            SecondaryButton(label: 'Cancel', onPressed: _cancel),
          ],
        ),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.palette.mutedText)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, color: context.palette.accentText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dateFormat.format(date),
                  style: TextStyle(
                    color: context.palette.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
