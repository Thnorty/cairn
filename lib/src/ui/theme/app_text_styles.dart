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
}
