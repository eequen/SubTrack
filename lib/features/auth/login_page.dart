import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/shared/editorial.dart';

/// Screen 1 from AGENTS.md section 14: Log in with an email or a username.
/// Creating an account lives on its own screen (`/signup`).
///
/// Campus-editorial treatment: masthead, logo lockup, serif statement, and a
/// ruled index-card form instead of a generic Material login card.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _passwordVisible = false;
  String? _error;

  /// Any edit clears a previous error so the form looks clean while the
  /// student fixes what was wrong.
  void _clearError() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authControllerProvider.notifier);
    try {
      await auth.signIn(
        identifier: _identifierController.text,
        password: _passwordController.text,
      );
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            18,
            AppTheme.screenPadding,
            28,
          ),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SubTrack',
                        style: textTheme.titleLarge?.copyWith(
                          color: palette.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'STUDENT ARCHIVE / EVERY VERSION',
                        style: textTheme.labelSmall?.copyWith(
                          color: palette.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'EST. 2026',
                  style: textTheme.labelSmall?.copyWith(
                    color: palette.mutedText,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const EditorialRule(padding: EdgeInsets.only(top: 14, bottom: 18)),
            const SubTrackMark(height: 92),
            const SizedBox(height: 16),
            Text(
              'Every subject,\nevery version,\nsafely kept.',
              style: textTheme.displaySmall?.copyWith(
                color: palette.text,
                height: 1.02,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                color: palette.card,
                border: Border.all(color: palette.cardBorder),
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('01 / Sign in'),
                  const SizedBox(height: 14),
                  Text('Email or username', style: textTheme.labelLarge),
                  const SizedBox(height: 2),
                  TextField(
                    controller: _identifierController,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _clearError(),
                  ),
                  const SizedBox(height: 18),
                  Text('Password', style: textTheme.labelLarge),
                  const SizedBox(height: 2),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_passwordVisible,
                    onChanged: (_) => _clearError(),
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: palette.deadlineBg,
                        border: Border(
                          left: BorderSide(color: palette.overdue, width: 3),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: textTheme.bodySmall?.copyWith(
                          color: palette.overdue,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Please wait…' : 'Log in'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _busy ? null : () => context.go('/signup'),
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: palette.inProgressBg,
                border: Border(
                  left: BorderSide(color: palette.inProgressText, width: 2),
                ),
              ),
              child: Text(
                'First time here? Create an account first. The button is at '
                'the end of the form.',
                style: textTheme.bodySmall?.copyWith(
                  color: palette.inProgressText,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Sign in once. After that, the app works offline.',
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(color: palette.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}
