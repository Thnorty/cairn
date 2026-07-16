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
}
