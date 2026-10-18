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
  String? _error;

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
      if (mounted) context.go('/semesters');
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
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Text('Password', style: textTheme.labelLarge),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: true,
              onSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Password reset is not available yet. Account '
                        'recovery comes after the defense.',
                      ),
                    ),
                  );
                },
                child: const Text('Forgot password?'),
              ),
            ),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Please wait…' : 'Log in'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => context.go('/create-account'),
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
