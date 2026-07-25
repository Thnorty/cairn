import 'package:cairn/src/premium/premium_service.dart';
import 'package:cairn/src/premium/unconfigured_premium_service.dart';
import 'package:cairn/src/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_premium_service.dart';

void main() {
  group('PremiumPlan value equality', () {
    test('instances with identical fields are equal', () {
      const plan1 = PremiumPlan(
        id: 'monthly',
        period: PremiumPeriod.monthly,
        priceString: r'$2.99',
      );
      const plan2 = PremiumPlan(
        id: 'monthly',
        period: PremiumPeriod.monthly,
        priceString: r'$2.99',
      );

      expect(plan1, equals(plan2));
      expect(plan1.hashCode, equals(plan2.hashCode));
    });

    test('instances with different fields are not equal', () {
      const plan1 = PremiumPlan(
        id: 'monthly',
        period: PremiumPeriod.monthly,
        priceString: r'$2.99',
      );
      const plan2 = PremiumPlan(
        id: 'annual',
        period: PremiumPeriod.annual,
        priceString: r'$20.99',
      );

      expect(plan1, isNot(equals(plan2)));
    });
  });

  group('PremiumOffering', () {
    const monthlyPlan = PremiumPlan(
      id: 'plan_m',
      period: PremiumPeriod.monthly,
      priceString: r'$2.99',
    );
    const annualPlan = PremiumPlan(
      id: 'plan_a',
      period: PremiumPeriod.annual,
      priceString: r'$20.99',
    );

    test('resolves monthly and annual convenience getters', () {
      const offering = PremiumOffering(plans: [monthlyPlan, annualPlan]);

      expect(offering.monthly, equals(monthlyPlan));
      expect(offering.annual, equals(annualPlan));
    });

    test('returns null when period is absent', () {
      const offering = PremiumOffering(plans: [monthlyPlan]);

      expect(offering.monthly, equals(monthlyPlan));
      expect(offering.annual, isNull);
    });

    test('value equality over plan list', () {
      const offering1 = PremiumOffering(plans: [monthlyPlan, annualPlan]);
      const offering2 = PremiumOffering(plans: [monthlyPlan, annualPlan]);
      const offering3 = PremiumOffering(plans: [monthlyPlan]);

      expect(offering1, equals(offering2));
      expect(offering1.hashCode, equals(offering2.hashCode));
      expect(offering1, isNot(equals(offering3)));
    });
  });

  group('UnconfiguredPremiumService', () {
    const service = UnconfiguredPremiumService();

    test('isPremiumStream emits false initially', () async {
      final isPremium = await service.isPremiumStream.first;
      expect(isPremium, isFalse);
    });

    test('loadOfferings returns null', () async {
      final offerings = await service.loadOfferings();
      expect(offerings, isNull);
    });

    test('purchase returns PremiumPurchaseFailed', () async {
      const plan = PremiumPlan(
        id: 'test',
        period: PremiumPeriod.monthly,
        priceString: r'$1.00',
      );
      final outcome = await service.purchase(plan);
      expect(outcome, isA<PremiumPurchaseFailed>());
      expect(
        (outcome as PremiumPurchaseFailed).message,
        contains('not available'),
      );
    });

    test('restore returns PremiumPurchaseFailed', () async {
      final outcome = await service.restore();
      expect(outcome, isA<PremiumPurchaseFailed>());
      expect(
        (outcome as PremiumPurchaseFailed).message,
        contains('not available'),
      );
    });

    test('logIn and logOut complete without throwing', () async {
      await expectLater(service.logIn('user_123'), completes);
      await expectLater(service.logOut(), completes);
    });
  });

  group('FakePremiumService', () {
    test('isPremiumStream emits seeded value first', () async {
      final fakeDefault = FakePremiumService();
      expect(await fakeDefault.isPremiumStream.first, isFalse);
      fakeDefault.dispose();

      final fakeTrue = FakePremiumService(isPremium: true);
      expect(await fakeTrue.isPremiumStream.first, isTrue);
      fakeTrue.dispose();
    });

    test('setPremium propagates to stream', () async {
      final fake = FakePremiumService(isPremium: false);
      final emitted = <bool>[];
      final sub = fake.isPremiumStream.listen(emitted.add);

      await Future<void>.delayed(Duration.zero);
      fake.setPremium(true);
      await Future<void>.delayed(Duration.zero);

      expect(emitted, equals([false, true]));

      await sub.cancel();
      fake.dispose();
    });

    test('default purchase flips premium true and succeeds', () async {
      final fake = FakePremiumService(isPremium: false);
      const plan = PremiumPlan(
        id: 'monthly',
        period: PremiumPeriod.monthly,
        priceString: r'$2.99',
      );

      final outcome = await fake.purchase(plan);
      expect(outcome, equals(const PremiumPurchaseSucceeded(true)));
      expect(await fake.isPremiumStream.first, isTrue);
      expect(fake.purchaseCount, equals(1));
      fake.dispose();
    });

    test('default restore returns succeeded with current entitlement', () async {
      final fake = FakePremiumService(isPremium: true);

      final outcome = await fake.restore();
      expect(outcome, equals(const PremiumPurchaseSucceeded(true)));
      expect(fake.restoreCount, equals(1));
      fake.dispose();
    });

    test('custom onPurchase and onRestore handlers execute when set', () async {
      final fake = FakePremiumService(
        onPurchase: (plan) => const PremiumPurchaseCancelled(),
        onRestore: () => const PremiumPurchaseFailed('Restore failed'),
      );

      const plan = PremiumPlan(
        id: 'monthly',
        period: PremiumPeriod.monthly,
        priceString: r'$2.99',
      );

      expect(await fake.purchase(plan), isA<PremiumPurchaseCancelled>());
      expect(await fake.restore(), isA<PremiumPurchaseFailed>());
      fake.dispose();
    });

    test('records logIn and logOut calls', () async {
      final fake = FakePremiumService();

      await fake.logIn('usr_456');
      expect(fake.loggedInUserIds, equals(['usr_456']));

      await fake.logOut();
      expect(fake.logOutCount, equals(1));
      fake.dispose();
    });

    test('loadOfferings returns default offering or custom/null', () async {
      final fakeDefault = FakePremiumService();
      final offerings = await fakeDefault.loadOfferings();
      expect(offerings, equals(FakePremiumService.defaultOffering));
      fakeDefault.dispose();

      final fakeNull = FakePremiumService(offerings: null);
      expect(await fakeNull.loadOfferings(), isNull);
      fakeNull.dispose();
    });
  });

  group('premiumStatusProvider & debugPremiumOverrideProvider', () {
    test('returns override value when debugPremiumOverrideProvider is set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(debugPremiumOverrideProvider.notifier).state = true;
      expect(container.read(premiumStatusProvider), isTrue);

      container.read(debugPremiumOverrideProvider.notifier).state = false;
      expect(container.read(premiumStatusProvider), isFalse);
    });

    test('reflects underlying premiumServiceProvider when override is null', () async {
      final fake = FakePremiumService(isPremium: false);
      addTearDown(fake.dispose);

      final container = ProviderContainer(
        overrides: [
          premiumServiceProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);

      // Keep the derived provider (and its StreamProvider dependency) alive so
      // stream emissions propagate eagerly rather than only on the next read.
      final sub = container.listen(premiumStatusProvider, (_, __) {});
      addTearDown(sub.close);

      // Initially null override, stream emits false
      expect(container.read(debugPremiumOverrideProvider), isNull);
      // Let the stream deliver its initial value (false).
      await Future<void>.delayed(Duration.zero);
      expect(container.read(premiumStatusProvider), isFalse);

      // Flip fake service status; let the emission propagate through the
      // StreamProvider into the derived premiumStatusProvider.
      fake.setPremium(true);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(premiumStatusProvider), isTrue);
    });
  });
}
