import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/ui/proof/daily_limit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  testWidgets('shows the daily cap (from the policy, not hardcoded) and the '
      'reset pill, and wires both footer actions', (tester) async {
    var goUnlimitedCalls = 0;
    var maybeLaterCalls = 0;
    await tester.pumpWidget(wrap(DailyLimitScreen(
      dailyCap: 5,
      onGoUnlimited: () => goUnlimitedCalls++,
      onMaybeLater: () => maybeLaterCalls++,
    )));
    await tester.pumpAndSettle();

    expect(find.text("That's today's five"), findsOneWidget);
    expect(find.textContaining('5 free AI proofs'), findsOneWidget);
    expect(find.text('Resets at midnight'), findsOneWidget);
    expect(find.text('Go unlimited'), findsOneWidget);
    expect(find.text('Maybe later'), findsOneWidget);

    await tester.tap(find.text('Go unlimited'));
    expect(goUnlimitedCalls, 1);

    await tester.tap(find.text('Maybe later'));
    expect(maybeLaterCalls, 1);
  });

  testWidgets('a different daily cap renders that number, not a hardcoded 5',
      (tester) async {
    await tester.pumpWidget(wrap(DailyLimitScreen(
      dailyCap: 3,
      onGoUnlimited: () {},
      onMaybeLater: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('3 free AI proofs'), findsOneWidget);
    expect(find.textContaining('5 free AI proofs'), findsNothing);
  });

  testWidgets('the close button behaves the same as Maybe later', (tester) async {
    var maybeLaterCalls = 0;
    await tester.pumpWidget(wrap(DailyLimitScreen(
      dailyCap: 5,
      onGoUnlimited: () {},
      onMaybeLater: () => maybeLaterCalls++,
    )));
    await tester.pumpAndSettle();

    // The close (X) button carries MaterialLocalizations' own
    // closeButtonLabel as its semantics label (see CloseCircleButton), so
    // it's found reliably regardless of how many other GestureDetectors
    // (the footer buttons) are on screen.
    final closeLabel = MaterialLocalizations.of(
      tester.element(find.byType(DailyLimitScreen)),
    ).closeButtonLabel;
    await tester.tap(find.bySemanticsLabel(closeLabel));
    expect(maybeLaterCalls, 1);
  });
}
