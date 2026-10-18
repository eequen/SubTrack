import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/app.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';

Future<AppDatabase> _pumpApp(
  WidgetTester tester, {
  String initialLocation = '/login',
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthService(prefs: prefs);
  final db = AppDatabase.memory();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(auth),
        databaseProvider.overrideWithValue(db),
        initialLocationProvider.overrideWithValue(initialLocation),
      ],
      child: const SubTrackApp(),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

Future<void> _close(AppDatabase db, WidgetTester tester) async {
  await db.close();
  await tester.pump();
}

void main() {
  testWidgets('login screen shows fields and offline note', (tester) async {
    final db = await _pumpApp(tester);

    expect(find.text('SubTrack'), findsOneWidget);
    expect(find.text('maria@school.edu'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Log in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(
      find.text('Sign in once. After that, the app works offline.'),
      findsOneWidget,
    );
    await _close(db, tester);
  });

  testWidgets('signed-out deep link redirects to login', (tester) async {
    final db = await _pumpApp(tester, initialLocation: '/subjects');

    expect(find.widgetWithText(ElevatedButton, 'Log in'), findsOneWidget);
    await _close(db, tester);
  });

  testWidgets('log in with any credentials opens choose semester', (
    tester,
  ) async {
    final db = await _pumpApp(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'maria@school.edu'),
      'maria@school.edu',
    );
    await tester.enterText(find.widgetWithText(TextField, '••••••••••'), 's');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Choose semester'), findsOneWidget);
    expect(find.text('Signed in as maria@school.edu'), findsOneWidget);
    await _close(db, tester);
  });

  testWidgets('invalid email shows an error and stays on login', (
    tester,
  ) async {
    final db = await _pumpApp(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'maria@school.edu'),
      'not-an-email',
    );
    await tester.enterText(find.widgetWithText(TextField, '••••••••••'), 's');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Log in'), findsOneWidget);
    await _close(db, tester);
  });
}
