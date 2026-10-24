import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/router.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/features/auth/supabase_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// Supabase credentials arrive only through --dart-define (AGENTS.md
/// constraint 8: no secrets in git). They are empty in tests and in
/// teammates' builds, which keeps the [FakeAuthService].
const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String _supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// True when the app was built with Supabase credentials.
bool get supabaseConfigured =>
    _supabaseUrl.isNotEmpty && _supabaseKey.isNotEmpty;

/// Initializes Supabase when credentials were provided. Called once from
/// main() before runApp; must not run in tests (no defines there).
Future<void> initializeSupabase() async {
  if (supabaseConfigured) {
    await supa.Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseKey,
    );
  }
}

/// Overridden in [main] with the real instance and in tests with mocks.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not set'),
);

final authServiceProvider = Provider<AuthService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  if (supabaseConfigured) {
    return SupabaseAuthService.app(prefs: prefs);
  }
  return FakeAuthService(prefs: prefs);
});

/// Holds the signed-in user. The router watches this and rebuilds on
/// sign-in/sign-out so the redirect re-evaluates.
class AuthController extends Notifier<AppUser?> {
  AuthService get _service => ref.read(authServiceProvider);

  @override
  AppUser? build() => _service.currentUser;

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    await _service.signIn(identifier: identifier, password: password);
    state = _service.currentUser;
  }

  Future<void> signUp({
    required String email,
    required String username,
    required String displayName,
    required String password,
  }) async {
    await _service.signUp(
      email: email,
      username: username,
      displayName: displayName,
      password: password,
    );
    state = _service.currentUser;
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = null;
  }
}

final authControllerProvider = NotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);

/// Overridden in tests to verify redirects from deep links.
final initialLocationProvider = Provider<String>((_) => '/login');

final routerProvider = Provider<GoRouter>((ref) {
  final user = ref.watch(authControllerProvider);
  return buildRouter(
    isSignedIn: user != null,
    initialLocation: ref.watch(initialLocationProvider),
  );
});
