import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/flashcard_repo.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';
import 'package:subtrack/features/cloud/backup_status_provider.dart';
import 'package:subtrack/features/flashcards/flashcard_dialogs.dart';
import 'package:subtrack/features/flashcards/flashcard_providers.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/features/subjects/subject_providers.dart';
import 'package:subtrack/shared/ui_components.dart';

/// All flashcard decks in the chosen semester. Decks are local-only and are
/// covered by the local `.zip` backup, never by cloud backup.
class FlashcardsPage extends ConsumerWidget {
  const FlashcardsPage({super.key});

  Future<int?> _pickSubject(
    BuildContext context,
    List<SubjectListItem> items,
  ) async {
    final subjects = <Subject>[
      for (final item in items)
        if (!item.subject.isArchived) item.subject,
    ];
    if (subjects.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create a subject first.')),
        );
      }
      return null;
    }
    if (subjects.length == 1) return subjects.single.id;
    return showSubjectPicker(context, subjects: subjects);
  }

  Future<void> _newDeck(
    BuildContext context,
    WidgetRef ref,
    List<SubjectListItem> items,
  ) async {
    final subjectId = await _pickSubject(context, items);
    if (subjectId == null || !context.mounted) return;
    final name = await showDeckNameDialog(context);
    if (name == null || !context.mounted) return;
    try {
      final deckId = await ref
          .read(flashcardRepoProvider)
          .createDeck(subjectId: subjectId, name: name);
      await ref.read(localBackupPendingProvider.notifier).markPending();
      if (context.mounted) context.push('/decks/$deckId');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create deck: $error')),
        );
      }
    }
  }

  Future<void> _importWithAi(
    BuildContext context,
    List<SubjectListItem> items,
  ) async {
    final subjectId = await _pickSubject(context, items);
    if (subjectId == null || !context.mounted) return;
    await context.push('/flashcards/import?subject=$subjectId');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semesterId = ref.watch(selectedSemesterProvider);
    return Scaffold(
      body: SafeArea(
        child: semesterId == null
            ? const EmptyState(
                icon: Icons.style_outlined,
                title: 'Choose a semester first',
                message: 'Flashcards belong to the subjects in a semester.',
              )
            : _body(context, ref, semesterId),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, int semesterId) {
    final asyncDecks = ref.watch(decksInSemesterProvider(semesterId));
    final subjectsAsync = ref.watch(subjectsProvider(semesterId));
    final subjects = subjectsAsync.value ?? <SubjectListItem>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        18,
        AppTheme.screenPadding,
        28,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flashcards',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: context.palette.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Study decks for this semester',
                    style: TextStyle(color: context.palette.mutedText),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Import with AI',
              onPressed: () => _importWithAi(context, subjects),
              icon: const Icon(Icons.auto_awesome_outlined),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _newDeck(context, ref, subjects),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('New deck'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _importWithAi(context, subjects),
                icon: const Icon(Icons.upload_file_outlined, size: 20),
                label: const Text('Import with AI'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.palette.card,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(color: context.palette.cardBorder),
          ),
          child: Row(
            children: [
              Icon(
                Icons.phonelink_lock_outlined,
                size: 20,
                color: context.palette.accentText,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Decks stay on this phone. Export a local backup to keep a '
                  'copy.',
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        asyncDecks.when(
          loading: () => const AppLoadingState(message: 'Loading decks...'),
          error: (error, _) =>
              AppErrorState(message: 'Could not load decks: $error'),
          data: (items) {
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 28),
                child: EmptyState(
                  icon: Icons.style_outlined,
                  title: 'No flashcards yet',
                  message:
                      'Create a deck by hand, or paste an AI reply with the '
                      'import button.',
                ),
              );
            }
            final groups = <String, List<SemesterDeckItem>>{};
            for (final item in items) {
              groups.putIfAbsent(item.subjectName, () => []).add(item);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 6),
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        color: context.palette.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  for (final item in entry.value) ...[
                    _DeckCard(item: item),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.item});

  final SemesterDeckItem item;

  @override
  Widget build(BuildContext context) {
    final deck = item.deck;
    return AppCard(
      onTap: () => context.push('/decks/${deck.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.palette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.style_outlined,
              color: context.palette.accentText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deck.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.cardCount} ${item.cardCount == 1 ? 'card' : 'cards'}'
                  '${deck.source == 'ai_import' ? ' · AI import' : ''}',
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
