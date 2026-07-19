import 'package:flutter/widgets.dart';

/// Colour tokens extracted from the canonical `design/*.dc.html` files.
///
/// Every value here is copied from a hex/rgba literal that appears in one
/// or more of the design files (primarily `Cairn Home.dc.html`, cross
/// checked against the Verify Result/Pending/Failed, Daily Limit, Profile
/// and Trail files). Nothing here is invented: where a colour only exists
/// as an `rgba(...)` with alpha, the ARGB hex below is that same r/g/b with
/// the alpha channel converted to a byte (`round(alpha * 255)`), noted in
/// the trailing comment as the original CSS value for traceability.
///
/// This is a plain static-const token table (not a `ThemeExtension`)
/// because every screen in the designs shares one fixed warm-parchment
/// palette; there is no dark-mode/theme-swap requirement to design for.
/// [`CairnTokens`] (in `app_theme.dart`) exposes the subset of these that
/// map onto idiomatic `Theme.of(context)` lookups; reach for `AppColors`
/// directly for the bespoke tokens (chips, stones, cards) that don't.
abstract final class AppColors {
  // ---- Screen base -------------------------------------------------------

  /// Base screen background, before any wash/contour overlay. Constant
  /// across every screen in the designs.
  static const Color screenBackground = Color(0xFFE9E1D3);

  // ---- Ink / text ---------------------------------------------------------

  /// Primary ink: greeting headline, task titles, verified-result titles.
  static const Color inkPrimary = Color(0xFF2C2924);

  /// Slightly darker ink used for the status bar, active tab, and the
  /// Cairn wordmark. Distinct from [inkPrimary] in the source files (the
  /// two are used side by side, e.g. wordmark vs. greeting), so kept as a
  /// separate token rather than collapsed into one.
  static const Color inkStrong = Color(0xFF33302B);

  /// Dimmed ink used for a not-yet-due task's title (the scheduled card).
  static const Color inkDimmed = Color(0xFF453F35);

  /// Close/back icon stroke colour.
  static const Color iconMuted = Color(0xFF4A453C);

  /// Muted body text: captions, meta lines, chip labels, reason text.
  static const Color textMuted = Color(0xFF6A6153);

  /// Fainter secondary text: chevrons, ghost button labels, "next" hints.
  static const Color textFaint = Color(0xFF8A8072);

  /// Empty Today's body copy colour (distinct from [textMuted]).
  static const Color emptyStateBodyText = Color(0xFF5F5647);

  /// Inactive tab icon/label colour.
  static const Color textInactive = Color(0xFFA19785);

  /// Uppercase, letter-spaced section label colour (TODAY, VERIFICATION,
  /// Profile, Trail of, etc).
  static const Color labelGrey = Color(0xFF9C917E);

  /// Small clock-glyph stroke colour (scheduled pill icon).
  static const Color clockGlyph = Color(0xFF7A7062);

  /// Off-white used for icon glyphs drawn on top of saturated colour
  /// (checkmark on the sage seal/chip, clock glyph on the awaiting chip).
  static const Color richCream = Color(0xFFF2EFE6);

  // ---- Terracotta (primary action) ----------------------------------------

  static const Color terracotta = Color(0xFFA6603D);
  static const Color terracottaLight = Color(0xFFC07A54);

  /// Text colour on the tinted terracotta pill ("New habit").
  static const Color terracottaChipText = Color(0xFF9A5636);

  /// Light text drawn on top of the terracotta gradient buttons.
  static const Color buttonText = Color(0xFFF6EFE6);

  /// rgba(166,96,61,.12) - tinted pill background.
  static const Color terracottaTintBg = Color(0x1FA6603D);

  /// rgba(166,96,61,.3) - tinted pill border.
  static const Color terracottaTintBorder = Color(0x4DA6603D);

  /// rgba(178,124,92,.14) - failed-verification reason banner background.
  static const Color clayTintBg = Color(0x24B27C5C);

  /// rgba(143,86,54,.9) - "Not verified" chip background on the photo.
  static const Color notVerifiedChipBg = Color(0xE68F5636);

  // ---- Sage (success) -----------------------------------------------------

  static const Color sage = Color(0xFF6D8056);
  static const Color sageLight = Color(0xFF96A776);
  static const Color sageText = Color(0xFF5F7A45);

  /// "Verified · 7:14 AM" chip label colour.
  static const Color sageTextStrong = Color(0xFF566C44);

