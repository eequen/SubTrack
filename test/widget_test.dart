import 'package:flutter_test/flutter_test.dart';
import 'package:subtrack/app/app.dart';

void main() {
  testWidgets('app starts at login with bottom tabs available on tab routes', (
    tester,
  ) async {
    await tester.pumpWidget(const SubTrackApp());
    await tester.pumpAndSettle();

    expect(find.text('SubTrack'), findsOneWidget);
    expect(
      find.text('Every subject, every version, safely kept.'),
      findsOneWidget,
    );
  });
}
