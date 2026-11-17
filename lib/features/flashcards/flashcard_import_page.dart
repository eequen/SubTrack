import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/core/flashcards_parser.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/data/repositories/subject_repo.dart';
import 'package:subtrack/features/flashcards/flashcard_dialogs.dart';
import 'package:subtrack/features/flashcards/flashcard_preview_page.dart';
import 'package:subtrack/features/semesters/semester_providers.dart';
import 'package:subtrack/features/subjects/subject_providers.dart';
import 'package:subtrack/shared/ui_components.dart';

/// Bring-your-own-AI import. SubTrack never calls a model or reads a PDF; the
/// student copies the prompt into an AI chat, then pastes the reply here.
class FlashcardImportPage extends ConsumerStatefulWidget {
  const FlashcardImportPage({this.subjectId, super.key});

  final String? subjectId;

  @override
  ConsumerState<FlashcardImportPage> createState() =>
      _FlashcardImportPageState();
}

class _FlashcardImportPageState extends ConsumerState<FlashcardImportPage> {
  late final TextEditingController _paste = TextEditingController();
  int? _subjectId;
  String? _error;
  bool _readingFile = false;

  @override
  void initState() {
    super.initState();
    _subjectId = int.tryParse(widget.subjectId ?? '');
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyPrompt() async {
    await Clipboard.setData(const ClipboardData(text: flashcardPromptV1));
    _snack('Prompt copied. Paste it into any AI chat with your notes.');
  }

  Future<void> _pickSubject(List<Subject> subjects) async {
    if (subjects.isEmpty) {
      _snack('Create a subject first.');
      return;
    }
    final id = await showSubjectPicker(
      context,
      subjects: subjects,
      title: 'Import into subject',
    );
    if (id != null && mounted) setState(() => _subjectId = id);
  }

  Future<void> _pickFile() async {
    setState(() => _readingFile = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'txt'],
      );
      if (result.isEmpty) return;
      final bytes = await result.single.readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true);
      _paste.text = text;
      setState(() => _error = null);
    } catch (error) {
      _snack('Could not read that file: $error');
    } finally {
      if (mounted) setState(() => _readingFile = false);
    }
  }

  void _preview(List<Subject> subjects) {
    final subjectId = _subjectId;
    if (subjectId == null) {
      setState(() => _error = 'Choose a subject before previewing.');
      return;
    }
    try {
      final parsed = parseFlashcardImport(_paste.text);
      setState(() => _error = null);
      context.push(
        '/flashcards/preview',
        extra: FlashcardPreviewArgs(
          subjectId: subjectId,
          subjects: subjects,
          deck: parsed,
        ),
      );
    } on FlashcardParseException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(
        () => _error =
            'That reply could not be read. Copy the AI reply again and '
            'paste it completely.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final semesterId = ref.watch(selectedSemesterProvider);
    final subjectsAsync = semesterId == null
        ? const AsyncValue<List<SubjectListItem>>.data([])
        : ref.watch(subjectsProvider(semesterId));
    final subjects = <Subject>[
      for (final item in subjectsAsync.value ?? const <SubjectListItem>[])
        item.subject,
    ];
    final selected = subjects
        .where((subject) => subject.id == _subjectId)
        .firstOrNull;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Expanded(
                    child: Text(
                      'Import cards with AI',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.screenPadding,
                  8,
                  AppTheme.screenPadding,
                  28,
                ),
                children: [
                  Text(
                    'SubTrack does not read PDFs or call an AI. Copy the prompt '
                    'below, attach your notes in ChatGPT, Claude, Gemini, or '
                    'another chat app, then paste the JSON reply here.',
                    style: TextStyle(
                      color: context.palette.mutedText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_outlined,
                              color: context.palette.accentText,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Step 1 - Copy this prompt',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _copyPrompt,
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Copy'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.palette.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: context.palette.cardBorder,
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              flashcardPromptV1,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                height: 1.35,
                                color: context.palette.mutedText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Step 2 - Choose the subject',
                          style: TextStyle(
                            color: context.palette.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (subjects.isNotEmpty)
                        TextButton(
                          onPressed: () => _pickSubject(subjects),
                          child: Text(selected == null ? 'Choose' : 'Change'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AppCard(
                    onTap: () => _pickSubject(subjects),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          color: context.palette.accentText,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selected?.name ?? 'No subject selected',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: selected == null
                                  ? context.palette.mutedText
                                  : context.palette.text,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Step 3 - Paste the reply',
                    style: TextStyle(
                      color: context.palette.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _paste,
                    minLines: 7,
                    maxLines: 14,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      hintText:
                          'Paste the AI reply here. JSON is best; Q:/A: lines '
                          'also work.',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _readingFile ? null : _pickFile,
                        icon: _readingFile
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.folder_open_outlined, size: 18),
                        label: const Text('Open .json or .txt'),
                      ),
                      TextButton(
                        onPressed: () {
                          _paste.clear();
                          setState(() => _error = null);
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.palette.overdueBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: context.palette.overdue,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: context.palette.overdue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Preview cards',
                    icon: Icons.visibility_outlined,
                    onPressed: () => _preview(subjects),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Nothing is saved until you review the cards and press '
                    'Save deck.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.palette.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