  /// "Verified" title colour on the verification-result screen.
  static const Color sageHeading = Color(0xFF4C6138);

  /// Bold lead-in ("Looks good.") on the accepted-reason banner.
  static const Color sageReasonBold = Color(0xFF42552C);

  /// Body text on the accepted-reason banner.
  static const Color sageReasonBody = Color(0xFF4F5E3C);

  /// rgba(122,141,96,.16) - verified chip background.
  static const Color sageChipBg = Color(0x297A8D60);

  /// rgba(122,141,96,.13) - accepted-reason banner background.
  static const Color sageBannerBg = Color(0x217A8D60);

  /// rgba(122,141,96,.18) - glow ring behind a freshly-placed sage stone.
  static const Color sageRing = Color(0x2E7A8D60);

  // ---- Clay (failure) -------------------------------------------------------

  static const Color clay = Color(0xFFB0704E);
  static const Color clayLight = Color(0xFFCF9877);

  /// "Couldn't verify" title colour.
  static const Color clayHeading = Color(0xFF8F5636);

  /// Reason-banner icon stroke on the failed-verification screen.
  static const Color clayIcon = Color(0xFFA06A45);

  /// Reason-banner body text on the failed-verification screen.
  static const Color clayText = Color(0xFF6B4A34);

  // ---- Pending / awaiting verification --------------------------------------

  static const Color pendingSealLight = Color(0xFFC3B49A);
  static const Color pendingSealDark = Color(0xFFA2937A);

  /// Small icon-circle background inside the "Awaiting verification" chip.
  static const Color pendingIconBg = Color(0xFFA89A84);

  /// "Saved. We'll verify it soon." title colour.
  static const Color pendingHeading = Color(0xFF544B3B);

  /// rgba(120,108,88,.14) - awaiting chip background (on a card).
  static const Color awaitingChipBg = Color(0x24786C58);

  /// rgba(38,35,30,.62) - awaiting chip background on top of a photo.
  static const Color awaitingChipOnPhotoBg = Color(0x9E26231E);

  /// rgba(160,148,126,.2) - glow ring behind an unverified top stone.
  static const Color pendingRing = Color(0x33A0947E);

  // ---- Card surfaces --------------------------------------------------------

  /// Primary parchment card gradient (165deg).
  static const Color cardGradientLight = Color(0xFFF3EEE3);
  static const Color cardGradientDark = Color(0xFFE4DCCB);

  /// Dimmed parchment card gradient, used for the not-yet-due (scheduled)
  /// card variant (165deg).
  static const Color cardGradientDimLight = Color(0xFFECE6DA);
  static const Color cardGradientDimDark = Color(0xFFDDD4C2);

  /// rgba(255,255,255,.35) - standard card border.
  static const Color cardBorder = Color(0x59FFFFFF);

  /// rgba(255,255,255,.25) - dimmed card border.
  static const Color cardBorderDim = Color(0x40FFFFFF);

  /// rgba(255,255,255,.7) / rgba(255,255,255,.55) - top inset highlight
  /// line approximated as a 1px gradient (Flutter has no inset shadow).
  static const Color cardTopHighlight = Color(0xB3FFFFFF);
  static const Color cardTopHighlightDim = Color(0x8CFFFFFF);

  /// Dark hero-card gradient (Profile rank card, 160deg).
  static const Color heroDarkTop = Color(0xFF3A4230);
  static const Color heroDarkBottom = Color(0xFF2C2C22);

  // ---- Buttons / misc borders ------------------------------------------------

  /// rgba(255,255,255,.3) - inset highlight on terracotta buttons.
  static const Color buttonInsetHighlight = Color(0x4DFFFFFF);

  /// rgba(120,108,88,.4) - outlined "Scheduled" pill border.
  static const Color scheduledPillBorder = Color(0x66786C58);

  /// rgba(140,74,42,.6) - terracotta button drop shadow base.
  static const Color buttonShadow = Color(0x998C4A2A);

  // ---- Stone gradients (the cairn stack) -------------------------------------

