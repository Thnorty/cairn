import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/ui/proof/verify_pending_screen.dart';
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

  testWidgets('shows the pending copy, offline reassurance, streak-safe and '
      'held-metres chips, all from the given data', (tester) async {
    var backCalls = 0;
    await tester.pumpWidget(wrap(VerifyPendingScreen(
      taskTitle: 'Meditate 10 min',
      completedAtMillis: DateTime(2026, 7, 10, 7, 16).millisecondsSinceEpoch,
      imageBytes: kFakeImageBytes,
      heldMetres: 13,
      onBackToToday: () => backCalls++,
    )));
    await tester.pumpAndSettle();

    expect(find.text("Saved. We'll verify it soon."), findsOneWidget);
    expect(find.textContaining('Meditate 10 min'), findsOneWidget);
    expect(find.text('Awaiting verification'), findsOneWidget);
    // Both fragments live in the same Text.rich (bold lead + body), so a
    // full exact match on either one alone wouldn't match.
    expect(find.textContaining('No connection right now.'), findsOneWidget);
    expect(
      find.textContaining(
        "Your proof is saved on this device - we'll verify it automatically "
        "the moment you're back online.",
      ),
      findsOneWidget,
    );
    expect(find.text('Streak safe'), findsOneWidget);
    expect(find.text('counts today'), findsOneWidget);
    expect(find.text('13 m held'), findsOneWidget);
    expect(find.text('lands on verify'), findsOneWidget);
    expect(find.text('Back to Today'), findsOneWidget);

    await tester.tap(find.text('Back to Today'));
    expect(backCalls, 1);
  });

  testWidgets('formats held metres with the locale thousands separator', (tester) async {
    await tester.pumpWidget(wrap(VerifyPendingScreen(
      taskTitle: 'Read',
      completedAtMillis: DateTime(2026, 7, 10, 7, 16).millisecondsSinceEpoch,
      imageBytes: kFakeImageBytes,
      heldMetres: 1100,
      onBackToToday: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('1,100 m held'), findsOneWidget);
  });
}
