import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Paints the faint topographic contour-map wash that sits under every
/// screen in the designs: concentric rings radiating from a point near
/// the top of the screen, e.g.
/// `repeating-radial-gradient(circle at 84% 4%, transparent 0 26px, rgba(70,60,44,.05) 26px 27px)`.
///
/// CSS's `repeating-radial-gradient` has no direct Flutter equivalent, so
/// this reproduces it with a `CustomPainter` drawing evenly-spaced ring
/// strokes outward from [origin], which is the same shape at the same
/// faintness.
class TopographicContourPainter extends CustomPainter {
  const TopographicContourPainter({
    this.origin = const Alignment(0.68, -0.92),
    this.ringSpacing = 27,
    this.ringColor = const Color(0x0D463C2C),
  });

  /// Where the concentric rings radiate from, in the same [Alignment]
  /// coordinate space as everything else (-1..1 per axis, 0,0 = centre).
  /// Varies slightly per screen in the source files (50%/76%/84%/60%/82%
  /// horizontally, all within a few percent of the top edge vertically);
  /// this default matches the Home file.
  final Alignment origin;

  /// Spacing between rings, matching the designs' ~26-31px repeat.
  final double ringSpacing;

  /// Ring stroke colour, matching the designs' ~0.045-0.05 alpha warm ink.
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = origin.alongSize(size);
    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    final maxRadius = corners
        .map((c) => (c - center).distance)
        .reduce(math.max);

    final paint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var r = ringSpacing; r < maxRadius; r += ringSpacing) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(TopographicContourPainter oldDelegate) =>
      origin != oldDelegate.origin ||
      ringSpacing != oldDelegate.ringSpacing ||
      ringColor != oldDelegate.ringColor;
}

/// The shared screen chrome behind every real screen: the base parchment
/// colour, one or two soft radial "wash" tints near the top of the
/// screen, and the faint topographic contour overlay - then [child] on
/// top. Every screen in the designs is built from this same recipe with a
/// different was tint; see e.g. Home (warm clay + sage), Verify Result
/// (sage-forward), Verify Failed (terracotta-forward).
class ScreenBackground extends StatelessWidget {
  const ScreenBackground({
    super.key,
    required this.child,
    this.washes = const [
      RadialGradient(
        center: Alignment(-0.64, -1.16),
        radius: 1.3,
        colors: [Color(0x38968368), Color(0x00968368)],
      ),
      RadialGradient(
        center: Alignment(1, -1),
        radius: 0.9,
        colors: [Color(0x2496A678), Color(0x0096A678)],
      ),
    ],
    this.showContour = true,
    this.contourOrigin = const Alignment(0.68, -0.92),
  });

  final Widget child;

  /// Soft radial tints layered over the base colour, outermost first.
  /// Defaults to the Home file's warm-clay + sage wash.
  final List<RadialGradient> washes;

  /// Whether to paint the topographic contour overlay. Always true in the
  /// designs; exposed only so a test can turn it off cheaply if needed.
  final bool showContour;

  /// Passed through to [TopographicContourPainter.origin].
  final Alignment contourOrigin;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.screenBackground),
      child: Stack(
        children: [
          for (final wash in washes)
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: wash))),
          if (showContour)
            Positioned.fill(
              child: CustomPaint(
                painter: TopographicContourPainter(origin: contourOrigin),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
