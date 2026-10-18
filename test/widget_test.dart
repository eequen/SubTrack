import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/app.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';

/// The create-account screen is taller than the default widget-test
/// surface and ListViews do not build offscreen children, so those tests
/// run on a taller surface instead.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

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
    expect(find.text('Email or username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Log in'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Create account'),
      findsOneWidget,
    );
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

    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'maria@school.edu');
    await tester.enterText(fields.last, 's');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Choose semester'), findsOneWidget);
    expect(find.text('Signed in as maria@school.edu'), findsOneWidget);
    await _close(db, tester);
  });

  testWidgets('empty identifier shows an error and stays on login', (
    tester,
  ) async {
    final db = await _pumpApp(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email or username.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Log in'), findsOneWidget);
    await _close(db, tester);
  });

  testWidgets('create account button opens the create-account screen', (
    tester,
  ) async {
    _tallView(tester);
    final db = await _pumpApp(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Back to log in'),
      findsOneWidget,
    );
    await _close(db, tester);
  });

  testWidgets('mismatched passwords are rejected on create account', (
    tester,
  ) async {
    _tallView(tester);
    final db = await _pumpApp(tester, initialLocation: '/create-account');

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'maria_01');
    await tester.enterText(fields.at(1), 'maria@school.edu');
    await tester.enterText(fields.at(2), 'secret123');
    await tester.enterText(fields.at(3), 'secret124');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(find.text('Create account'), findsWidgets);
    await _close(db, tester);
  });

  testWidgets('successful sign up lands on choose semester', (tester) async {
    _tallView(tester);
    final db = await _pumpApp(tester, initialLocation: '/create-account');

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'maria_01');
    await tester.enterText(fields.at(1), 'maria@school.edu');
    await tester.enterText(fields.at(2), 'secret123');
    await tester.enterText(fields.at(3), 'secret123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Choose semester'), findsOneWidget);
    await _close(db, tester);
  });

  testWidgets('bad username shape is rejected on create account', (
    tester,
  ) async {
    _tallView(tester);
    final db = await _pumpApp(tester, initialLocation: '/create-account');

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'no!');
    await tester.enterText(fields.at(1), 'maria@school.edu');
    await tester.enterText(fields.at(2), 'secret123');
    await tester.enterText(fields.at(3), 'secret123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Usernames use 3-20'), findsOneWidget);
    await _close(db, tester);
  });
}
