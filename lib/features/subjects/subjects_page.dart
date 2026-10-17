import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/semester_repo.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/shared/stub_body.dart';

/// Header follows mockup 4; the subject cards arrive in the next task.
class SubjectsPage extends ConsumerWidget {
  const SubjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedSemesterProvider);
    final repo = ref.watch(semesterRepoProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: selectedId == null
                        ? const Text('My Subjects')
                        : _SemesterHeader(repo: repo, semesterId: selectedId),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/semesters'),
                    child: const Text('Change'),
                  ),
                ],
              ),
              const Expanded(child: StubBody(title: 'My Subjects')),
            ],
          ),
        ),
      ),
    );
  }
}

class _SemesterHeader extends StatelessWidget {
  const _SemesterHeader({required this.repo, required this.semesterId});

  final SemesterRepo repo;
  final int semesterId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Semester?>(
      stream: repo.watchById(semesterId),
      builder: (context, snapshot) {
        final s = snapshot.data;
        return Text(
          s == null
              ? 'My Subjects'
              : '${semesterLabel(s.term)} - SY ${s.schoolYear}\nMy Subjects',
        );
      },
    );
  }
}
