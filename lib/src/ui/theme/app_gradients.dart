import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Converts a CSS `linear-gradient(angleDeg, ...)` angle to the
/// begin/end [Alignment] pair Flutter's [LinearGradient] needs.
///
/// CSS gradient angles are measured clockwise from "up" (0deg = to top,
/// 90deg = to right, 180deg = to bottom, 270deg = to left); Flutter has no
/// angle-based gradient constructor, only begin/end alignments. This maps
/// one to the other so the gradients below can cite the exact degree
/// values used in the design files instead of an eyeballed Alignment pair.
(Alignment begin, Alignment end) cssGradientAlignment(double degrees) {
  final radians = degrees * math.pi / 180;
  final dx = math.sin(radians);
  final dy = -math.cos(radians);
  return (Alignment(-dx, -dy), Alignment(dx, dy));
}

/// Gradient tokens extracted from `design/*.dc.html`.
abstract final class AppGradients {
  /// Primary parchment card fill, 165deg.
  static LinearGradient get card {
    final (begin, end) = cssGradientAlignment(165);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [AppColors.cardGradientLight, AppColors.cardGradientDark],
    );
  }

  /// Dimmed/scheduled parchment card fill, 165deg.
  static LinearGradient get cardDimmed {
    final (begin, end) = cssGradientAlignment(165);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [
        AppColors.cardGradientDimLight,
        AppColors.cardGradientDimDark,
      ],
    );
  }

  /// Terracotta primary-button gradient, 155deg.
  static LinearGradient get terracottaButton {
    final (begin, end) = cssGradientAlignment(155);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [AppColors.terracottaLight, AppColors.terracotta],
    );
  }

  /// Dark hero-card gradient (Profile rank card), 160deg.
  static LinearGradient get heroDark {
    final (begin, end) = cssGradientAlignment(160);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [AppColors.heroDarkTop, AppColors.heroDarkBottom],
    );
  }

  /// A stone gradient fill, 158deg, for the given light/dark colour pair.
  static LinearGradient stone(Color light, Color dark) {
    final (begin, end) = cssGradientAlignment(158);
    return LinearGradient(begin: begin, end: end, colors: [light, dark]);
  }

  /// New Habit's inactive recurrence-type chip fill, 165deg.
  static LinearGradient get chipInactive {
    final (begin, end) = cssGradientAlignment(165);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [AppColors.chipInactiveLight, AppColors.chipInactiveDark],
    );
  }

  /// New Habit's unselected day-circle fill, 155deg.
  static LinearGradient get circleInactive {
    final (begin, end) = cssGradientAlignment(155);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [AppColors.circleInactiveLight, AppColors.circleInactiveDark],
    );
  }

  /// New Habit's selected sage day-circle fill, 155deg (the same sage pair
  /// as the cairn stack's freshly-placed top stone).
  static LinearGradient get sageCircleSelected {
    final (begin, end) = cssGradientAlignment(155);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [AppColors.sageLight, AppColors.sage],
    );
  }

  /// New Habit's active monthly-mode pill-toggle segment, 155deg.
  static LinearGradient get pillToggleActive {
    final (begin, end) = cssGradientAlignment(155);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [AppColors.pillToggleActiveLight, AppColors.pillToggleActiveDark],
    );
  }

  /// Profile rank hero's progress-bar fill, 90deg `#9aa87c -> #c2cdae`.
  static LinearGradient get heroProgressFill {
    final (begin, end) = cssGradientAlignment(90);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [AppColors.heroProgressFillStart, AppColors.heroLabelSage],
    );
  }

  /// Profile rank hero's circular mountain-badge fill, 155deg
  /// `#8a97b0 -> #5f6d88`.
  static LinearGradient get heroBadge {
    final (begin, end) = cssGradientAlignment(155);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [AppColors.heroBadgeLight, AppColors.heroBadgeDark],
    );
  }

  /// Profile's Cairn Premium row background, 160deg `#f4efe4 -> #e6decb`.
  static LinearGradient get premiumBg {
    final (begin, end) = cssGradientAlignment(160);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [AppColors.premiumBgLight, AppColors.premiumBgDark],
    );
  }

  /// Profile's account-status row avatar-circle fill, 150deg
  /// `#c9c0b0 -> #a99f8c` (the same pair Home's greeting avatar uses).
  static LinearGradient get accountAvatar {
    final (begin, end) = cssGradientAlignment(150);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [AppColors.accountAvatarLight, AppColors.accountAvatarDark],
    );
  }
}
