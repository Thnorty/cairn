import 'package:cairn/src/models/stone_style.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('storedStoneStyleProvider resolves to river with no stored value', () async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(await container.read(storedStoneStyleProvider.future), StoneStyle.river);
  });

  test('effectiveStoneStyleProvider mirrors the stored style when entitled', () async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await SettingsRepository(db).setStoneStyle(StoneStyle.slate);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        debugPremiumOverrideProvider.overrideWith((ref) => true),
      ],
    );
    addTearDown(container.dispose);

    await container.read(storedStoneStyleProvider.future);
    expect(container.read(effectiveStoneStyleProvider), StoneStyle.slate);
  });

  test('effectiveStoneStyleProvider falls back to river for a non-premium user '
      'even with no stored value', () async {
    final db = inMemoryDatabase();
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        debugPremiumOverrideProvider.overrideWith((ref) => false),
      ],
    );
    addTearDown(container.dispose);

    await container.read(storedStoneStyleProvider.future);
    expect(container.read(effectiveStoneStyleProvider), StoneStyle.river);
  });

  group('lapse case', () {
    test(
        'a stored premium style (Basalt) while NOT entitled resolves '
        'effective to river but the stored value is preserved untouched, '
        'and re-entitlement restores it without a re-write', () async {
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await SettingsRepository(db).setStoneStyle(StoneStyle.basalt);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          debugPremiumOverrideProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);

      await container.read(storedStoneStyleProvider.future);

      // Lapsed: renders river, but the stored choice is untouched.
      expect(container.read(effectiveStoneStyleProvider), StoneStyle.river);
      expect(container.read(storedStoneStyleProvider).value, StoneStyle.basalt);

      // Re-entitle (e.g. the subscription resumes): effective flips back to
      // the preserved stored value with no write of any kind.
      container.read(debugPremiumOverrideProvider.notifier).state = true;

      expect(container.read(effectiveStoneStyleProvider), StoneStyle.basalt);
      expect(container.read(storedStoneStyleProvider).value, StoneStyle.basalt);

      // And the underlying persisted row genuinely never changed either.
      expect(await SettingsRepository(db).stoneStyle(), StoneStyle.basalt);
    });
  });
}
