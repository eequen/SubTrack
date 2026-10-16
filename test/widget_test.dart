import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/app.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  String initialLocation = '/login',
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthService(prefs: prefs);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(auth),
        initialLocationProvider.overrideWithValue(initialLocation),
      ],
      child: const SubTrackApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login screen shows fields and offline note', (tester) async {
    await _pumpApp(tester);

    expect(find.text('SubTrack'), findsOneWidget);
    expect(find.text('maria@school.edu'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Log in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(
      find.text('Sign in once. After that, the app works offline.'),
      findsOneWidget,
    );
  });

  testWidgets('signed-out deep link redirects to login', (tester) async {
    await _pumpApp(tester, initialLocation: '/subjects');

    expect(find.widgetWithText(ElevatedButton, 'Log in'), findsOneWidget);
  });

  testWidgets('log in with any credentials opens choose semester', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'maria@school.edu'),
      'maria@school.edu',
    );
    await tester.enterText(find.widgetWithText(TextField, '••••••••••'), 's');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Choose semester'), findsOneWidget);
    expect(find.text('Signed in as maria@school.edu'), findsOneWidget);
  });

  testWidgets('invalid email shows an error and stays on login', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'maria@school.edu'),
      'not-an-email',
    );
    await tester.enterText(find.widgetWithText(TextField, '••••••••••'), 's');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Log in'), findsOneWidget);
  });
}
