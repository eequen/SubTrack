import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/app/app.dart';
import 'package:subtrack/app/providers.dart';
import 'package:subtrack/data/db/app_database.dart';
import 'package:subtrack/features/auth/auth_providers.dart';
import 'package:subtrack/features/auth/auth_service.dart';

/// Screen 15 slice 1: profile card, cloud row, version footer.
void main() {
  testWidgets('profile shows the account and the cloud row', (tester) async {
    SharedPreferences.setMockInitialValues({
      'subtrack_fake_auth_email': 'kent@gmail.com',
    });
    final prefs = await SharedPreferences.getInstance();
    final auth = FakeAuthService(prefs: prefs);
    final db = AppDatabase.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authServiceProvider.overrideWithValue(auth),
          databaseProvider.overrideWithValue(db),
          initialLocationProvider.overrideWithValue('/profile'),
        ],
        child: const SubTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsNWidgets(2)); // title + nav tab label
    expect(find.text('@kent@gmail.com'), findsOneWidget);
    expect(find.text('Cloud backup and restore'), findsOneWidget);
    expect(find.text('SubTrack version 1.0.0'), findsOneWidget);
    await db.close();
  });
}
