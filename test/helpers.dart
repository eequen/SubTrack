import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtrack/data/db/app_database.dart';

/// Closes a drift database inside a widget test.
///
/// When the last listener of a drift query stream cancels, drift keeps the
/// stream cached for one more event-loop turn by scheduling a zero-duration
/// timer (`StreamQueryStore.markAsClosed`). `close()` waits for those timers.
/// In widget tests a timer scheduled from the fake zone only fires when fake
/// time advances ([WidgetTester.pump]) and one scheduled from the real zone
/// only fires while the real event loop turns ([WidgetTester.runAsync]), so
/// this helper alternates both until `close()` completes.
Future<void> closeDatabase(WidgetTester tester, AppDatabase db) async {
  // Unmount the widget tree first: a widget that still keeps a drift stream
  // subscription can block close() (its stream controller waits for the
  // done event to be delivered to the listener).
  await tester.pumpWidget(const SizedBox());
  await tester.pump();

  var done = false;
  final closing = db.close().whenComplete(() => done = true);
  for (var i = 0; i < 50 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(done, isTrue, reason: 'database close did not finish in 50 turns');
  await closing;
}
