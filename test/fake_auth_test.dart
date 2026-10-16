import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/features/auth/auth_service.dart';

Future<FakeAuthService> _service() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return FakeAuthService(prefs: prefs);
}

void main() {
  test('signIn accepts any email and password', () async {
    final auth = await _service();
    expect(auth.currentUser, isNull);

    await auth.signIn(email: 'maria@school.edu', password: 'secret');

    expect(auth.currentUser?.email, 'maria@school.edu');
  });

  test('signIn rejects invalid email and empty password', () async {
    final auth = await _service();

    await expectLater(
      auth.signIn(email: 'not-an-email', password: 'secret'),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      auth.signIn(email: 'maria@school.edu', password: ''),
      throwsA(isA<AuthException>()),
    );
    expect(auth.currentUser, isNull);
  });

  test('session persists across instances, signOut clears it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final first = FakeAuthService(prefs: prefs);
    await first.signIn(email: 'maria@school.edu', password: 'secret');

    final second = FakeAuthService(prefs: prefs);
    expect(second.currentUser?.email, 'maria@school.edu');

    await second.signOut();
    expect(second.currentUser, isNull);

    final third = FakeAuthService(prefs: prefs);
    expect(third.currentUser, isNull);
  });
}
