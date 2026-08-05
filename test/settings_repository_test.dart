import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/stone_style.dart';
import 'package:cairn/src/repo/settings_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = inMemoryDatabase();
    repo = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('onboarding-complete flag', () {
    test('a fresh database has not completed onboarding', () async {
      expect(await repo.isOnboardingComplete(), isFalse);
    });

    test('markOnboardingComplete then isOnboardingComplete returns true', () async {
      await repo.markOnboardingComplete();

      expect(await repo.isOnboardingComplete(), isTrue);
    });

    test('markOnboardingComplete is idempotent (safe to call twice)', () async {
      await repo.markOnboardingComplete();
      await repo.markOnboardingComplete();

      expect(await repo.isOnboardingComplete(), isTrue);
    });
  });

  group('stone style', () {
    test('a fresh database defaults to river with no stored value', () async {
      expect(await repo.stoneStyle(), StoneStyle.river);
    });

    test('setStoneStyle then stoneStyle round-trips for every style', () async {
      for (final style in StoneStyle.values) {
        await repo.setStoneStyle(style);
        expect(await repo.stoneStyle(), style);
      }
    });

    test('setStoneStyle is idempotent (safe to call twice with the same '
        'value, an upsert not an insert)', () async {
      await repo.setStoneStyle(StoneStyle.granite);
      await repo.setStoneStyle(StoneStyle.granite);

      expect(await repo.stoneStyle(), StoneStyle.granite);
    });

    test('an unknown value written directly to the row parses back to river '
        'rather than throwing', () async {
      // Bypasses setStoneStyle to simulate a future/corrupted stored value
      // this build's StoneStyle enum doesn't recognise.
      await db.into(db.appSettings).insertOnConflictUpdate(
            const AppSettingsCompanion(
              key: Value('stone_style'),
              value: Value('marble'),
            ),
          );

      expect(await repo.stoneStyle(), StoneStyle.river);
    });
  });

  group('display name', () {
    test('a fresh database has no stored display name', () async {
      expect(await repo.displayName(), isNull);
    });

    test('setDisplayName then displayName round-trips', () async {
      await repo.setDisplayName('Sam');

      expect(await repo.displayName(), 'Sam');
    });

    test('setDisplayName trims surrounding whitespace before storing',
        () async {
      await repo.setDisplayName('  Sam  ');

      expect(await repo.displayName(), 'Sam');
    });

    test('setDisplayName is idempotent (safe to call twice, an upsert not '
        'an insert) and the later call wins', () async {
      await repo.setDisplayName('Sam');
      await repo.setDisplayName('Riley');

      expect(await repo.displayName(), 'Riley');
    });

    test('setDisplayName with a whitespace-only value is a no-op: any '
        'existing stored name is left untouched', () async {
      await repo.setDisplayName('Sam');
      await repo.setDisplayName('   ');

      expect(await repo.displayName(), 'Sam');
    });

    test('setDisplayName with a whitespace-only value on a fresh database '
        'writes nothing: displayName still resolves to null', () async {
      await repo.setDisplayName('   ');

      expect(await repo.displayName(), isNull);
    });

    test('a whitespace-only value written directly to the row (bypassing '
        'setDisplayName) reads back as null, not as a blank name', () async {
      await db.into(db.appSettings).insertOnConflictUpdate(
            const AppSettingsCompanion(
              key: Value('display_name'),
              value: Value('   '),
            ),
          );

      expect(await repo.displayName(), isNull);
    });
  });
}