  /// Default stone gradient pairs (light, dark), 158deg, cycled by stone
  /// index. Sourced verbatim from the Home file's mini-cairn stone list.
  static const List<(Color, Color)> stoneGradients = [
    (Color(0xFFDCD5C7), Color(0xFFB9B0A0)),
    (Color(0xFFD6CFC0), Color(0xFFB3A999)),
    (Color(0xFFDCD5C7), Color(0xFFB6AD9C)),
    (Color(0xFFD4CDBD), Color(0xFFB0A695)),
    (Color(0xFFDED7C9), Color(0xFFB8AF9E)),
    (Color(0xFFD6CFC0), Color(0xFFB1A796)),
    (Color(0xFFDDD6C8), Color(0xFFB5AC9B)),
    (Color(0xFFD8D1C2), Color(0xFFAEA491)),
  ];

  /// Muted/dimmed stone gradient pairs, for the not-yet-due cairn variant.
  /// Sourced from the Home file's scheduled-card (Card 3) mini-cairn.
  static const List<(Color, Color)> stoneGradientsMuted = [
    (Color(0xFFD3CCBD), Color(0xFFB0A695)),
    (Color(0xFFCFC8B8), Color(0xFFACA291)),
    (Color(0xFFD3CCBC), Color(0xFFADA391)),
    (Color(0xFFCFC8B8), Color(0xFFA99F8D)),
    (Color(0xFFD1CABA), Color(0xFFAAA08E)),
    (Color(0xFFCDC6B6), Color(0xFFA59B89)),
  ];

  /// Freshly-placed/highlighted top stone (sage), 158deg.
  static const Color stoneSageLight = Color(0xFF96A776);
  static const Color stoneSageDark = Color(0xFF6D8056);

  /// Placed-but-unverified top stone (muted clay), 158deg - Home Card 1b's
  /// mini-cairn. Distinct from [pendingSealLight]/[pendingSealDark] (which
  /// tint the pending chip's icon circle, not a stone).
  static const Color stonePendingLight = Color(0xFFCDBFA6);
  static const Color stonePendingDark = Color(0xFFA89A80);

  /// rgba(60,50,35,.16) / rgba(60,50,35,.14) - stone drop shadow.
  static const Color stoneShadow = Color(0x293C3223);
  static const Color stoneShadowMuted = Color(0x243C3223);

  /// rgba(50,42,30,.26) / rgba(50,42,30,.24) - the soft ground shadow an
  /// oval elliptical smudge each cairn stack sits on.
  static const Color groundShadow = Color(0x42322A1E);
  static const Color groundShadowMuted = Color(0x3D322A1E);

  // ---- Shared card/photo drop shadows -----------------------------------------

  /// rgba(60,50,35, x) - the warm umber used for every card/photo drop
  /// shadow layer in the designs; only the alpha differs per layer.
  static const Color umberShadowBase = Color(0xFF3C3223);

  // ---- New Habit screen ---------------------------------------------------

  /// `#f0ece1` - text on the selected (dark) recurrence-type chip.
  static const Color darkChipText = Color(0xFFF0ECE1);

  /// `#f4f0e6` - text on a selected sage day-circle (the weekly day
  /// picker, the monthly day-of-month grid, and the monthly nth-weekday
  /// mode's weekday row all share this one selected-circle treatment).
  static const Color sageChipText = Color(0xFFF4F0E6);

  /// 165deg `#f2ede2 -> #e5ddcc` - inactive recurrence-type chip fill.
  static const Color chipInactiveLight = Color(0xFFF2EDE2);
  static const Color chipInactiveDark = Color(0xFFE5DDCC);

  /// 155deg `#f3eee3 -> #e2dac9` - unselected day-circle fill, reused by
  /// the same three controls as [sageChipText].
  static const Color circleInactiveLight = Color(0xFFF3EEE3);
  static const Color circleInactiveDark = Color(0xFFE2DAC9);

  /// rgba(255,255,255,.5) - the unselected day-circle/chip border, shared
  /// by the weekly day picker, the monthly day-of-month grid, the monthly
  /// nth-weekday mode's weekday row, and its "Which week" ordinal chips.
  static const Color circleBorder = Color(0x80FFFFFF);

  /// rgba(122,141,96,.1) - the sage-tinted panel background wrapping each
  /// recurrence type's extra controls (the weekly day picker, the monthly
  /// mode panel, the once date panel).
  static const Color sagePanelBg = Color(0x1A7A8D60);

  /// `#5f6b4c` - sage-toned panel label text ("On these days", "Day of
  /// the month", "Which week", "Which day", "On this date").
  static const Color sagePanelLabelText = Color(0xFF5F6B4C);

  /// rgba(120,108,88,.12) - the monthly-mode pill-toggle track background.
  static const Color pillToggleTrackBg = Color(0x1F786C58);

