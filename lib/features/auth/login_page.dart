import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';

/// Screen 1 from AGENTS.md section 14: Log in with an email or a username.
/// Creating an account lives on its own screen (`/create-account`).
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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          children: [
            const SizedBox(height: 48),
            Text(
              'SubTrack',
              style: textTheme.headlineLarge?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Every subject, every version, safely kept.',
              style: textTheme.bodyLarge?.copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: 16),
            // First-time users must see where to go (requested change).
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inProgressBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'First time here? Create an account first — the button at '
                'the end of this screen.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.inProgressText,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Email or username', style: textTheme.labelLarge),
            const SizedBox(height: 6),
            TextField(
              controller: _identifierController,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _clearError(),
            ),
            const SizedBox(height: 16),
            Text('Password', style: textTheme.labelLarge),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: !_passwordVisible,
              onChanged: (_) => _clearError(),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                  icon: Icon(
                    _passwordVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.overdue)),
              const SizedBox(height: 8),
            ],
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Please wait…' : 'Log in'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => context.go('/signup'),
              child: const Text('Create account'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sign in once. After that, the app works offline.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
