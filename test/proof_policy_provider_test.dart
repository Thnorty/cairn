import 'package:cairn/src/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('proofPolicyProvider has default dailyCap of 5 when non-premium', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final policy = container.read(proofPolicyProvider);
    expect(policy.dailyCap, equals(5));
  });

  test('proofPolicyProvider resolves dailyCap as null when debugPremiumOverrideProvider is true', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(debugPremiumOverrideProvider.notifier).state = true;
    final policy = container.read(proofPolicyProvider);
    expect(policy.dailyCap, isNull);
  });

  test('proofPolicyProvider resolves dailyCap as 5 when debugPremiumOverrideProvider is false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(debugPremiumOverrideProvider.notifier).state = false;
    final policy = container.read(proofPolicyProvider);
    expect(policy.dailyCap, equals(5));
  });
}
