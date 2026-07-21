import 'package:flutter/widgets.dart';

/// Small [CustomPaint] glyphs reused verbatim (same SVG path, colour and
/// size parameterised per call site) across several otherwise-unrelated
/// screens. Each was previously re-implemented as a private near-copy in
/// every file that needed it; this file centralises only the ones confirmed
/// to draw the exact same path, per this codebase's existing precedent for
/// shared glyphs (`plus_glyph.dart`, `wordmark_glyph.dart`,
/// `status_chip.dart`'s `GalleryGlyph`/`CloseGlyph`). Glyphs that merely
/// *look* similar but draw different coordinates (e.g. the Premium/Daily
/// Limit "Go unlimited" mountain, or `verify_pending_screen.dart`'s
/// `_StreakSafeIcon` bolt) deliberately keep their own private painters -
/// seeing doc comment below each shared glyph for the specific one it was
/// *not* merged with.

/// The triangle-range "mountain" glyph (`M3 19l5.5-9 3.5 5 2-3 6.5 7z`,
/// closed path, round joins): Profile's rank-hero badge and achieved-tier
/// row, the Trail rank pill, the Cairn Complete bonus pill, and How Cairns
/// Work's rank-row icon all draw this same shape, previously duplicated as
/// `profile_screen.dart`'s `_GlyphShape.mountain` case,
/// `trail_screen.dart`'s `_MountainGlyph`, `cairn_complete_screen.dart`'s
/// `_BonusMountainGlyph`, and `how_cairns_work_screen.dart`'s
/// `_RowMountainGlyph`.
///
/// NOT the same shape as `daily_limit_screen.dart`'s (and
/// `premium_screen.dart`'s) "Go unlimited" button glyph
/// (`M4 19l6-10 4 6 3-4 3 8z`, an unclosed path with round caps) - that one
/// keeps its own private `_MountainGlyph`/`_MountainGlyphPainter` since the
/// path genuinely differs.
class MountainGlyph extends StatelessWidget {
  const MountainGlyph({super.key, required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MountainGlyphPainter(color: color)),
    );
  }
}

class _MountainGlyphPainter extends CustomPainter {
  const _MountainGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(p(3, 19).dx, p(3, 19).dy)
      ..lineTo(p(8.5, 10).dx, p(8.5, 10).dy)
      ..lineTo(p(12, 15).dx, p(12, 15).dy)
      ..lineTo(p(14, 12).dx, p(14, 12).dy)
      ..lineTo(p(20.5, 19).dx, p(20.5, 19).dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MountainGlyphPainter oldDelegate) => color != oldDelegate.color;
}

/// The broken-cairn lightning-bolt glyph (`M13 3l-2 8h6l-8 10 2-8H5z`,
/// closed path, round caps/joins): the Trail screen's broken-cairn caption
/// and How Cairns Work's matching legend/row icons all draw this same
/// shape, previously duplicated as `trail_screen.dart`'s `_LightningGlyph`
/// and `how_cairns_work_screen.dart`'s `_LightningGlyph`.
///
/// NOT the same shape as `verify_pending_screen.dart`'s `_StreakSafeIcon`
/// (`M13 2L5 13h6l-1 9 8-11h-6z`) - a differently-proportioned "streak safe"
/// bolt that keeps its own private painter since the path genuinely
/// differs.
class LightningGlyph extends StatelessWidget {
  const LightningGlyph({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LightningGlyphPainter(color: color)),
    );
  }
}

class _LightningGlyphPainter extends CustomPainter {
  const _LightningGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(p(13, 3).dx, p(13, 3).dy)
      ..lineTo(p(11, 11).dx, p(11, 11).dy)
      ..lineTo(p(17, 11).dx, p(17, 11).dy)
      ..lineTo(p(9, 21).dx, p(9, 21).dy)
      ..lineTo(p(11, 13).dx, p(11, 13).dy)
      ..lineTo(p(5, 13).dx, p(5, 13).dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LightningGlyphPainter oldDelegate) => color != oldDelegate.color;
}

/// The back-chevron glyph (`M15 5l-7 7 7 7`, open path, round cap/join,
/// fixed stroke-width 2.2 regardless of size): the New Habit header's
/// leading control (all four variants) and the shared onboarding header
/// (`OnboardingHeader`/`_BackButton`, used by the How It Works and Verify
/// onboarding steps) draw this same shape, previously duplicated as
/// `new_habit_screen.dart`'s `_BackChevronPainter` and
/// `onboarding_header.dart`'s `_BackChevronPainter`.
class BackChevronGlyph extends StatelessWidget {
  const BackChevronGlyph({super.key, required this.color, this.size = 17});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BackChevronGlyphPainter(color: color)),
    );
  }
}

class _BackChevronGlyphPainter extends CustomPainter {
  const _BackChevronGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;
    canvas.drawPath(
      Path()
        ..moveTo(15 * w, 5 * h)
        ..lineTo(8 * w, 12 * h)
        ..lineTo(15 * w, 19 * h),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_BackChevronGlyphPainter oldDelegate) => color != oldDelegate.color;
}
