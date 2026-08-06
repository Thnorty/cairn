import 'package:drift/drift.dart';

import '../db/database.dart';
import '../models/stone_style.dart';
import '../models/occurrence.dart' show timeOfDayFromHHmm;

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
  static const _falseValue = 'false';
  static const _stoneStyleKey = 'stone_style';
  static const _displayNameKey = 'display_name';
  static const _remindersEnabledKey = 'reminders_enabled';
  static const _defaultReminderTimeKey = 'default_reminder_time';
  static const _streakWarningsEnabledKey = 'streak_warnings_enabled';

  /// Fallback default reminder time (24-hour "HH:mm") when nothing valid is
  /// stored - the untimed slot 0's reminder time until the user picks their
  /// own.
  static const String defaultReminderTimeFallback = '09:00';

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

  /// Whether per-occurrence reminders and streak-at-risk warnings are
  /// enabled at all. False for a fresh database (no row yet) or any stored
  /// value other than the exact sentinel [_trueValue] - nothing fires until
  /// the user opts in (see the notification planner's own doc comment).
  Future<bool> remindersEnabled() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(_remindersEnabledKey)))
        .getSingleOrNull();
    return row?.value == _trueValue;
  }

  /// Persists whether reminders are enabled. Idempotent upsert, same
  /// reasoning as [markOnboardingComplete]/[setStoneStyle].
  Future<void> setRemindersEnabled(bool enabled) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion(
            key: const Value(_remindersEnabledKey),
            value: Value(enabled ? _trueValue : _falseValue),
          ),
        );
  }

  /// True iff [value] parses as a valid 24-hour "HH:mm" time via
  /// [timeOfDayFromHHmm] - reused rather than writing a second HH:mm parser,
  /// per that function's own doc comment. [timeOfDayFromHHmm] normalizes an
  /// out-of-range hour/minute (e.g. "99:99") via [DateTime]'s own overflow
  /// rollover rather than throwing, so this only actually rejects values
  /// that aren't even numeric "H:M"-shaped strings (missing colon,
  /// non-numeric parts, absent altogether); accepted as a known, narrow gap
  /// since every real caller of [setDefaultReminderTime] is expected to be a
  /// time-picker UI (a later work order) that can only ever produce a
  /// genuinely valid 0-23/0-59 pair in the first place.
  bool _isValidHHmm(String value) {
    try {
      timeOfDayFromHHmm(value);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The stored default reminder time (24-hour "HH:mm") used for a task's
  /// untimed slot 0 (empty `due_times`) when reminders are enabled.
  /// [defaultReminderTimeFallback] for a fresh database (no row yet) or any
  /// stored value that fails [_isValidHHmm] - never throws.
  Future<String> defaultReminderTime() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(_defaultReminderTimeKey)))
        .getSingleOrNull();
    final stored = row?.value;
    if (stored == null || !_isValidHHmm(stored)) {
      return defaultReminderTimeFallback;
    }
    return stored;
  }

  /// Persists [hhmm] as the stored default reminder time. A no-op (nothing
  /// written, any existing stored value left untouched) when [hhmm] fails
  /// [_isValidHHmm] - same "make invalid input hard to persist" principle as
  /// [setDisplayName]'s whitespace-only guard.
  Future<void> setDefaultReminderTime(String hhmm) async {
    if (!_isValidHHmm(hhmm)) return;
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion(
            key: const Value(_defaultReminderTimeKey),
            value: Value(hhmm),
          ),
        );
  }

  /// Whether the evening "streak at risk" warning is enabled - only
  /// meaningful when [remindersEnabled] is also true. True for a fresh
  /// database (no row yet, opt-out rather than opt-in once reminders
  /// themselves are on) or any stored value other than the exact sentinel
  /// [_falseValue].
  Future<bool> streakWarningsEnabled() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(_streakWarningsEnabledKey)))
        .getSingleOrNull();
    if (row == null) return true;
    return row.value != _falseValue;
  }

  /// Persists whether streak-at-risk warnings are enabled. Idempotent
  /// upsert, same reasoning as [markOnboardingComplete]/[setStoneStyle].
  Future<void> setStreakWarningsEnabled(bool enabled) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion(
            key: const Value(_streakWarningsEnabledKey),
            value: Value(enabled ? _trueValue : _falseValue),
          ),
        );
  }
}
