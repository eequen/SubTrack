import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/features/files/file_pick.dart';

void main() {
  testWidgets('file source chooser uses a visible themed sheet', (
    tester,
  ) async {
    Future<PickedUpload?>? pickFuture;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light('indigo'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => pickFuture = pickFileBytes(context),
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    expect(find.text('Add file'), findsOneWidget);
    expect(find.text('From storage'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Material &&
            widget.color == AppTheme.light('indigo').colorScheme.surface,
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await pickFuture, isNull);
  });
}
