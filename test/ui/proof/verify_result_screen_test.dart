import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/ui/proof/verify_result_screen.dart';
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

  testWidgets('shows the task, time, verifier reason and cairn caption, all '
      'from the given data (nothing hardcoded)', (tester) async {
    var doneCalls = 0;
    await tester.pumpWidget(wrap(VerifyResultScreen(
      taskTitle: 'Read 20 pages',
      completedAtMillis: DateTime(2026, 7, 10, 7, 16).millisecondsSinceEpoch,
      imageBytes: kFakeImageBytes,
      reason: 'An open book with visible printed text.',
      cairnNumber: 1,
      stoneCount: 5,
      onDone: () => doneCalls++,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Verified'), findsOneWidget);
    expect(find.textContaining('Read 20 pages'), findsOneWidget);
    // Both fragments live in the same Text.rich (bold lead + body), so a
    // full exact match on either one alone wouldn't match; textContaining
    // finds each within the combined rendered text.
    expect(find.textContaining('Looks good.'), findsOneWidget);
    expect(
      find.textContaining('An open book with visible printed text.'),
      findsOneWidget,
    );
    expect(find.text('Cairn 1 · 5 stones · new stone placed'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    expect(doneCalls, 1);
  });

  testWidgets('a task with zero prior stones (its very first) still renders',
      (tester) async {
    await tester.pumpWidget(wrap(VerifyResultScreen(
      taskTitle: 'Meditate',
      completedAtMillis: DateTime(2026, 7, 10, 7, 16).millisecondsSinceEpoch,
      imageBytes: kFakeImageBytes,
      reason: 'Looks right.',
      cairnNumber: 1,
      stoneCount: 1,
      onDone: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Cairn 1 · 1 stone · new stone placed'), findsOneWidget);
  });
}