  /// 155deg `#f5f1e7 -> #e8e0d0` - the active segment of the monthly-mode
  /// pill toggle.
  static const Color pillToggleActiveLight = Color(0xFFF5F1E7);
  static const Color pillToggleActiveDark = Color(0xFFE8E0D0);

  /// rgba(120,108,88,.16) - the small "+" icon-circle background on
  /// "+ Add a time".
  static const Color addTimeIconBg = Color(0x29786C58);

  // ---- Profile screen -----------------------------------------------------

  /// `#f0ece1` - the rank hero's primary text colour (inherited by its tier
  /// title/"m gained" line's container) and its current-tier ladder-icon
  /// inner dot fill.
  static const Color heroInk = Color(0xFFF0ECE1);

  /// `#f2ede2` - the rank hero's mountain-badge icon stroke: a distinct,
  /// near-white cream from [heroInk], verbatim from the source file's own
  /// two close-but-different creams (not a typo/duplicate).
  static const Color heroMountainStroke = Color(0xFFF2EDE2);

  /// `#8a97b0` / `#5f6d88` - the rank hero's circular mountain-badge
  /// gradient (155deg), distinct from the account-status row's avatar
  /// gradient below.
  static const Color heroBadgeLight = Color(0xFF8A97B0);
  static const Color heroBadgeDark = Color(0xFF5F6D88);

  /// `#c2cdae` - the rank hero's "CURRENT RANK" label and the progress
  /// row's bold "N m to Next" text; also the progress-bar fill's gradient
  /// end (see [heroProgressFillStart]).
  static const Color heroLabelSage = Color(0xFFC2CDAE);

  /// `#cdc9ba` - the rank hero's "N m gained" line and the progress row's
  /// plain current-tier text.
  static const Color heroSubtext = Color(0xFFCDC9BA);

  /// rgba(240,236,225,.5) - the rank hero's withheld-metres line ("+N m
  /// awaiting verification") text/icon, shown only while
  /// `pendingAltitude() > 0`.
  static const Color heroPendingText = Color(0x80F0ECE1);

  /// rgba(255,255,255,.14) - the rank hero's progress-bar track background.
  static const Color heroProgressTrackBg = Color(0x24FFFFFF);

  /// `#9aa87c` - the rank hero's progress-bar fill gradient start (end is
  /// [heroLabelSage]).
  static const Color heroProgressFillStart = Color(0xFF9AA87C);

  /// rgba(255,255,255,.6) - the top inset-highlight line on the rank-ladder
  /// and settings list panels and the Cairn Premium row (distinct from
  /// [cardTopHighlight]'s .7/.55, which the irregular task cards use).
  static const Color panelTopHighlight = Color(0x99FFFFFF);

  /// rgba(255,255,255,.4) - the rank-ladder/settings list panel border
  /// (distinct from [cardBorder]'s .35).
  static const Color panelBorder = Color(0x66FFFFFF);

  /// rgba(120,108,88,.14) - the hairline divider between rows in a list
  /// panel (the rank ladder, the settings list).
  static const Color hairlineDivider = Color(0x24786C58);

  /// rgba(122,141,96,.18) - a passed (already-reached) rank tier's icon
  /// circle background in the ladder. Numerically identical to
  /// [sageRing] (same source rgb/alpha) but kept as its own named token
  /// since the two mark unrelated things.
  static const Color achievedTierIconBg = Color(0x2E7A8D60);

  /// rgba(120,108,88,.35) - a not-yet-reached rank tier's outline-circle
  /// border in the ladder.
  static const Color futureTierBorder = Color(0x59786C58);

  /// rgba(178,124,92,.1) / rgba(178,124,92,.2) - the "Climbing anonymously"
  /// account-status row's background/border.
  static const Color accountStatusBg = Color(0x1AB27C5C);
  static const Color accountStatusBorder = Color(0x33B27C5C);

  /// `#5c5344` - the account-status row's person-icon stroke.
  static const Color accountIconStroke = Color(0xFF5C5344);

  /// `#c9c0b0` / `#a99f8c` - the account-status row's avatar-circle
  /// gradient (150deg; the same pair Home's greeting avatar uses, kept as
  /// its own token here since that one is a private literal in
  /// `home_screen.dart`).
  static const Color accountAvatarLight = Color(0xFFC9C0B0);
  static const Color accountAvatarDark = Color(0xFFA99F8C);

