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
}
