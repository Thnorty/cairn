import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/repo/settings_repository.dart';
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
}
