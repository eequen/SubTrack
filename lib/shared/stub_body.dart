import 'package:flutter/material.dart';

/// Thin placeholder body used by the Phase 1 route stubs.
/// Real UI arrives in Phase 2/3; each stub shows its route title so the
/// router and tab shell can be verified now.
class StubBody extends StatelessWidget {
  const StubBody({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!),
            ],
          ],
        ),
      ),
    );
  }
}
