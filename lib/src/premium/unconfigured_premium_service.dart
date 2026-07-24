import 'premium_service.dart';

/// Stand-in service when no billing backend is configured
/// (`AppConfig.isPremiumConfigured == false`, e.g. an unconfigured build).
///
/// Always reports non-premium status, returns null offerings, and fails purchase
/// attempts with a user-facing failure outcome. Safe to build and run with
/// zero external dependencies.
class UnconfiguredPremiumService implements PremiumService {
  const UnconfiguredPremiumService();

  @override
  Stream<bool> get isPremiumStream => Stream<bool>.value(false);

  @override
  Future<PremiumOffering?> loadOfferings() async => null;

  @override
  Future<PremiumPurchaseOutcome> purchase(PremiumPlan plan) async {
    return const PremiumPurchaseFailed('Premium is not available in this build.');
  }

  @override
  Future<PremiumPurchaseOutcome> restore() async {
    return const PremiumPurchaseFailed('Premium is not available in this build.');
  }

  @override
  Future<void> logIn(String userId) async {}

  @override
  Future<void> logOut() async {}
}