  /// rgba(122,141,96,.3) - the Cairn Premium row's border.
  static const Color premiumBorder = Color(0x4D7A8D60);

  /// `#f4efe4` / `#e6decb` - the Cairn Premium row's background gradient
  /// (160deg).
  static const Color premiumBgLight = Color(0xFFF4EFE4);
  static const Color premiumBgDark = Color(0xFFE6DECB);

  // ---- Trail screen --------------------------------------------------------

  /// `#6f685b` - a broken cairn's "Cairn N" title colour on the Trail
  /// screen, distinct from a capped cairn's darker [inkDimmed] title.
  static const Color trailBrokenCairnTitle = Color(0xFF6F685B);

  /// `#a19795` - the "WHERE YOU STARTED" trailhead marker's text colour.
  /// One byte off [textInactive] (`#a19785`) in the source file; kept as
  /// its own token rather than collapsed, per this file's own precedent of
  /// preserving literal per-use distinctions.
  static const Color trailWhereYouStartedText = Color(0xFFA19795);

  // ---- Stats screen ---------------------------------------------------------

  /// rgba(120,108,88,.18) - a future weekday bar's faint fill on the Stats
  /// screen's "This week" chart.
  static const Color statsFutureBarBg = Color(0x2E786C58);

  /// rgba(120,108,88,.2) - shared by the Stats screen's unfilled
  /// proofs-used-today segments and the "Deeper insights" card's lock-icon
  /// circle background (identical rgba value at both source sites).
  static const Color statsMutedFillBg = Color(0x33786C58);

  /// rgba(255,255,255,.3) - the Stats screen's locked "Deeper insights"
  /// card border. Numerically identical to [buttonInsetHighlight] (same
  /// source rgba) but kept as its own token since the two mark unrelated
  /// things, per this file's own precedent (see [achievedTierIconBg]).
  static const Color statsLockedCardBorder = Color(0x4DFFFFFF);

  /// `#b7ad99` - the Stats screen's blurred faux-chart bars behind the
  /// locked "Deeper insights" card.
  static const Color statsFauxChartBar = Color(0xFFB7AD99);

  /// `#ece7db` / `#ddd4c2` - the Stats screen's locked "Deeper insights"
  /// card background gradient (165deg).
  static const Color statsLockedCardBgLight = Color(0xFFECE7DB);
  static const Color statsLockedCardBgDark = Color(0xFFDDD4C2);

  // ---- Premium screen -------------------------------------------------------

  /// rgba(150,166,120,.22) - the Premium screen's top sage wash tint (its
  /// first radial wash), transparent counterpart for that gradient's second
  /// stop.
  static const Color premiumSageWash = Color(0x3896A678);

  /// rgba(90,100,72,.05) - the Premium screen's own sage-tinted topographic
  /// contour ring colour (`Cairn Premium.dc.html`'s own repeating-radial-
  /// gradient tint), distinct from Home's neutral warm-ink tint.
  static const Color premiumContourRing = Color(0x0D5A6448);

  /// `#f4f0e6` - text drawn on a solid sage fill on the Premium screen (the
  /// "Best value" ribbon label and the selected Yearly plan card's filled
  /// radio checkmark). One byte off [richCream] (`#f2efe6`) in the source
  /// file; kept as its own token per this file's precedent of preserving
  /// literal per-use distinctions (see [trailWhereYouStartedText]).
  static const Color premiumOnSageText = Color(0xFFF4F0E6);

  /// `#7a8d5a` / `#5f7444` - the Premium screen's "Best value · save 42%"
  /// ribbon background gradient (155deg).
  static const Color premiumRibbonBgLight = Color(0xFF7A8D5A);
  static const Color premiumRibbonBgDark = Color(0xFF5F7444);

  /// `#7a8d5a` - the Premium screen's "Stone styles" row icon's middle bar.
  /// Numerically identical to [premiumRibbonBgLight] (same source hex) but
  /// kept as its own token since the two mark unrelated things, per this
  /// file's own precedent (see [achievedTierIconBg]).
  static const Color premiumStoneStylesMidBar = Color(0xFF7A8D5A);

  /// rgba(120,108,88,.22) - the Premium screen's unselected (Monthly) plan
  /// card border.
  static const Color premiumUnselectedCardBorder = Color(0x38786C58);

  /// `#c4bbaa` - the Premium screen's footer link-row dot separators.
  static const Color premiumFooterDotColor = Color(0xFFC4BBAA);
}
