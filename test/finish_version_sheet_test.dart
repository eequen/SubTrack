import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/shared/finish_version_sheet.dart';

void main() {
  testWidgets('sliding up submits and sliding down saves as final', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light('indigo'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showFinishVersionSheet(
                    context,
                    versionNo: 2,
                    fileName: 'thesis.docx',
                    currentStatus: 'in_progress',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Save v2'), findsOneWidget);
    expect(find.text('Save & submit'), findsOneWidget);
    expect(find.text('Save as final'), findsOneWidget);

    await tester.drag(find.byKey(finishVersionKnobKey), const Offset(0, -90));
    await tester.pumpAndSettle();
    expect(result, finishVersionSubmitted);

    result = null;
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(finishVersionKnobKey), const Offset(0, 90));
    await tester.pumpAndSettle();
    expect(result, finishVersionFinal);
  });
}
