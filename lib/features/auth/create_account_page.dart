import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/shared/brand_logo.dart';
import 'package:subtrack/shared/ui_components.dart';

/// Email shape check for the create-account form; Supabase re-checks it.
final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// A separate screen for new users (requested change): username, email,
/// password, and a confirm-password field to catch typos.
class CreateAccountPage extends ConsumerStatefulWidget {
  const CreateAccountPage({super.key});

  @override
  ConsumerState<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends ConsumerState<CreateAccountPage> {
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  bool _passwordVisible = false;
  bool _confirmVisible = false;
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
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validate() {
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty || displayName.length > 30) {
      return 'Enter your display name (30 characters max).';
    }
    final uname = normalizeUsername(_usernameController.text);
    if (!usernamePattern.hasMatch(uname)) {
      return 'Usernames use 3-20 letters, numbers, or underscores and start '
          'with a letter.';
    }
    if (!_emailPattern.hasMatch(_emailController.text.trim())) {
      return 'Enter a valid email address.';
    }
    if (_passwordController.text.length < 8) {
      return 'Passwords need at least 8 characters.';
    }
    if (_confirmController.text != _passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authControllerProvider.notifier);
    try {
      await auth.signUp(
        email: _emailController.text.trim(),
        username: _usernameController.text,
        displayName: _displayNameController.text,
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
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              child: Column(
                children: [
                  const BrandLogo.icon(height: 84, onDarkSurface: true),
                  const SizedBox(height: 12),
                  Text(
                    'Create account',
                    style: textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose the username you will log in with.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Display name', style: textTheme.labelLarge),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _displayNameController,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'How should we address you?',
                    ),
                    onChanged: (_) => _clearError(),
                  ),
                  const SizedBox(height: 16),
                  Text('Username', style: textTheme.labelLarge),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _usernameController,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Choose a username',
                    ),
                    onChanged: (_) => _clearError(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '3-20 letters, numbers, or underscores. Starts with a letter.',
                    style: textTheme.bodySmall?.copyWith(
                      color: context.palette.mutedText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Email', style: textTheme.labelLarge),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Email address',
                    ),
                    onChanged: (_) => _clearError(),
                  ),
                  const SizedBox(height: 16),
                  Text('Password', style: textTheme.labelLarge),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_passwordVisible,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _clearError(),
                    decoration: InputDecoration(
                      hintText: 'At least 8 characters',
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
                  const SizedBox(height: 16),
                  Text('Confirm password', style: textTheme.labelLarge),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _confirmController,
                    obscureText: !_confirmVisible,
                    onChanged: (_) => _clearError(),
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'Re-enter your password',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _confirmVisible = !_confirmVisible),
                        icon: Icon(
                          _confirmVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(color: context.palette.overdue),
                    ),
                  ],
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Create account',
                    loading: _busy,
                    onPressed: _busy ? null : _submit,
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: 'Back to log in',
                    onPressed: _busy ? null : () => context.go('/login'),
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
