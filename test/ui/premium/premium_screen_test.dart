import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/premium/premium_service.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/ui/premium/premium_screen.dart';
import 'package:cairn/src/ui/proof/verification_chrome.dart' show CloseCircleButton;
import 'package:cairn/src/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_premium_service.dart';

void main() {
  Widget wrap({
    FakePremiumService? fakePremium,
    bool? isPremiumOverride,
  }) {
    final service = fakePremium ?? FakePremiumService();
    return ProviderScope(
      overrides: [
        premiumServiceProvider.overrideWithValue(service),
        if (isPremiumOverride != null)
          debugPremiumOverrideProvider.overrideWith((_) => isPremiumOverride),
      ],
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

  Future<void> pumpPremium(
    WidgetTester tester, {
    FakePremiumService? fakePremium,
    bool? isPremiumOverride,
  }) async {
    await tester.pumpWidget(wrap(
      fakePremium: fakePremium,
      isPremiumOverride: isPremiumOverride,
    ));
    await tester.tap(find.text('Open Premium'));
    await tester.pumpAndSettle();
  }

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

  group('content and tags', () {
    testWidgets(
        'renders real prices on both plan cards, 2 Coming soon tags, and 3 Available now tags',
        (tester) async {
      await pumpPremium(tester);

      expect(find.text('CAIRN PREMIUM'), findsOneWidget);
      expect(find.text('Keep every stone, on every peak'), findsOneWidget);

      // Every canonical value row is still present (the tag counts below
      // only prove how many are tagged, not which rows exist).
      expect(find.text('Unlimited AI proofs'), findsOneWidget);
      expect(find.text('Cloud photo backup'), findsOneWidget);
      expect(find.text('Deeper insights'), findsOneWidget);
      expect(find.text('Home-screen widgets'), findsOneWidget);
      expect(find.text('Stone styles'), findsOneWidget);

      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Start 7-day free trial'), findsOneWidget);

      expect(find.text('\$20.99'), findsOneWidget);
      expect(find.text('\$2.99'), findsOneWidget);

      // Three benefits are live now: "Unlimited AI proofs", "Deeper
      // insights" and "Stone styles". Bump these counts as each remaining
      // roadmap row ships.
      expect(find.text('Available now'), findsNWidgets(3));
      expect(find.text('Coming soon'), findsNWidgets(2));
    });
  });

  group('live pricing', () {
    testWidgets(
        'yearly subtitle renders the live per-month string in local currency, not the USD fallback',
        (tester) async {
      const offering = PremiumOffering(
        plans: [
          PremiumPlan(
            id: 'monthly',
            period: PremiumPeriod.monthly,
            priceString: 'TRY 169.99',
            price: 169.99,
          ),
          PremiumPlan(
            id: 'annual',
            period: PremiumPeriod.annual,
            priceString: 'TRY 1,189.99',
            price: 1189.99,
            pricePerMonthString: 'TRY 99.17',
          ),
        ],
      );
      final fakePremium = FakePremiumService(offerings: offering);

      await pumpPremium(tester, fakePremium: fakePremium);

      expect(find.text('TRY 1,189.99/yr · TRY 99.17/mo'), findsOneWidget);
      expect(find.text(r'$20.99/yr · $1.75/mo'), findsNothing);
      expect(find.text(r'$1.75'), findsNothing);
    });

    testWidgets(
        'footer shows the yearly price with /yr when Yearly is selected, and switches to the monthly price with /mo after selecting Monthly',
        (tester) async {
      await pumpPremium(tester);

      // Yearly is selected by default (design default).
      expect(find.text('Then \$20.99/yr · cancel anytime'), findsOneWidget);
      expect(find.text('Then \$2.99/mo · cancel anytime'), findsNothing);

      await tester.ensureVisible(find.text('Monthly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly'));
      await tester.pump();

      expect(find.text('Then \$2.99/mo · cancel anytime'), findsOneWidget);
      expect(find.text('Then \$20.99/yr · cancel anytime'), findsNothing);
    });

    testWidgets('ribbon renders a computed savings percentage that differs from the 41% design fallback',
        (tester) async {
      const offering = PremiumOffering(
        plans: [
          PremiumPlan(
            id: 'monthly',
            period: PremiumPeriod.monthly,
            priceString: r'$5.00',
            price: 5.00,
          ),
          PremiumPlan(
            id: 'annual',
            period: PremiumPeriod.annual,
            priceString: r'$40.00',
            price: 40.00,
            pricePerMonthString: r'$3.33',
          ),
        ],
      );
      // (1 - 40 / (5 * 12)) * 100 == 33.33..., floored to 33.
      final fakePremium = FakePremiumService(offerings: offering);

      await pumpPremium(tester, fakePremium: fakePremium);

      expect(find.text('BEST VALUE · SAVE 33%'), findsOneWidget);
      expect(find.text('BEST VALUE · SAVE 41%'), findsNothing);
    });

    testWidgets(
        'all four price-bearing fallbacks render the hardcoded design strings when loadOfferings() returns null',
        (tester) async {
      final fakePremium = FakePremiumService(offerings: null);

      await pumpPremium(tester, fakePremium: fakePremium);

      // Yearly plan card price + subtitle fallback.
      expect(find.text(r'$20.99'), findsOneWidget);
      expect(find.text(r'$20.99/yr · $1.75/mo'), findsOneWidget);
      // Best value ribbon fallback.
      expect(find.text('BEST VALUE · SAVE 41%'), findsOneWidget);
      // Footer trial subtitle fallback (Yearly selected by default).
      expect(find.text('Then \$20.99/yr · cancel anytime'), findsOneWidget);
    });
  });

  group('plan selection and purchasing', () {
    testWidgets('Yearly is selected by default and tapping Monthly selects it',
        (tester) async {
      await pumpPremium(tester);

      const yearlyKey = ValueKey('plan-card-yearly');
      const monthlyKey = ValueKey('plan-card-monthly');

      expect(isPlanSelected(tester, yearlyKey), isTrue);
      expect(isPlanSelected(tester, monthlyKey), isFalse);

      await tester.ensureVisible(find.text('Monthly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly'));
      await tester.pump();

      expect(isPlanSelected(tester, yearlyKey), isFalse);
      expect(isPlanSelected(tester, monthlyKey), isTrue);
    });

    testWidgets(
        'tapping CTA calls purchase with selected plan (annual by default, then monthly)',
        (tester) async {
      PremiumPlan? purchasedPlan;
      final fakePremium = FakePremiumService()
        ..onPurchase = (plan) {
          purchasedPlan = plan;
          return const PremiumPurchaseSucceeded(true);
        };
      await pumpPremium(tester, fakePremium: fakePremium);

      // Default selection is annual
      await tester.tap(find.text('Start 7-day free trial'));
      await tester.pumpAndSettle();

      expect(fakePremium.purchaseCount, 1);
      expect(purchasedPlan?.id, FakePremiumService.defaultOffering.annual!.id);

      // Re-open premium paywall
      await tester.tap(find.text('Open Premium'));
      await tester.pumpAndSettle();

      // Select monthly
      await tester.ensureVisible(find.text('Monthly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly'));
      await tester.pump();

      await tester.tap(find.text('Start 7-day free trial'));
      await tester.pumpAndSettle();

      expect(fakePremium.purchaseCount, 2);
      expect(purchasedPlan?.id, FakePremiumService.defaultOffering.monthly!.id);
    });

    testWidgets('cancelled purchase shows NO snackbar and leaves screen pushed',
        (tester) async {
      final fakePremium = FakePremiumService()
        ..onPurchase = (_) => const PremiumPurchaseCancelled();

      await pumpPremium(tester, fakePremium: fakePremium);

      await tester.tap(find.text('Start 7-day free trial'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(PremiumScreen), findsOneWidget);
    });

    testWidgets('failed purchase shows its message in a snackbar', (tester) async {
      final fakePremium = FakePremiumService()
        ..onPurchase = (_) => const PremiumPurchaseFailed('Store error occurred');

      await pumpPremium(tester, fakePremium: fakePremium);

      await tester.tap(find.text('Start 7-day free trial'));
      await tester.pump();

      expect(find.text('Store error occurred'), findsOneWidget);
      expect(find.byType(PremiumScreen), findsOneWidget);
    });
  });

  group('already premium state', () {
    testWidgets('when premium is active, plan cards/CTA are replaced by entitlement panel and Manage subscription',
        (tester) async {
      final fakePremium = FakePremiumService()..setPremium(true);
      await pumpPremium(tester, fakePremium: fakePremium);

      expect(find.byKey(const ValueKey('plan-card-yearly')), findsNothing);
      expect(find.byKey(const ValueKey('plan-card-monthly')), findsNothing);
      expect(find.text('Start 7-day free trial'), findsNothing);

      expect(find.text("You're on Cairn Premium"), findsOneWidget);
      expect(find.text('Unlimited AI proofs active.'), findsOneWidget);
      expect(find.text('Manage subscription'), findsOneWidget);
    });
  });

  group('restore', () {
    testWidgets('restore with no entitlement shows "No purchases to restore."',
        (tester) async {
      final fakePremium = FakePremiumService()
        ..onRestore = () => const PremiumPurchaseSucceeded(false);

      await pumpPremium(tester, fakePremium: fakePremium);

      await tester.tap(find.text('Restore purchase'));
      await tester.pump();

      expect(find.text('No purchases to restore.'), findsOneWidget);
      expect(find.byType(PremiumScreen), findsOneWidget);
    });
  });

  group('close', () {
    // The close-X sitting top-left is a deliberate, documented deviation
    // from Cairn Premium.dc.html's own top-right X (every close/dismiss
    // control in this app sits top-left) - see PremiumScreen's own comment.
    // Guarded here so a later change cannot silently undo it.
    testWidgets('the close-X sits top-left, mirroring VerificationHeader',
        (tester) async {
      await pumpPremium(tester);

      final align = tester.widget<Align>(
        find
            .ancestor(of: find.byType(CloseCircleButton), matching: find.byType(Align))
            .first,
      );
      expect(align.alignment, AlignmentDirectional.centerStart);
    });

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
