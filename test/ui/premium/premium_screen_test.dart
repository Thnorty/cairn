import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/ui/premium/premium_screen.dart';
import 'package:cairn/src/ui/proof/verification_chrome.dart' show CloseCircleButton;
import 'package:cairn/src/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the Premium screen (`Cairn Premium.dc.html`), pushed via
/// [openPremiumScreen] from a plain placeholder home screen - the same real
/// navigation path every Premium affordance in the app uses (Profile's
/// "Cairn Premium" row, Stats' "Go unlimited"/"Deeper insights", the Daily
/// Limit screen's own "Go unlimited") - so this harness exercises the close
/// button's `Navigator.pop()` against a real route stack rather than a bare
/// `MaterialApp(home: PremiumScreen())`.
void main() {
  Widget wrap() {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => openPremiumScreen(context),
                child: const Text('Open Premium'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpPremium(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Open Premium'));
    await tester.pumpAndSettle();
  }

  /// Whether the plan card keyed [key] is currently rendered as selected:
  /// reads the same border colour/width the widget itself switches on
  /// (`AppColors.sage` at width 2 when selected, vs
  /// `AppColors.premiumUnselectedCardBorder` at width 1.5 otherwise) off the
  /// card's own outer `DecoratedBox`, rather than reaching into the private
  /// `_PlanRadio`/`_RadioCheckPainter` widgets that aren't visible outside
  /// `premium_screen.dart`.
  bool isPlanSelected(WidgetTester tester, Key key) {
    final decoratedBox = tester
        .widgetList<DecoratedBox>(
          find.descendant(of: find.byKey(key), matching: find.byType(DecoratedBox)),
        )
        .first;
    final decoration = decoratedBox.decoration as BoxDecoration;
    final border = decoration.border as Border;
    return border.top.color == AppColors.sage;
  }

  group('content', () {
    testWidgets(
        'renders the eyebrow, headline, all five value-row titles, both '
        'plan cards, and the footer trial button', (tester) async {
      await pumpPremium(tester);

      expect(find.text('CAIRN PREMIUM'), findsOneWidget);
      expect(find.text('Keep every stone, on every peak'), findsOneWidget);

      expect(find.text('Unlimited AI proofs'), findsOneWidget);
      expect(find.text('Cloud photo backup'), findsOneWidget);
      expect(find.text('Deeper insights'), findsOneWidget);
      expect(find.text('Home-screen widgets'), findsOneWidget);
      expect(find.text('Stone styles'), findsOneWidget);

      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);

      expect(find.text('Start 7-day free trial'), findsOneWidget);
    });
  });

  group('plan selection', () {
    testWidgets('Yearly is selected by default and tapping Monthly selects it',
        (tester) async {
      await pumpPremium(tester);

      const yearlyKey = ValueKey('plan-card-yearly');
      const monthlyKey = ValueKey('plan-card-monthly');

      expect(isPlanSelected(tester, yearlyKey), isTrue);
      expect(isPlanSelected(tester, monthlyKey), isFalse);

      // The Monthly card sits below the fold in the default test viewport
      // (this screen's body is a real scrollable), same as Profile's own
      // below-the-fold rows - see profile_screen_test.dart's identical use
      // of ensureVisible before tapping.
      await tester.ensureVisible(find.text('Monthly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly'));
      await tester.pump();

      expect(isPlanSelected(tester, yearlyKey), isFalse);
      expect(isPlanSelected(tester, monthlyKey), isTrue);
    });
  });

  group('footer', () {
    testWidgets('tapping the trial button shows the coming-soon snackbar',
        (tester) async {
      await pumpPremium(tester);

      await tester.tap(find.text('Start 7-day free trial'));
      await tester.pump();

      expect(find.text('Coming soon'), findsOneWidget);
    });
  });

  group('close', () {
    testWidgets('tapping the close-X pops the route', (tester) async {
      await pumpPremium(tester);

      expect(find.byType(PremiumScreen), findsOneWidget);

      await tester.tap(find.byType(CloseCircleButton));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumScreen), findsNothing);
      expect(find.text('Open Premium'), findsOneWidget);
    });
  });
}
