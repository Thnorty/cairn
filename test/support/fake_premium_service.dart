import 'dart:async';

import 'package:cairn/src/premium/premium_service.dart';

/// In-memory test fake for [PremiumService].
///
/// Features configurable initial entitlement, offering state, purchase outcomes,
/// and recorded method invocations for assertions.
class FakePremiumService implements PremiumService {
  static const defaultOffering = PremiumOffering(
    plans: [
      PremiumPlan(
        id: 'monthly',
        period: PremiumPeriod.monthly,
        priceString: r'$2.99',
      ),
      PremiumPlan(
        id: 'annual',
        period: PremiumPeriod.annual,
        priceString: r'$20.99',
      ),
    ],
  );

  final _controller = StreamController<bool>.broadcast();
  bool _current;
  final PremiumOffering? _offerings;

  PremiumPurchaseOutcome Function(PremiumPlan)? onPurchase;
  PremiumPurchaseOutcome Function()? onRestore;

  final List<String> loggedInUserIds = [];
  int logOutCount = 0;
  int purchaseCount = 0;
  int restoreCount = 0;

  FakePremiumService({
    bool isPremium = false,
    PremiumOffering? offerings = defaultOffering,
    this.onPurchase,
    this.onRestore,
  })  : _current = isPremium,
        _offerings = offerings;

  @override
  Stream<bool> get isPremiumStream {
    // Emit the current value immediately on listen, then forward live updates.
    // The inner subscription to [_controller] is attached synchronously in
    // onListen (right after seeding the current value), so a setPremium()
    // that lands immediately after listen is never dropped - an async*
    // "yield _current; yield* _controller.stream" would race here and drop
    // an event added in the gap before the yield* attaches its listener.
    // This faithfully models the real addCustomerInfoUpdateListener contract:
    // the latest value first, then every change.
    late final StreamController<bool> out;
    StreamSubscription<bool>? sub;
    out = StreamController<bool>(
      onListen: () {
        out.add(_current);
        sub = _controller.stream.listen(
          out.add,
          onError: out.addError,
          onDone: out.close,
        );
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );
    return out.stream;
  }

  void setPremium(bool value) {
    _current = value;
    _controller.add(value);
  }

  @override
  Future<PremiumOffering?> loadOfferings() async => _offerings;

  @override
  Future<PremiumPurchaseOutcome> purchase(PremiumPlan plan) async {
    purchaseCount++;
    if (onPurchase != null) {
      return onPurchase!(plan);
    }
    setPremium(true);
    return const PremiumPurchaseSucceeded(true);
  }

  @override
  Future<PremiumPurchaseOutcome> restore() async {
    restoreCount++;
    if (onRestore != null) {
      return onRestore!();
    }
    return PremiumPurchaseSucceeded(_current);
  }

  @override
  Future<void> logIn(String userId) async {
    loggedInUserIds.add(userId);
  }

  @override
  Future<void> logOut() async {
    logOutCount++;
  }

  void dispose() {
    _controller.close();
  }
}
