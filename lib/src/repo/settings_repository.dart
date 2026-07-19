import 'package:drift/drift.dart';

import '../db/database.dart';

/// Reads and writes device-local UI settings ([AppSettings], a simple
/// key/value table - see that table's own doc comment for why it is
/// deliberately exempt from this app's sync-ready column convention).
///
/// Currently backs a single flag (`onboarding_complete`), but kept as its
/// own small repository - rather than inlining the query in a provider -
/// so a later setting can be added here without every caller reaching into
/// the database directly, matching how [TaskRepository]/[CompletionRepository]
/// are the sole route to their own tables.
class SettingsRepository {
  final AppDatabase _db;

  SettingsRepository(this._db);

  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _trueValue = 'true';

  /// Whether the first-launch onboarding flow has already been completed.
  /// False for a fresh database (no row yet) or any stored value other than
  /// the exact sentinel [_trueValue] written by [markOnboardingComplete].
  Future<bool> isOnboardingComplete() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(_onboardingCompleteKey)))
        .getSingleOrNull();
    return row?.value == _trueValue;
  }

  /// Marks the first-launch onboarding flow as complete. Idempotent: an
  /// upsert, so calling this more than once (e.g. a retried tap) never
  /// throws on the key's primary-key constraint.
  Future<void> markOnboardingComplete() async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          const AppSettingsCompanion(
            key: Value(_onboardingCompleteKey),
            value: Value(_trueValue),
          ),
        );
  }
}
