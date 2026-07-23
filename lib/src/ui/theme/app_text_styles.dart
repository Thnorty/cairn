import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// The two type families used throughout the designs.
///
/// Work Sans is bundled as a single variable font asset declared three
/// times in `pubspec.yaml` (weights 400/500/600); see the comment there.
/// The designs also reference Work Sans 450, which has no static instance
/// in the family - every "450" usage in the source files is mapped to 500
/// here, per the phase-3 spec.
abstract final class AppFontFamilies {
  static const String zillaSlab = 'Zilla Slab';
  static const String workSans = 'Work Sans';
}

/// Text style tokens extracted from `design/*.dc.html`. Sizes, weights and
/// letter-spacing are copied verbatim from the CSS; colours reference
/// [AppColors]. `height` is Flutter's per-fontSize line-height multiplier,
/// the closest equivalent to the CSS `line-height` values in the files.
abstract final class AppTextStyles {
  /// 34px Zilla Slab 600 - Home screen greeting ("Good morning, Sam").
  static const TextStyle greeting = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w600,
    fontSize: 34,
    height: 1.05,
    color: AppColors.inkPrimary,
  );

  /// 30px Zilla Slab 700 - large screen titles (Profile "You", Trail
  /// habit name header).
  static const TextStyle screenTitle = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w700,
    fontSize: 30,
    height: 1.0,
    color: AppColors.inkPrimary,
  );

  /// 27px Zilla Slab 600 - verification result/pending/failed headline.
  static const TextStyle resultTitle = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w600,
    fontSize: 27,
    height: 1.12,
    color: AppColors.inkPrimary,
  );

  /// 22px Zilla Slab 700 - the "Cairn" wordmark.
  static const TextStyle wordmark = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    letterSpacing: 0.2,
    color: AppColors.inkStrong,
  );

  /// 24px Zilla Slab 600 - Empty Today's title ("Your first stone is
  /// waiting").
  static const TextStyle emptyStateTitle = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w600,
    fontSize: 24,
    color: AppColors.inkPrimary,
  );

  /// 14px Work Sans 400 - Empty Today's body copy under [emptyStateTitle].
  static const TextStyle emptyStateBody = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.55,
    color: AppColors.emptyStateBodyText,
  );

  /// 19px Zilla Slab 600 - task title on a card.
  static const TextStyle taskTitle = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w600,
    fontSize: 19,
    height: 1.15,
    color: AppColors.inkPrimary,
  );

  /// Same as [taskTitle] but dimmed, for a not-yet-due (scheduled) card.
  static const TextStyle taskTitleDimmed = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w600,
    fontSize: 19,
    height: 1.15,
    color: AppColors.inkDimmed,
  );

  /// 12px Work Sans 600, uppercase, 2px letter-spacing - section labels
  /// (TODAY, VERIFICATION, the greeting's date line). Callers must pass
  /// already-uppercased text (see the `todaySectionLabel`/
  /// `verificationHeaderLabel` ARB entries): Dart's `toUpperCase()` isn't
  /// locale-aware (breaks Turkish dotted-i), so uppercasing happens once,
  /// in the translated string, not in this style or at render time.
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    letterSpacing: 2,
    color: AppColors.labelGrey,
  );

  /// 13px Work Sans 400 - standard body copy (reason banners, settings
  /// rows).
  static const TextStyle body = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 1.5,
    color: AppColors.textMuted,
  );

  /// 12.5px Work Sans 400 - the smaller meta/caption line under a task
  /// title ("Cairn 2 · 9 stones · new stone placed").
  static const TextStyle caption = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 12.5,
    color: AppColors.textMuted,
  );

  /// 12.5px Work Sans 600 - status chip label.
  static const TextStyle chipLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 12.5,
    color: AppColors.textMuted,
  );

  /// 13px Work Sans 500 - the outlined "Scheduled" pill label.
  static const TextStyle scheduledPillLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    color: AppColors.textMuted,
  );

  /// 16px Work Sans 600 - large footer CTA button label ("Done",
  /// "Retake photo", "Go unlimited").
  static const TextStyle buttonLabelLarge = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: AppColors.buttonText,
  );

  /// 13.5px Work Sans 600 - small inline CTA button label ("Prove it").
  static const TextStyle buttonLabelSmall = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 13.5,
    color: AppColors.buttonText,
  );

  /// 15px Work Sans 600 - medium content-sized CTA button label (Empty
  /// Today's "+ New habit").
  static const TextStyle buttonLabelMedium = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: AppColors.buttonText,
  );

  /// 12.5px Work Sans 600 - tinted pill button label ("New habit").
  static const TextStyle tintedPillLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 12.5,
    color: AppColors.terracottaChipText,
  );

  /// 14.5px Work Sans 600 - plain text/ghost button label ("Cancel",
  /// "Maybe later").
  static const TextStyle textGhostButtonLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 14.5,
    color: AppColors.textMuted,
  );

  /// 10.5px Work Sans 600 - active tab bar label.
  static const TextStyle tabLabelActive = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 10.5,
    color: AppColors.inkStrong,
  );

  /// 10.5px Work Sans 500 - inactive tab bar label.
  static const TextStyle tabLabelInactive = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w500,
    fontSize: 10.5,
    color: AppColors.textInactive,
  );

  /// 11.5px Work Sans 700, 1.5px letter-spacing, uppercase - New Habit's
  /// form section labels ("WHAT ARE YOU PROVING?", "HOW OFTEN?", "TIMES OF
  /// DAY"). Distinct from [sectionLabel] (12px/600/2px letter-spacing):
  /// close but not identical in the source files, faithfully kept as its
  /// own token rather than collapsed into one. Callers must pass
  /// already-uppercased text, same reasoning as [sectionLabel].
  static const TextStyle formSectionLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w700,
    fontSize: 11.5,
    letterSpacing: 1.5,
    color: AppColors.labelGrey,
  );

  /// 14px Work Sans 600 - New Habit's recurrence-type chip label ("Once",
  /// "Daily", "Weekly", "Monthly") and its "+ Add a time" label, inactive-
  /// state colour.
  static const TextStyle recurrenceChipLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: AppColors.textMuted,
  );

  /// 12px Work Sans 600 - New Habit's sage-panel sub-labels ("On these
  /// days", "Day of the month", "Which week", "Which day", "On this
  /// date").
  static const TextStyle panelSubLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    color: AppColors.sagePanelLabelText,
  );

  /// 12px Work Sans 400 - New Habit's helper copy under a section label
  /// ("Each time is one proof...", "Optional - a reminder...").
  static const TextStyle formHelperText = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.4,
    color: AppColors.textMuted,
  );

  /// 11.5px Work Sans 400 - New Habit's smaller inline note under the
  /// day-of-month grid ("Months without this day will use the last day of
  /// the month.").
  static const TextStyle formFinePrint = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 11.5,
    height: 1.4,
    color: AppColors.textFaint,
  );

  // ---- Profile screen -------------------------------------------------

  /// 11px Work Sans 700, 2px letter-spacing, uppercase - the Profile rank
  /// hero's "CURRENT RANK" label. Callers must pass already-uppercased
  /// text, same Turkish dotted-i reason as [sectionLabel].
  static const TextStyle heroLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w700,
    fontSize: 11,
    letterSpacing: 2,
    color: AppColors.heroLabelSage,
  );

  /// 26px Zilla Slab 600 - the Profile rank hero's tier name ("Ridge").
  /// The tier name itself is domain vocabulary (`RankTier.label`), not run
  /// through AppLocalizations - see `profile_screen.dart`'s doc comment.
  static const TextStyle heroTierTitle = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w600,
    fontSize: 26,
    height: 1.05,
    color: AppColors.heroInk,
  );

  /// 13px Work Sans 400 - the Profile rank hero's "N m gained" line.
  static const TextStyle heroGainedSubtitle = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    color: AppColors.heroSubtext,
  );

  /// 11.5px Work Sans 400 - the Profile rank hero's withheld-metres line.
  static const TextStyle heroPendingLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 11.5,
    color: AppColors.heroPendingText,
  );

  /// 11.5px Work Sans 400 - the Profile rank hero's progress-row
  /// current-tier label (left side, e.g. "Ridge").
  static const TextStyle heroProgressLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 11.5,
    color: AppColors.heroSubtext,
  );

  /// 11.5px Work Sans 600 - the Profile rank hero's progress-row "N m to
  /// Next" label (right side).
  static const TextStyle heroProgressNext = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 11.5,
    color: AppColors.heroLabelSage,
  );

  /// 14px Work Sans 400 - the Profile rank-ladder row's tier-name label,
  /// default (already-passed-tier) colour; callers `.copyWith` for the
  /// current-tier (bold, ink) and future-tier (faint) variants.
  static const TextStyle ladderTierLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: AppColors.textMuted,
  );

  /// 12px Work Sans 400 - the Profile rank-ladder row's trailing metres/
  /// "You're here" label, default colour; callers `.copyWith` for the
  /// current-tier (bold, sage) variant.
  static const TextStyle ladderMetresLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    color: AppColors.labelGrey,
  );

  /// 15px Work Sans 600 - Profile's "Climbing anonymously" account-status
  /// title.
  static const TextStyle accountStatusTitle = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: AppColors.inkPrimary,
  );

  /// 13px Work Sans 600 - Profile's "Create" account-status action label.
  static const TextStyle accountCreateLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    color: AppColors.terracotta,
  );

  /// 16px Zilla Slab 600 - a small card title (Profile's "Cairn Premium"
  /// row).
  static const TextStyle smallCardTitle = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: AppColors.inkPrimary,
  );

  /// 15px Work Sans 400 - Profile's settings-row label.
  static const TextStyle settingsRowLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    color: AppColors.inkPrimary,
  );

  // ---- Trail screen ---------------------------------------------------

  /// 15px Zilla Slab 600 - the Trail screen's per-task rank pill tier name
  /// ("Ridge"). Distinct from Profile's 26px [heroTierTitle]: the Trail
  /// pill is a small header chip, not a hero card.
  static const TextStyle trailRankPillTier = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: AppColors.inkPrimary,
  );

  /// 11px Work Sans 400 - the Trail screen's per-task rank pill's bare
  /// metres line ("840 m").
  static const TextStyle trailRankPillMetres = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 11,
    color: AppColors.textMuted,
  );

  /// 13px Work Sans 600 - the Trail screen's selected (dark-filled) habit
  /// selector chip label.
  static const TextStyle trailChipLabelSelected = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    color: AppColors.darkChipText,
  );

  /// 13px Work Sans 500 - the Trail screen's unselected habit selector
  /// chip label.
  static const TextStyle trailChipLabelUnselected = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    color: AppColors.inkDimmed,
  );

  /// 10px Work Sans 700, 1.5px letter-spacing, uppercase - the "GROWING NOW"
  /// badge above the Trail screen's currently-growing cairn. Callers must
  /// pass already-uppercased text, same Turkish dotted-i reason as
  /// [sectionLabel].
  static const TextStyle trailGrowingBadgeLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w700,
    fontSize: 10,
    letterSpacing: 1.5,
    color: AppColors.sageText,
  );

  /// 14px Zilla Slab 600 - the task title shown under the Trail screen's
  /// currently-growing cairn.
  static const TextStyle trailGrowingTaskTitle = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: AppColors.inkPrimary,
  );

  /// 11.5px Work Sans 400 - the "Cairn N · N stones" caption under the
  /// Trail screen's currently-growing cairn.
  static const TextStyle trailGrowingCaption = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 11.5,
    color: AppColors.textMuted,
  );

  /// 13.5px Zilla Slab 600 - a capped or broken cairn's "Cairn N" title on
  /// the Trail screen (capped colour; see [trailBrokenCairnTitleStyle] for
  /// the broken variant).
  static const TextStyle trailCairnTitle = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w600,
    fontSize: 13.5,
    color: AppColors.inkDimmed,
  );

  /// 13.5px Zilla Slab 600 - a broken cairn's "Cairn N" title on the Trail
  /// screen, using [AppColors.trailBrokenCairnTitle] instead of
  /// [trailCairnTitle]'s darker colour.
  static const TextStyle trailBrokenCairnTitleStyle = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w600,
    fontSize: 13.5,
    color: AppColors.trailBrokenCairnTitle,
  );

  /// 11px Work Sans 400 - a capped cairn's "N stones · capped" caption, and
  /// the trailhead's "The trailhead · date" caption, on the Trail screen.
  static const TextStyle trailCairnCaption = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 11,
    color: AppColors.textMuted,
  );

  /// 11px Work Sans 400 - a broken cairn's "broken · N stones" caption on
  /// the Trail screen, paired with its small lightning glyph.
  static const TextStyle trailBrokenCaption = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 11,
    color: AppColors.textFaint,
  );

  /// 11px Work Sans 600, 2px letter-spacing, uppercase - the "WHERE YOU
  /// STARTED" marker below the Trail screen's trailhead cairn. Callers must
  /// pass already-uppercased text, same Turkish dotted-i reason as
  /// [sectionLabel].
  static const TextStyle trailWhereYouStartedLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 11,
    letterSpacing: 2,
    color: AppColors.trailWhereYouStartedText,
  );

  // ---- Stats screen -----------------------------------------------------

  /// 34px Zilla Slab 700 - the Stats screen's top stat tile big numbers
  /// ("248", "6").
  static const TextStyle statsBigNumber = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w700,
    fontSize: 34,
    height: 0.9,
    color: AppColors.inkPrimary,
  );

  /// 13.5px Work Sans 600 - a Stats screen card heading ("Proofs used
  /// today", "This week").
  static const TextStyle statsCardHeading = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 13.5,
    color: AppColors.inkPrimary,
  );

  /// 13px Work Sans 400 - the Stats screen daily-proofs card's "N of M"
  /// trailing count.
  static const TextStyle statsUsedOfCapLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    color: AppColors.textMuted,
  );

  /// 12px Work Sans 400 - the Stats screen's "This week" card's "N of M
  /// done" trailing summary.
  static const TextStyle statsWeekSummaryLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    color: AppColors.textMuted,
  );

  /// 11.5px Work Sans 400 - the Stats screen daily-proofs card's "Resets at
  /// midnight · Go unlimited" caption line.
  static const TextStyle statsResetCaption = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 11.5,
    color: AppColors.labelGrey,
  );

  /// 11px Work Sans 600 - the Stats screen weekly bar chart's weekday
  /// initial labels ("M", "T", "W", ...).
  static const TextStyle statsWeekdayLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 11,
    color: AppColors.textFaint,
  );

  /// 13px Work Sans 600 - a Stats screen current-streak row's trailing "N
  /// days" count.
  static const TextStyle statsStreakDaysLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    color: AppColors.sageText,
  );

  /// 11px Work Sans 700, 0.5px letter-spacing, uppercase - the "PREMIUM"
  /// badge on the Stats screen's locked "Deeper insights" card. Callers
  /// must pass already-uppercased text, same Turkish dotted-i reason as
  /// [sectionLabel].
  static const TextStyle statsPremiumBadgeLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w700,
    fontSize: 11,
    letterSpacing: 0.5,
    color: AppColors.terracotta,
  );

  // ---- Premium screen -----------------------------------------------------

  /// 11px Work Sans 700, 2.5px letter-spacing, uppercase - the Premium
  /// screen's "CAIRN PREMIUM" eyebrow above its headline. Distinct from
  /// [heroLabel] (11px/700/2px letter-spacing/[AppColors.heroLabelSage]):
  /// close but not identical in the source files, faithfully kept as its
  /// own token rather than collapsed into one. Callers must pass
  /// already-uppercased text, same Turkish dotted-i reason as [sectionLabel].
  static const TextStyle premiumEyebrow = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w700,
    fontSize: 11,
    letterSpacing: 2.5,
    color: AppColors.sageText,
  );

  /// 28px Zilla Slab 600 - the Premium screen's "Keep every stone, on every
  /// peak" headline.
  static const TextStyle premiumHeadline = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 1.12,
    color: AppColors.inkPrimary,
  );

  /// 18px Zilla Slab 600 - a Premium plan card's title ("Yearly"/"Monthly"),
  /// selected-card colour; callers `.copyWith` the unselected ([inkDimmed])
  /// variant.
  static const TextStyle premiumPlanTitle = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    color: AppColors.inkPrimary,
  );

  /// 20px Zilla Slab 700 - a Premium plan card's price, selected-card
  /// colour; callers `.copyWith` the unselected ([inkDimmed]) variant.
  static const TextStyle premiumPlanPrice = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w700,
    fontSize: 20,
    color: AppColors.inkPrimary,
  );

  /// 10.5px Work Sans 700, 0.6px letter-spacing, uppercase - the Premium
  /// screen's "Best value · save 42%" ribbon label. Callers must pass
  /// already-uppercased text, same reason as [sectionLabel].
  static const TextStyle premiumRibbonLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w700,
    fontSize: 10.5,
    letterSpacing: 0.6,
    color: AppColors.premiumOnSageText,
  );

  /// 12px Work Sans 400 - the Premium screen's "Then $27.99/yr · cancel
  /// anytime" footer subtitle under its trial button.
  static const TextStyle premiumTrialSubtitle = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    color: AppColors.textMuted,
  );

  /// 11.5px Work Sans 400 - the Premium screen's footer "Restore purchase" /
  /// "Terms" / "Privacy" link-row labels.
  static const TextStyle premiumFooterLinkLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 11.5,
    color: AppColors.labelGrey,
  );

  // ---- Onboarding screens -----------------------------------------------

  /// 32px Zilla Slab 700 - the onboarding welcome screen's two-line
  /// headline ("Don't just check it off." / "Prove it."). The second line
  /// uses this same style `.copyWith(color: AppColors.sageText)`.
  static const TextStyle onboardingHeadline = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w700,
    fontSize: 32,
    height: 1.12,
    color: AppColors.inkPrimary,
  );

  /// 12.5px Work Sans 400 - the authored clarifier line under the
  /// onboarding welcome screen's subhead ("A cairn is a small stack of
  /// stones..."). Same family/weight/colour as [AppTextStyles.emptyStateBody]
  /// (which the subhead itself reuses directly), just a size step down per
  /// this run's spec ("same muted subhead style, slightly smaller").
  static const TextStyle onboardingClarifier = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 12.5,
    height: 1.5,
    color: AppColors.emptyStateBodyText,
  );

  /// 14.5px Work Sans 600 - the bold lead-in of an onboarding welcome step
  /// card's line (e.g. "Do the thing."), immediately followed by
  /// [onboardingStepBody] in the same line.
  static const TextStyle onboardingStepLead = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 14.5,
    color: AppColors.inkPrimary,
  );

  /// 14.5px Work Sans 400 - the muted remainder of an onboarding welcome
  /// step card's line, following [onboardingStepLead]. Callers `.copyWith`
  /// the step-3 (sage) card's own body colour ([AppColors.sageReasonBody])
  /// in place of this default.
  static const TextStyle onboardingStepBody = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 14.5,
    color: AppColors.emptyStateBodyText,
  );

  /// 28px Zilla Slab 700 - the onboarding verification screen's title ("How
  /// verification works"). Close to but distinct from [PremiumScreen]'s own
  /// 28px headline style ([premiumHeadline] is weight 600, not 700).
  static const TextStyle onboardingVerificationHeadline = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w700,
    fontSize: 28,
    height: 1.12,
    color: AppColors.inkPrimary,
  );

  /// 14.5px Work Sans 600 - an onboarding verification point card's title
  /// (e.g. "Sent only to be checked").
  static const TextStyle onboardingPointTitle = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 14.5,
    color: AppColors.inkPrimary,
  );

  /// 12.5px Work Sans 400 - an onboarding verification point card's body
  /// copy, under [onboardingPointTitle].
  static const TextStyle onboardingPointBody = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 12.5,
    height: 1.45,
    color: AppColors.emptyStateBodyText,
  );

  /// 13px Work Sans 600 - the bold lead-in of the onboarding verification
  /// screen's footer permission-primer card ("Cairn needs your camera"),
  /// immediately followed by [onboardingPermissionBody] in the same line.
  static const TextStyle onboardingPermissionLead = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    color: AppColors.clayHeading,
  );

  /// 13px Work Sans 400 - the plain remainder of the onboarding
  /// verification screen's footer permission-primer card's line, following
  /// [onboardingPermissionLead].
  static const TextStyle onboardingPermissionBody = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 1.4,
    color: AppColors.clayText,
  );

  /// 13px Work Sans 600 - the onboarding verification screen's "Learn more
  /// about privacy" footer link.
  static const TextStyle onboardingPrivacyLinkLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    color: AppColors.textMuted,
  );

  // ---- Cairn Complete / How Cairns Work -------------------------------

  /// 28px Zilla Slab 600 - the Cairn Complete celebration screen's
  /// headline ("Cairn 6 complete"), sage-tinted. Close to but distinct from
  /// [onboardingVerificationHeadline] (also 28px Zilla Slab, but weight
  /// 700 and [AppColors.inkPrimary]): kept as its own token per this
  /// file's own precedent of preserving literal per-source distinctions.
  static const TextStyle cairnCompleteHeadline = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    color: AppColors.sageHeading,
  );

  /// 26px Zilla Slab 700 - the How Cairns Work explainer sheet's title
  /// ("Every stone builds a cairn").
  static const TextStyle howCairnsWorkTitle = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w700,
    fontSize: 26,
    height: 1.14,
    color: AppColors.inkPrimary,
  );

  /// 13.5px Work Sans 400 - the How Cairns Work explainer sheet's subhead,
  /// under [howCairnsWorkTitle]. Same family/weight/colour as
  /// [emptyStateBody] (which its own subhead style is closest to), just a
  /// size step down - same reasoning as [onboardingClarifier].
  static const TextStyle howCairnsWorkSubhead = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 13.5,
    height: 1.5,
    color: AppColors.emptyStateBodyText,
  );

  /// 11.5px Work Sans 600 - a label under one of the three mini-cairns in
  /// the How Cairns Work explainer sheet's legend card (Growing/Capped/
  /// Broken); callers `.copyWith` the colour per state.
  static const TextStyle howCairnsWorkLegendLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 11.5,
  );

  /// 14px Work Sans 600 - an explainer row's title on the How Cairns Work
  /// sheet.
  static const TextStyle howCairnsWorkRowTitle = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: AppColors.inkPrimary,
  );

  // ---- Account screens (Cairn Account.dc.html) -------------------------

  /// 14px Work Sans 400 - the account-flow header subtitle under the
  /// eyebrow+title (Create account / Sign in / Set new password screens).
  /// Distinct from [body] (13px): a size step up, matching the source
  /// file's own literal.
  static const TextStyle accountHeaderSubtitle = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.5,
    color: AppColors.textMuted,
  );

  /// 12.5px Work Sans 500 - an account-flow field label ("Email",
  /// "Password", "New password"). Distinct from [caption] (12.5px/400): a
  /// weight step up, matching the source file's own literal.
  static const TextStyle accountFieldLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w500,
    fontSize: 12.5,
    color: AppColors.textMuted,
  );

  /// 15px Work Sans 400 - an account-flow text field's input value.
  static const TextStyle accountFieldInput = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    color: AppColors.inkPrimary,
  );

  /// 12.5px Work Sans 500 - the account-flow "Free. Your trail stays
  /// exactly as it is." chip label.
  static const TextStyle accountFreeChipLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w500,
    fontSize: 12.5,
    color: AppColors.sageReasonBody,
  );

  /// 22px Work Sans 600 - the Enter Code screen's 6-box OTP digit text.
  static const TextStyle otpDigit = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    color: AppColors.inkPrimary,
  );

  /// 12.5px Work Sans 400 - an account-flow inline field-error line, and the
  /// account offline banner's body text.
  static const TextStyle accountInlineError = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 12.5,
    color: AppColors.terracotta,
  );

  /// 15.5px Work Sans 600 - the "Keep which trail" chooser card's title
  /// ("This device" / "This account").
  static const TextStyle accountTrailOptionTitle = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 15.5,
    color: AppColors.inkPrimary,
  );

  /// 12.5px Work Sans 400 - the "Keep which trail" chooser card's stone
  /// count/last-climb subtitle; callers `.copyWith` the italic
  /// "No activity yet" empty-state colour ([AppColors.labelGrey]).
  static const TextStyle accountTrailOptionSubtitle = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 12.5,
    color: AppColors.textMuted,
  );

  /// 15px Work Sans 600 - the signed-in account row's "Signed in" title
  /// (Profile screen, Frame 6).
  static const TextStyle accountSignedInTitle = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: AppColors.inkPrimary,
  );

  /// 12.5px Work Sans 400 - the signed-in account row's email line.
  static const TextStyle accountSignedInEmail = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w400,
    fontSize: 12.5,
    color: AppColors.textMuted,
  );

  /// 11.5px Work Sans 500 - the signed-in account row's "Your trail is
  /// backed up." line.
  static const TextStyle accountBackedUpLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w500,
    fontSize: 11.5,
    color: AppColors.sageText,
  );

  /// 12.5px Work Sans 600 - the signed-in account row's clay "Sign out"
  /// pill label.
  static const TextStyle accountSignOutLabel = TextStyle(
    fontFamily: AppFontFamilies.workSans,
    fontWeight: FontWeight.w600,
    fontSize: 12.5,
    color: AppColors.terracotta,
  );

  /// 22px Zilla Slab 700 - reusable Cairn dialog title.
  static const TextStyle dialogTitle = TextStyle(
    fontFamily: AppFontFamilies.zillaSlab,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    color: AppColors.inkPrimary,
  );
}

