import 'package:drift/drift.dart';

import '../db/database.dart';
import '../models/stone_style.dart';

/// Reads and writes device-local UI settings ([AppSettings], a simple
/// key/value table - see that table's own doc comment for why it is
/// deliberately exempt from this app's sync-ready column convention).
///
/// Backs a handful of flags/choices (onboarding-complete, the chosen stone
/// style), but kept as its own small repository - rather than inlining the
/// query in a provider - so a later setting can be added here without every
/// caller reaching into the database directly, matching how
/// [TaskRepository]/[CompletionRepository] are the sole route to their own
/// tables.
class SettingsRepository {
  final AppDatabase _db;

  SettingsRepository(this._db);

  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _trueValue = 'true';
  static const _stoneStyleKey = 'stone_style';

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

  /// The *stored* stone style choice (see [StoneStyle]'s own doc comment on
  /// stored vs. effective). [StoneStyle.river] for a fresh database (no row
  /// yet) or any stored value [StoneStyle.fromStored] doesn't recognise.
  Future<StoneStyle> stoneStyle() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(_stoneStyleKey)))
        .getSingleOrNull();
    return StoneStyle.fromStored(row?.value);
  }

  /// Persists [style] as the stored stone style choice. Idempotent upsert,
  /// same reasoning as [markOnboardingComplete]. This alone never affects
  /// what's actually *rendered* - see [StoneStyle]'s doc comment - the
  /// caller (the Stone Style picker's Apply button) is responsible for
  /// refreshing whatever provider watches this.
  Future<void> setStoneStyle(StoneStyle style) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion(
            key: const Value(_stoneStyleKey),
            value: Value(style.toStored),
          ),
        );
  }
}
