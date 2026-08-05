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
  static const _displayNameKey = 'display_name';

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

  /// The user's stored display name (Home's greeting/avatar - see
  /// `Cairn Onboarding Name.dc.html`'s doc comment), local to this device
  /// and the source of truth for rendering regardless of whether an account
  /// exists. Null for a fresh database (no row yet), and null - not the raw
  /// stored value - for a whitespace-only stored value: trimmed on read as
  /// well as on write, so a row that somehow ended up empty/whitespace-only
  /// (e.g. written by an older build) reads back as absent rather than as a
  /// blank name.
  Future<String?> displayName() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(_displayNameKey)))
        .getSingleOrNull();
    final value = row?.value;
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Persists [name] as the stored display name, trimmed. A no-op (nothing
  /// written, any existing stored name left untouched) when the trimmed
  /// value is empty: whitespace-only is treated as absent, never stored -
  /// callers that need to be able to clear the name outright would need a
  /// separate affordance, which this app doesn't have (every caller of this
  /// method already guards Continue/Save on the trimmed value being
  /// non-empty). Idempotent upsert otherwise, same reasoning as
  /// [markOnboardingComplete]/[setStoneStyle].
  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion(
            key: const Value(_displayNameKey),
            value: Value(trimmed),
          ),
        );
  }
}
