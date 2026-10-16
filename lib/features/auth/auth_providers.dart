import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/router.dart';
import 'package:subtrack/features/auth/auth_service.dart';

/// Overridden in [main] with the real instance and in tests with mocks.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not set'),
);

final authServiceProvider = Provider<AuthService>((ref) {
  return FakeAuthService(prefs: ref.watch(sharedPreferencesProvider));
});

/// Holds the signed-in user. The router watches this and rebuilds on
/// sign-in/sign-out so the redirect re-evaluates.
class AuthController extends Notifier<AppUser?> {
  AuthService get _service => ref.read(authServiceProvider);

  @override
  AppUser? build() => _service.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    await _service.signIn(email: email, password: password);
    state = _service.currentUser;
  }

  Future<void> signUp({required String email, required String password}) async {
    await _service.signUp(email: email, password: password);
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
