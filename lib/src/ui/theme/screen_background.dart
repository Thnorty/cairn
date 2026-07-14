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
    this.ringSpacing = 26,
    this.strokeWidth = 1,
    this.ringColor = const Color(0x0D463C2C),
  });

  /// Where the concentric rings radiate from, in the same [Alignment]
  /// coordinate space as everything else (-1..1 per axis, 0,0 = centre).
  /// Varies slightly per screen in the source files (50%/76%/84%/60%/82%
  /// horizontally, all within a few percent of the top edge vertically);
  /// this default matches the Home file's `circle at 84% 4%`.
  final Alignment origin;

  /// Spacing between rings **in logical pixels (dp)**, matching the Home
  /// file's `repeating-radial-gradient(circle at 84% 4%, transparent 0
  /// 26px, rgba(70,60,44,.05) 26px 27px)`: a 26px transparent gap then a
  /// 1px ring, repeating every 27px - i.e. one ring every 26px measured
  /// gap-to-gap. `CustomPainter.paint`'s `Canvas`/`Size` are always in
  /// logical pixels regardless of device pixel ratio, so drawing `r` in
  /// these units (never multiplying by `MediaQuery.devicePixelRatio` or
  /// similar) is what makes the rings scale correctly across devices.
  final double ringSpacing;

  /// Ring stroke width in logical pixels (dp), matching the design's 1px
  /// ring band.
  final double strokeWidth;

  /// Ring stroke colour, matching the design's `rgba(70,60,44,.05)`. The
  /// design applies a *further* 50% opacity on the whole contour layer on
  /// top of this (see [ScreenBackground]), so this colour's alpha alone is
  /// intentionally the full `.05`, not pre-halved.
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
      ..strokeWidth = strokeWidth;

    for (var r = ringSpacing; r < maxRadius; r += ringSpacing) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(TopographicContourPainter oldDelegate) =>
      origin != oldDelegate.origin ||
      ringSpacing != oldDelegate.ringSpacing ||
      strokeWidth != oldDelegate.strokeWidth ||
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
    this.contourRingColor = const Color(0x0D463C2C),
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

  /// Passed through to [TopographicContourPainter.ringColor]. Each design
  /// file tints its contour rings to match that screen's own wash (e.g. a
  /// faint green cast on `Cairn Verify Result.dc.html`, a faint terracotta
  /// cast on the failed-verification screens) rather than reusing Home's
  /// neutral warm-ink tint everywhere.
  final Color contourRingColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.screenBackground),
      child: Stack(
        children: [
          for (final wash in washes)
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: wash))),
          if (showContour)
            // The design wraps the contour div in its own `opacity:.5`,
            // *on top of* the `rgba(70,60,44,.05)` already baked into the
            // ring colour (see `Cairn Home.dc.html`'s "topographic contour
            // wash" div: `opacity:.5;background-image:repeating-radial-
            // gradient(...rgba(70,60,44,.05)...)`). Without this `Opacity`
            // the rings render at their raw .05 alpha - roughly twice the
            // intended, almost-subliminal .025 effective strength - which
            // is what made them read as clearly-visible rings on a real
            // device instead of a faint paper texture.
            Positioned.fill(
              child: Opacity(
                opacity: 0.5,
                child: CustomPaint(
                  painter: TopographicContourPainter(
                    origin: contourOrigin,
                    ringColor: contourRingColor,
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
