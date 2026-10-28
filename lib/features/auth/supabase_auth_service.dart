import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// Shown when the device has no internet and there is no saved session yet.
const String _offlineMessage =
    'No internet connection. The first sign-in needs the internet; '
    'after that the app works offline.';

/// Cloud tables are set up by the SQL scripts in docs/; this appears when a
/// script was not run yet.
const String _setupMessage =
    'Cloud setup is incomplete. The username table is missing — run the '
    'schema script in docs/ first.';

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
    if (message.contains('least 6') || message.contains('least 8')) {
      return 'Passwords need at least 8 characters.';
    }
    if (message.contains('database error saving new user')) {
      return 'Could not create the account. The username may be taken — '
          'try another one.';
    }
    if (error is supa.AuthRetryableFetchException) {
      return _offlineMessage;
    }
    return error.message;
  }
  if (error is supa.PostgrestException) {
    return _setupMessage;
  }
  if (error is SocketException) {
    return _offlineMessage;
  }
  return 'Something went wrong. Try again.';
}

/// Turns "name123" into the account email behind that username so sign-in
/// can accept an email OR a username.
///
/// [lookup] queries the public `profiles` table
/// (docs/supabase_schema_profiles.sql). Email-shaped input passes through
/// untouched. That account's email is only used for the actual sign-in.
Future<String> resolveSignInEmail(
  String identifier,
  Future<String?> Function(String username) lookup,
) async {
  final trimmed = identifier.trim();
  if (trimmed.contains('@')) return trimmed;
  final email = await lookup(normalizeUsername(trimmed));
  if (email == null) {
    throw const AuthException('No account uses that username.');
  }
  return email;
}

/// Real auth backed by Supabase (email or username + password).
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
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    _validateCredentials(identifier, password);
    final email = identifier.trim().contains('@')
        ? identifier.trim()
        : await resolveSignInEmail(identifier, _emailForUsername);
    await _guard(
      () => _client.auth.signInWithPassword(email: email, password: password),
    );
    _rememberUser();
  }

  @override
  Future<void> signUp({
    required String email,
    required String username,
    required String displayName,
    required String password,
  }) async {
    final uname = normalizeUsername(username);
    if (!usernamePattern.hasMatch(uname)) {
      throw const AuthException(
        'Usernames use 3-20 letters, numbers, or underscores and start '
        'with a letter.',
      );
    }
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty || trimmedName.length > 30) {
      throw const AuthException('Enter your display name (30 characters max).');
    }
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      throw const AuthException('Enter a valid email address.');
    }
    if (password.length < 8) {
      throw const AuthException('Passwords need at least 8 characters.');
    }
    await _guard(() => _checkUsernameFree(uname));
    await _guard(
      () => _client.auth.signUp(
        email: trimmedEmail,
        password: password,
        // The on_auth_user_created trigger copies username and display
        // name into the profiles table (docs/supabase_schema_*.sql).
        data: {'username': uname, 'display_name': trimmedName},
      ),
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

  @override
  Future<void> changePassword({required String newPassword}) async {
    if (newPassword.length < 8) {
      throw const AuthException('Passwords need at least 8 characters.');
    }
    await _guard(
      () => _client.auth.updateUser(supa.UserAttributes(password: newPassword)),
    );
  }

  /// Asks the cloud for the email behind [username]; null means nobody
  /// registered it. The profiles table is world-readable on purpose so a
  /// signed-out phone can look usernames up.
  Future<String?> _emailForUsername(String username) async {
    final rows = await _guard(
      () => _client
          .from('profiles')
          .select('email')
          .eq('username', username)
          .limit(1),
    );
    return rows.isEmpty ? null : (rows.single['email'] as String?);
  }

  Future<void> _checkUsernameFree(String uname) async {
    final rows = await _guard(
      () =>
          _client.from('profiles').select('id').eq('username', uname).limit(1),
    );
    if (rows.isNotEmpty) {
      throw const AuthException('That username is taken. Pick another one.');
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on supa.AuthException catch (e) {
      throw AuthException(authErrorMessage(e));
    } on supa.PostgrestException catch (e) {
      throw AuthException(authErrorMessage(e));
    } on SocketException {
      throw const AuthException(_offlineMessage);
    }
  }

  void _validateCredentials(String identifier, String password) {
    if (identifier.trim().isEmpty) {
      throw const AuthException('Enter your email or username.');
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
