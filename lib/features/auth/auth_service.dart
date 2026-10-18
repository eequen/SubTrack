import 'package:shared_preferences/shared_preferences.dart';

/// Signed-in account. [username] can be empty for sessions restored
/// offline (it is only needed while signing in).
class AppUser {
  const AppUser({required this.id, required this.email, this.username = ''});

  final String id;
  final String email;
  final String username;
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

/// Usernames: 3-20 lowercase letters, digits, or underscores, starting
/// with a letter. Validated here so the form and the services agree.
final RegExp usernamePattern = RegExp(r'^[a-z][a-z0-9_]{2,19}$');

/// Trims, lowercases, and underscorifies a typed username candidate.
String normalizeUsername(String raw) =>
    raw.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();

abstract class AuthService {
  AppUser? get currentUser;

  /// [identifier] is an email address or a username.
  Future<void> signIn({required String identifier, required String password});

  Future<void> signUp({
    required String email,
    required String username,
    required String password,
  });

  Future<void> signOut();
}

/// Development stand-in for Supabase auth. Accepts any non-empty
/// identifier (email or username) and password, and persists the session
/// in [SharedPreferences] so the app can open offline after the first
/// sign-in (AGENTS.md constraint 2).
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

  Future<void> _authenticate(String identifier, String password) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) {
      throw const AuthException('Enter your email or username.');
    }
    if (password.isEmpty) {
      throw const AuthException('Enter your password.');
    }
    await prefs.setString(_sessionKey, trimmed);
    _currentUser = AppUser(id: trimmed, email: trimmed);
  }

  @override
  Future<void> signIn({required String identifier, required String password}) =>
      _authenticate(identifier, password);

  @override
  Future<void> signUp({
    required String email,
    required String username,
    required String password,
  }) => _authenticate(email, password);

  @override
  Future<void> signOut() async {
    await prefs.remove(_sessionKey);
    _currentUser = null;
  }
}
