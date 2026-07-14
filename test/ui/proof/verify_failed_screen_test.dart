import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/ui/proof/verify_failed_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_proof_pipeline.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  testWidgets('with retries remaining: shows the reason and tries left, '
      'Retake photo calls onRetake', (tester) async {
    var retakeCalls = 0;
    var cancelCalls = 0;
    await tester.pumpWidget(wrap(VerifyFailedScreen(
      taskTitle: 'Read 20 pages',
      atMillis: DateTime(2026, 7, 10, 7, 16).millisecondsSinceEpoch,
      imageBytes: kFakeImageBytes,
      cairnNumber: 1,
      stoneCount: 4,
      attemptsRemaining: 2,
      reason: 'No book visible in frame.',
      onRetake: () => retakeCalls++,
      onCancel: () => cancelCalls++,
    )));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't verify"), findsOneWidget);
    expect(find.text('Not verified'), findsOneWidget);
    expect(find.text('No book visible in frame.', findRichText: true), findsOneWidget);
    expect(find.text('2 tries left today'), findsOneWidget);
    expect(find.text('Cairn 1 · 4 stones · no stone placed'), findsOneWidget);
    expect(find.text('Retake photo'), findsOneWidget);

    await tester.tap(find.text('Retake photo'));
    expect(retakeCalls, 1);

    await tester.tap(find.text('Cancel'));
    expect(cancelCalls, 1);
  });

  testWidgets('with zero attempts remaining: shows the static exhausted copy, '
      'not the reason, and a disabled Try again tomorrow button', (tester) async {
    await tester.pumpWidget(wrap(VerifyFailedScreen(
      taskTitle: 'Read 20 pages',
      atMillis: DateTime(2026, 7, 10, 7, 16).millisecondsSinceEpoch,
      imageBytes: kFakeImageBytes,
      cairnNumber: 1,
      stoneCount: 4,
      attemptsRemaining: 0,
      onCancel: () {},
    )));
    await tester.pumpAndSettle();

    expect(
      find.textContaining("You've used all 3 attempts for this task today.",
          findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Try again tomorrow'), findsOneWidget);
    expect(find.text('Attempts reset at midnight'), findsOneWidget);
    expect(find.text('Retake photo'), findsNothing);
    expect(find.text('2 tries left today'), findsNothing);
  });

  testWidgets('with no photo bytes at all (reached directly from precheck): '
      'renders a placeholder instead of crashing', (tester) async {
    await tester.pumpWidget(wrap(VerifyFailedScreen(
      taskTitle: 'Read 20 pages',
      atMillis: DateTime(2026, 7, 10, 7, 16).millisecondsSinceEpoch,
      cairnNumber: 1,
      stoneCount: 4,
      attemptsRemaining: 0,
      onCancel: () {},
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Try again tomorrow'), findsOneWidget);
  });

  testWidgets('a task with zero prior stones falls back to the ghost cairn '
      'illustration instead of crashing', (tester) async {
    await tester.pumpWidget(wrap(VerifyFailedScreen(
      taskTitle: 'Read 20 pages',
      atMillis: DateTime(2026, 7, 10, 7, 16).millisecondsSinceEpoch,
      imageBytes: kFakeImageBytes,
      cairnNumber: 1,
      stoneCount: 0,
      attemptsRemaining: 2,
      reason: 'No task-relevant object visible.',
      onRetake: () {},
      onCancel: () {},
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Cairn 1 · 0 stones · no stone placed'), findsOneWidget);
  });
}
