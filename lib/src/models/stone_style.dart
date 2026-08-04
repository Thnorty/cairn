/// Which visual style a task's cairn stones are drawn in (`Cairn Stone
/// Styles.dc.html`, Phase 5). Four styles, laid out as a deliberate value
/// ladder lightest to darkest: [river] (the app's original, unnamed stone
/// palette, now given a name - the free default), [granite], [slate],
/// [basalt] - each successively darker/premium.
///
/// This is a pure domain enum: it carries no [Color]/palette data itself
/// (see `lib/src/ui/widgets/cairn_stack.dart`'s private `_paletteFor`,
/// which resolves a style to its `AppColors.*Gradients`/`*GradientsMuted`
/// pair list), matching this codebase's existing layering where `models/`
/// stays Flutter-widget-free and the `ui/` layer owns colour.
///
/// STORED vs EFFECTIVE (decided per this feature's spec, 2026-08-04): a
/// style the user picked is *persisted* forever once premium (surviving a
/// later subscription lapse untouched - see `SettingsRepository.stoneStyle`/
/// `setStoneStyle` and `effectiveStoneStyleProvider` in `providers.dart`),
/// but only *rendered* while the user is currently entitled to premium (or
/// always, for [river], which needs no entitlement). Getting this backwards
/// either strands a paying-then-lapsed user's saved choice unrendered
/// forever even after they re-subscribe, or silently destroys it the moment
/// they lapse - both wrong. `effectiveStoneStyleProvider` is the one place
/// that reconciles the two; every screen that draws a themed [CairnStack]
/// should watch that provider, never the raw stored value directly (the
/// Stone Style picker is the one deliberate exception, since it needs to
/// show the user their own saved-but-currently-locked choice as still
/// selected there).
enum StoneStyle {
  river,
  granite,
  slate,
  basalt;

  /// Parses a value persisted in `AppSettings` (see `SettingsRepository`)
  /// back into a style. Any value other than an exact, known [name] -
  /// including `null` (no row yet), an empty string, or data corrupted by a
  /// future format change - falls back to [river] rather than throwing,
  /// matching this app's existing "an unknown/absent persisted value never
  /// crashes, it degrades to the safe default" precedent (see
  /// `SettingsRepository.isOnboardingComplete`'s own doc comment).
  static StoneStyle fromStored(String? value) {
    return StoneStyle.values.firstWhere(
      (style) => style.name == value,
      orElse: () => StoneStyle.river,
    );
  }

  /// The value to persist for this style in `AppSettings` - just [name],
  /// but named for symmetry with [fromStored] so call sites never have to
  /// know the underlying representation is the enum's own name.
  String get toStored => name;

  /// Only [river] is free; every other style requires an active premium
  /// entitlement to render or to be newly selected (see this enum's own doc
  /// comment on the stored-vs-effective distinction that entitlement gates).
  bool get requiresPremium => this != StoneStyle.river;
}
