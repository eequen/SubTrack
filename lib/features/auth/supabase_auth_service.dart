import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// Shown when the device has no internet and there is no saved session yet.
const String _offlineMessage =
    'No internet connection. The first sign-in needs the internet; '
    'after that the app works offline.';

/// Maps a Supabase or network failure to a friendly message
/// (AGENTS.md section 9, Phase 5 task 2).
String authErrorMessage(Object error) {
  if (error is supa.AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Wrong email or password.';
    }
    if (message.contains('email not confirmed')) {
      return 'Confirm your email first — check your inbox.';
    }
    if (message.contains('already registered')) {
      return 'An account with this email already exists. Log in instead.';
    }
    if (message.contains('rate limit') || message.contains('too many')) {
      return 'Too many attempts. Try again in a minute.';
    }
    if (error is supa.AuthRetryableFetchException) {
      return _offlineMessage;
    }
    return error.message;
  }
  if (error is SocketException) {
    return _offlineMessage;
  }
  return 'Something went wrong. Try again.';
}

/// Real auth backed by Supabase (email + password).
///
/// supabase_flutter persists and restores its own session, so the app opens
/// offline after the first sign-in (AGENTS.md constraint 2). The user id and
/// email are also mirrored into [SharedPreferences] synchronously, because
/// the per-user database file name (AGENTS.md section 8) is needed before
/// any network call can happen.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client, this._prefs) {
    final id = _prefs.getString(_userIdKey);
    final email = _prefs.getString(_userEmailKey);
    if (id != null && id.isNotEmpty && email != null && email.isNotEmpty) {
      _currentUser = AppUser(id: id, email: email);
    }
  }

  /// Real app storage; tests construct [SupabaseAuthService] directly with
  /// a plain client instead.
  SupabaseAuthService.app({required SharedPreferences prefs})
    : this(supa.Supabase.instance.client, prefs);

  static const String _userIdKey = 'subtrack_supabase_user_id';
  static const String _userEmailKey = 'subtrack_supabase_user_email';

  final supa.SupabaseClient _client;
  final SharedPreferences _prefs;
  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    _validate(email, password);
    await _guard(
      () => _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      ),
    );
    _rememberUser();
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    _validate(email, password);
    await _guard(
      () => _client.auth.signUp(email: email.trim(), password: password),
    );
    // When email confirmation is still enabled, sign-up returns no session.
    _rememberUser();
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on supa.AuthException {
      // The local sign-out below must happen even if the server call fails.
    } on SocketException {
      // Same: offline sign-out still signs out locally.
    }
    await _prefs.remove(_userIdKey);
    await _prefs.remove(_userEmailKey);
    _currentUser = null;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on supa.AuthException catch (e) {
      throw AuthException(authErrorMessage(e));
    } on SocketException {
      throw const AuthException(_offlineMessage);
    }
  }

  void _validate(String email, String password) {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw const AuthException('Enter a valid email address.');
    }
    if (password.isEmpty) {
      throw const AuthException('Enter your password.');
    }
  }

  /// Saves the signed-in user for offline starts, or explains why there is
  /// no session yet (email confirmation pending).
  void _rememberUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException(
        'Check your email to confirm your account, then log in.',
      );
    }
    _prefs.setString(_userIdKey, user.id);
    _prefs.setString(_userEmailKey, user.email ?? '');
    _currentUser = AppUser(id: user.id, email: user.email ?? '');
  }
}
