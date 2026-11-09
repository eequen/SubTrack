import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/shared/brand_logo.dart';
import 'package:subtrack/shared/ui_components.dart';

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
          padding: EdgeInsets.zero,
          children: [
            BrandHeader(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 36),
              child: Column(
                children: [
                  const BrandLogo.icon(height: 104, onDarkSurface: true),
                  const SizedBox(height: 12),
                  Text(
                    'SubTrack',
                    style: textTheme.headlineMedium?.copyWith(
                      color: context.palette.onAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Every subject, every version, safely kept.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: context.palette.onAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Username', style: textTheme.labelLarge),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _identifierController,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Enter your username',
                    ),
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
                      hintText: 'Enter your password',
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
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: context.palette.overdue),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: 'Log in',
                    loading: _busy,
                    onPressed: _busy ? null : _submit,
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: 'Create account',
                    onPressed: _busy ? null : () => context.go('/signup'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Sign in once. After that, the app works offline.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: context.palette.mutedText,
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
