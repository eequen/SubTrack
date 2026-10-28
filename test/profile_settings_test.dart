import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/app.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';

import 'helpers.dart';

/// Signs in as kent@gmail.com and opens the app at [location].
Future<AppDatabase> _pumpApp(
  WidgetTester tester, {
  String location = '/profile',
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    'subtrack_fake_auth_email': 'kent@gmail.com',
  });
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.memory();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(FakeAuthService(prefs: prefs)),
        databaseProvider.overrideWithValue(db),
        initialLocationProvider.overrideWithValue(location),
      ],
      child: const SubTrackApp(),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

Future<DbProfile> _profile(AppDatabase db) =>
    db.select(db.profiles).getSingle();

MaterialApp _materialApp(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp));

void main() {
  testWidgets('profile lists the appearance, notifications, and account '
      'sections', (tester) async {
    final db = await _pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsNWidgets(2)); // title + nav tab label
    expect(find.text('@kent@gmail.com'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.byKey(const ValueKey('accent-pink')), findsOneWidget);
    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('Deadline reminders'), findsOneWidget);
    expect(find.text('Weekly backup reminder'), findsOneWidget);
    expect(find.text('Cloud backup and restore'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete cloud data'), findsOneWidget);
    expect(find.text('SubTrack version 1.0.0'), findsOneWidget);

    await closeDatabase(tester, db);
  });

  testWidgets('picking the pink accent re-themes and saves', (tester) async {
    final db = await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('accent-pink')));
    await tester.pumpAndSettle();

    expect(
      _materialApp(tester).theme!.colorScheme.primary,
      const Color(0xFFC2185B),
    );
    expect((await _profile(db)).accentKey, 'pink');

    await closeDatabase(tester, db);
  });

  testWidgets('choosing Dark switches the theme mode and saves', (
    tester,
  ) async {
    final db = await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();

    expect(_materialApp(tester).themeMode, ThemeMode.dark);
    expect((await _profile(db)).themeMode, 'dark');

    await closeDatabase(tester, db);
  });

  testWidgets('Edit opens Edit profile and saves the display name', (
    tester,
  ) async {
    final db = await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text("Username can't be changed"), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('display-name-field')),
      'Kent P.',
    );
    await tester.tap(find.byKey(const ValueKey('save-profile')));
    await tester.pumpAndSettle();

    expect(find.text('Edit profile'), findsNothing);
    expect(find.text('Kent P.'), findsOneWidget);
    expect((await _profile(db)).displayName, 'Kent P.');

    await closeDatabase(tester, db);
  });

  testWidgets('change password validates and reports success', (tester) async {
    final db = await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('change-password')));
    await tester.pumpAndSettle();
    expect(find.text('Change password'), findsNWidgets(2)); // tile + dialog

    await tester.enterText(find.byKey(const ValueKey('new-password')), 'short');
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Passwords need at least 8 characters.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-password')),
      'password123',
    );
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Password changed.'), findsOneWidget);

    await closeDatabase(tester, db);
  });

  testWidgets('sign out asks first and returns to the login screen', (
    tester,
  ) async {
    final db = await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sign-out-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);

    await closeDatabase(tester, db);
  });

  testWidgets('delete cloud data needs the exact username typed', (
    tester,
  ) async {
    final db = await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-cloud-data')));
    await tester.pumpAndSettle();

    FilledButton deleteButton() => tester.widget<FilledButton>(
      find.byKey(const ValueKey('delete-confirm-button')),
    );
    expect(deleteButton().onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm-field')),
      'wrong-name',
    );
    await tester.pump();
    expect(deleteButton().onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm-field')),
      'kent@gmail.com',
    );
    await tester.pump();
    expect(deleteButton().onPressed, isNotNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await closeDatabase(tester, db);
  });
}
