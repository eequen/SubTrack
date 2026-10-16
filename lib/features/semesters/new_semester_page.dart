import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';

const _terms = ['first', 'second', 'summer'];
final _dateFormat = DateFormat('MMM d, yyyy');

/// Screen 3 from AGENTS.md section 14: New semester.
class NewSemesterPage extends ConsumerStatefulWidget {
  const NewSemesterPage({super.key});

  @override
  ConsumerState<NewSemesterPage> createState() => _NewSemesterPageState();
}

class _NewSemesterPageState extends ConsumerState<NewSemesterPage> {
  String _term = 'first';
  final _schoolYearController = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 120));
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _schoolYearController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(semesterRepoProvider)
          .create(
            term: _term,
            schoolYear: _schoolYearController.text,
            startDate: _start,
            endDate: _end,
          );
      await ref.read(selectedSemesterProvider.notifier).select(id);
      if (mounted) context.go('/subjects');
    } on ArgumentError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          children: [
            TextButton(
              onPressed: () => context.go('/semesters'),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text('‹ Semesters'),
              ),
            ),
            Text(
              'New semester',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Text('You will add subjects next.'),
            const SizedBox(height: 16),
            const Text('Semester'),
            DropdownButtonFormField<String>(
              initialValue: _term,
              items: _terms
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(semesterLabel(t)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _term = v ?? 'first'),
            ),
            const SizedBox(height: 16),
            const Text('School year'),
            TextField(
              controller: _schoolYearController,
              decoration: const InputDecoration(hintText: '2026-2027'),
            ),
            const SizedBox(height: 16),
            const Text('Start date'),
            OutlinedButton(
              onPressed: () => _pickDate(true),
              child: Text(_dateFormat.format(_start)),
            ),
            const SizedBox(height: 16),
            const Text('End date'),
            OutlinedButton(
              onPressed: () => _pickDate(false),
              child: Text(_dateFormat.format(_end)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy ? null : _create,
              child: Text(_busy ? 'Please wait…' : 'Create semester'),
            ),
            TextButton(
              onPressed: () => context.go('/semesters'),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
