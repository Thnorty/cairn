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
        'renders real prices on both plan cards, 4 Coming soon tags, and 1 Available now tag',
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

      expect(find.text('\$27.99'), findsOneWidget);
      expect(find.text('\$3.99'), findsOneWidget);

      expect(find.text('Available now'), findsOneWidget);
      expect(find.text('Coming soon'), findsNWidgets(4));
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
