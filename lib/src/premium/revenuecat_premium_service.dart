import 'dart:async';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'premium_service.dart';

/// Real RevenueCat-backed implementation of [PremiumService].
class RevenueCatPremiumService implements PremiumService {
  static const _entitlementId = 'premium';

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _current = false;
  final Map<String, Package> _packagesById = {};

  RevenueCatPremiumService() {
    try {
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
    } catch (_) {}
  }

  void _onCustomerInfo(CustomerInfo info) {
    final isPremium = info.entitlements.active.containsKey(_entitlementId);
    _current = isPremium;
    if (!_controller.isClosed) {
      _controller.add(isPremium);
    }
  }

  @override
  Stream<bool> get isPremiumStream {
    late final StreamController<bool> controller;
    StreamSubscription<bool>? sub;
    controller = StreamController<bool>(
      onListen: () {
        sub = _controller.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.add(_current);
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<PremiumOffering?> loadOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return null;

      final plans = <PremiumPlan>[];

      final monthlyPkg = current.monthly;
      if (monthlyPkg != null) {
        _packagesById[monthlyPkg.identifier] = monthlyPkg;
        plans.add(
          PremiumPlan(
            id: monthlyPkg.identifier,
            period: PremiumPeriod.monthly,
            priceString: monthlyPkg.storeProduct.priceString,
            price: monthlyPkg.storeProduct.price,
            pricePerMonthString: monthlyPkg.storeProduct.pricePerMonthString,
          ),
        );
      }

      final annualPkg = current.annual;
      if (annualPkg != null) {
        _packagesById[annualPkg.identifier] = annualPkg;
        plans.add(
          PremiumPlan(
            id: annualPkg.identifier,
            period: PremiumPeriod.annual,
            priceString: annualPkg.storeProduct.priceString,
            price: annualPkg.storeProduct.price,
            pricePerMonthString: annualPkg.storeProduct.pricePerMonthString,
          ),
        );
      }

      if (plans.isEmpty) return null;
      return PremiumOffering(plans: plans);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PremiumPurchaseOutcome> purchase(PremiumPlan plan) async {
    final pkg = _packagesById[plan.id];
    if (pkg == null) {
      return const PremiumPurchaseFailed(
        'That plan is no longer available. Reload and try again.',
      );
    }
    try {
      await Purchases.purchase(PurchaseParams.package(pkg));
      final info = await Purchases.getCustomerInfo();
      final isPremium = info.entitlements.active.containsKey(_entitlementId);
      return PremiumPurchaseSucceeded(isPremium);
    } catch (e) {
      if (e is PlatformException &&
          PurchasesErrorHelper.getErrorCode(e) ==
              PurchasesErrorCode.purchaseCancelledError) {
        return const PremiumPurchaseCancelled();
      }
      return const PremiumPurchaseFailed(
        'Purchase could not be completed. Please try again.',
      );
    }
  }

  @override
  Future<PremiumPurchaseOutcome> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      final isPremium = info.entitlements.active.containsKey(_entitlementId);
      return PremiumPurchaseSucceeded(isPremium);
    } catch (_) {
      return const PremiumPurchaseFailed(
        'Failed to restore purchases. Please try again.',
      );
    }
  }

  @override
  Future<void> logIn(String userId) async {
    try {
      await Purchases.logIn(userId);
    } catch (_) {}
  }

  @override
  Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } catch (_) {}
  }

  void dispose() {
    _controller.close();
  }
}
