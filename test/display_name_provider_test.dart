import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Unit tests for [storedDisplayNameProvider]/[userDisplayNameProvider],
/// mirroring `stone_style_provider_test.dart`'s own recipe for
/// `AppSettings`-backed providers.
void main() {
  test('storedDisplayNameProvider resolves to null with no stored name', () async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(await container.read(storedDisplayNameProvider.future), isNull);
  });

  test('storedDisplayNameProvider resolves to the stored name', () async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await SettingsRepository(db).setDisplayName('Sam');

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(await container.read(storedDisplayNameProvider.future), 'Sam');
  });

  test('userDisplayNameProvider mirrors storedDisplayNameProvider once it '
      'resolves', () async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await SettingsRepository(db).setDisplayName('Riley');

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container.read(storedDisplayNameProvider.future);
    expect(container.read(userDisplayNameProvider), 'Riley');
  });

  test('userDisplayNameProvider is null (the Home fallback-to-Friend case) '
      'when no name has ever been set', () async {
    final db = inMemoryDatabase();
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container.read(storedDisplayNameProvider.future);
    expect(container.read(userDisplayNameProvider), isNull);
  });

  test('a write followed by ref.invalidate(storedDisplayNameProvider) '
      'picks up the new value, the same convention OnboardingNameScreen and '
      'AccountService use', () async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container.read(storedDisplayNameProvider.future);
    expect(container.read(userDisplayNameProvider), isNull);

    await SettingsRepository(db).setDisplayName('Jordan');
    container.invalidate(storedDisplayNameProvider);
    await container.read(storedDisplayNameProvider.future);

    expect(container.read(userDisplayNameProvider), 'Jordan');
  });
}
