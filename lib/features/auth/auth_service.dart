import 'package:shared_preferences/shared_preferences.dart';

/// Signed-in account. The real Supabase version arrives in Phase 5;
/// until then [FakeAuthService] accepts any email and password.
class AppUser {
  const AppUser({required this.id, required this.email});

  final String id;
  final String email;
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

abstract class AuthService {
  AppUser? get currentUser;

  Future<void> signIn({required String email, required String password});

  Future<void> signUp({required String email, required String password});

  Future<void> signOut();
}

/// Development stand-in for Supabase auth. Accepts any non-empty email and
/// password and persists the session in [SharedPreferences] so the app can
/// open offline after the first sign-in (AGENTS.md constraint 2).
class FakeAuthService implements AuthService {
  FakeAuthService({required this.prefs}) {
    final email = prefs.getString(_sessionKey);
    if (email != null && email.isNotEmpty) {
      _currentUser = AppUser(id: email, email: email);
    }
  }

  static const String _sessionKey = 'subtrack_fake_auth_email';

  final SharedPreferences prefs;
  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  Future<void> _authenticate(String email, String password) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw const AuthException('Enter a valid email address.');
    }
    if (password.isEmpty) {
      throw const AuthException('Enter your password.');
    }
    await prefs.setString(_sessionKey, trimmed);
    _currentUser = AppUser(id: trimmed, email: trimmed);
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _authenticate(email, password);

  @override
  Future<void> signUp({required String email, required String password}) =>
      _authenticate(email, password);

  @override
  Future<void> signOut() async {
    await prefs.remove(_sessionKey);
    _currentUser = null;
  }
}
