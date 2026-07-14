import 'package:flutter/widgets.dart';

/// Which tab-bar glyph to paint. Names match the four tabs in the
/// designs: Today (home), Trail (winding path), Stats (bar chart), You
/// (person).
enum TabIconShape { today, trail, stats, you }

/// Reproduces the tab bar's inline-SVG stroke icons pixel-faithfully via
/// `CustomPainter`, using the exact path coordinates from the design
/// files' `viewBox="0 0 24 24"` glyphs (stroke width 2, round caps/joins),
/// rather than approximating them with Material icons.
class TabBarIcon extends StatelessWidget {
  const TabBarIcon({
    super.key,
    required this.shape,
    required this.color,
    this.size = 23,
  });

  final TabIconShape shape;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _TabIconPainter(shape: shape, color: color),
    );
  }
}

class _TabIconPainter extends CustomPainter {
  const _TabIconPainter({required this.shape, required this.color});

  final TabIconShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset p(double x, double y) => Offset(x * scale, y * scale);

    switch (shape) {
      case TabIconShape.today:
        // <path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V20h14V9.5"/>
        final roof = Path()
          ..moveTo(p(3, 10.5).dx, p(3, 10.5).dy)
          ..lineTo(p(12, 3).dx, p(12, 3).dy)
          ..lineTo(p(21, 10.5).dx, p(21, 10.5).dy);
        final walls = Path()
          ..moveTo(p(5, 9.5).dx, p(5, 9.5).dy)
          ..lineTo(p(5, 20).dx, p(5, 20).dy)
          ..lineTo(p(19, 20).dx, p(19, 20).dy)
          ..lineTo(p(19, 9.5).dx, p(19, 9.5).dy);
        canvas.drawPath(roof, paint);
        canvas.drawPath(walls, paint);
        break;

      case TabIconShape.trail:
        // <path d="M6 21c0-3.5 4-3.5 4-7s-4-3.5-4-7 4-3.5 4-4"/>
        // <circle cx="10" cy="3" r="0.6" fill="currentColor"/>
        // <path d="M14 3c0 3.5 4 3.5 4 7s-4 3.5-4 7 3 3 4 4"/>
        final lower = Path()
          ..moveTo(p(6, 21).dx, p(6, 21).dy)
          ..cubicTo(
            p(6, 17.5).dx,
            p(6, 17.5).dy,
            p(10, 17.5).dx,
            p(10, 17.5).dy,
            p(10, 14).dx,
            p(10, 14).dy,
          )
          ..cubicTo(
            p(10, 10.5).dx,
            p(10, 10.5).dy,
            p(6, 10.5).dx,
            p(6, 10.5).dy,
            p(6, 7).dx,
            p(6, 7).dy,
          );
        final upper = Path()
          ..moveTo(p(14, 3).dx, p(14, 3).dy)
          ..cubicTo(
            p(14, 6.5).dx,
            p(14, 6.5).dy,
            p(18, 6.5).dx,
            p(18, 6.5).dy,
            p(18, 10).dx,
            p(18, 10).dy,
          )
          ..cubicTo(
            p(18, 13.5).dx,
            p(18, 13.5).dy,
            p(14, 13.5).dx,
            p(14, 13.5).dy,
            p(14, 17).dx,
            p(14, 17).dy,
          )
          ..cubicTo(
            p(14, 20.5).dx,
            p(14, 20.5).dy,
            p(17, 20).dx,
            p(17, 20).dy,
            p(18, 21).dx,
            p(18, 21).dy,
          );
        canvas.drawPath(lower, paint);
        canvas.drawPath(upper, paint);
        final dotPaint = Paint()..color = color;
        canvas.drawCircle(p(10, 3), 0.6 * scale, dotPaint);
        break;

      case TabIconShape.stats:
        // <path d="M4 20V10"/><path d="M12 20V4"/><path d="M20 20v-7"/>
        canvas.drawLine(p(4, 20), p(4, 10), paint);
        canvas.drawLine(p(12, 20), p(12, 4), paint);
        canvas.drawLine(p(20, 20), p(20, 13), paint);
        break;

      case TabIconShape.you:
        // <circle cx="12" cy="8" r="3.4"/>
        // <path d="M5.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6"/>
        canvas.drawCircle(p(12, 8), 3.4 * scale, paint);
        final shoulders = Path()
          ..moveTo(p(5.5, 20).dx, p(5.5, 20).dy)
          ..cubicTo(
            p(5.5, 16.4).dx,
            p(5.5, 16.4).dy,
            p(8.4, 14).dx,
            p(8.4, 14).dy,
            p(12, 14).dx,
            p(12, 14).dy,
          )
          ..cubicTo(
            p(15.6, 14).dx,
            p(15.6, 14).dy,
            p(18.5, 16.4).dx,
            p(18.5, 16.4).dy,
            p(18.5, 20).dx,
            p(18.5, 20).dy,
          );
        canvas.drawPath(shoulders, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(_TabIconPainter oldDelegate) =>
      shape != oldDelegate.shape || color != oldDelegate.color;
}
