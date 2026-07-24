import 'package:flutter/foundation.dart';

/// Billing period for a subscription plan.
enum PremiumPeriod { monthly, annual }

/// An immutable value type representing a subscription plan for the paywall UI.
@immutable
class PremiumPlan {
  /// Opaque store identifier used for purchasing (e.g. RevenueCat package ID).
  final String id;

  /// Billing period for this plan (monthly or annual).
  final PremiumPeriod period;

  /// Store-localized total price string (e.g. "$27.99" or "GBP 3.99").
  final String priceString;

  const PremiumPlan({
    required this.id,
    required this.period,
    required this.priceString,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PremiumPlan &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          period == other.period &&
          priceString == other.priceString;

  @override
  int get hashCode => Object.hash(id, period, priceString);
}

/// Available subscription plans offered by the store.
@immutable
class PremiumOffering {
  final List<PremiumPlan> plans;

  const PremiumOffering({required this.plans});

  /// Convenience getter returning the first monthly plan, or null if absent.
  PremiumPlan? get monthly =>
      plans.cast<PremiumPlan?>().firstWhere(
            (p) => p?.period == PremiumPeriod.monthly,
            orElse: () => null,
          );

  /// Convenience getter returning the first annual plan, or null if absent.
  PremiumPlan? get annual =>
      plans.cast<PremiumPlan?>().firstWhere(
            (p) => p?.period == PremiumPeriod.annual,
            orElse: () => null,
          );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PremiumOffering &&
          runtimeType == other.runtimeType &&
          listEquals(plans, other.plans);

  @override
  int get hashCode => Object.hashAll(plans);
}

/// Sealed result type for purchase and restore operations.
sealed class PremiumPurchaseOutcome {
  const PremiumPurchaseOutcome();
}

/// Purchase or restore succeeded. [isPremium] indicates whether active
/// entitlements were granted.
class PremiumPurchaseSucceeded extends PremiumPurchaseOutcome {
  final bool isPremium;

  const PremiumPurchaseSucceeded(this.isPremium);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PremiumPurchaseSucceeded &&
          runtimeType == other.runtimeType &&
          isPremium == other.isPremium;

  @override
  int get hashCode => isPremium.hashCode;
}

/// User backed out of the store payment dialog. This is not an error and
/// the UI must treat it as a silent no-op.
class PremiumPurchaseCancelled extends PremiumPurchaseOutcome {
  const PremiumPurchaseCancelled();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PremiumPurchaseCancelled && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Purchase or restore failed with an error message.
class PremiumPurchaseFailed extends PremiumPurchaseOutcome {
  final String message;

  const PremiumPurchaseFailed(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PremiumPurchaseFailed &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}

/// Seam for subscription and entitlement management (Phase 5).
///
/// Provides reactive access to premium entitlement status, offerings,
/// purchasing, and identity association.
///
/// Same pattern as [SyncTransport]: an abstract seam, an unconfigured inert
/// implementation ([UnconfiguredPremiumService]), and an in-memory fake for
/// tests ([FakePremiumService]).
abstract class PremiumService {
  /// Reactive entitlement status stream.
  ///
  /// Emits the current entitlement value immediately on listen and again on
  /// every change.
  Stream<bool> get isPremiumStream;

  /// Loads available subscription offerings from the store, or null when
  /// none are available or the billing service is unconfigured.
  Future<PremiumOffering?> loadOfferings();

  /// Attempts to purchase the given [plan].
  Future<PremiumPurchaseOutcome> purchase(PremiumPlan plan);

  /// Attempts to restore prior purchases across app reinstalls or devices.
  Future<PremiumPurchaseOutcome> restore();

  /// Associates the billing identity with the app's Supabase [userId].
  Future<void> logIn(String userId);

  /// Reverts to an anonymous billing identity on sign-out.
  Future<void> logOut();
}
