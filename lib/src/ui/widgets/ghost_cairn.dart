import 'package:flutter/widgets.dart';

/// The dashed-outline "waiting" cairn (4 stones, no fill): the "no stones
/// yet" illustration from `Cairn Empty Today.dc.html`, reused wherever the
/// app needs to represent a cairn with zero completions - the empty-today
/// illustration itself at full size, and (a design-owner decision, since no
/// static mockup shows a brand-new task's card) [scale]d down to fit a
/// [CairnStack]'s 60px column when a task has no completions yet: see
/// `home_occurrence_card.dart`'s `_CairnColumn`. It's existing canonical
/// vocabulary either way - reused here rather than duplicated or replaced
/// with an invented "empty stack" treatment.
///
/// A distinct one-off rendering from [CairnStack]'s solid gradient stones:
/// this is the only place in the designs a *dashed* pebble outline appears,
/// so it's kept as its own small widget rather than adding a rarely-used
/// "ghost" mode to the shared stack component. Approximates the source
/// file's per-corner elliptical radii with a single uniform stadium-ish
/// rounded rect per stone (a deliberate simplification for a decorative
/// placeholder illustration).
class GhostCairnStack extends StatelessWidget {
  const GhostCairnStack({super.key, this.scale = 1.0});

  /// Uniform size multiplier: 1.0 matches Empty Today's full-size
  /// illustration (its widest stone/ground-shadow is 60/64px, straight from
  /// the source file); the Home card's zero-stone mini-cairn column scales
  /// this down so the ghost cairn reads at roughly the same visual weight
  /// as a real [CairnStack] in that same 60px-wide column.
  final double scale;

  static const _stones = [
    (width: 24.0, height: 12.0, rotation: -3.0, alpha: 0x73),
    (width: 36.0, height: 14.0, rotation: 2.0, alpha: 0x73),
    (width: 48.0, height: 15.0, rotation: -2.0, alpha: 0x80),
    (width: 60.0, height: 16.0, rotation: 1.0, alpha: 0x8C),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final stone in _stones) ...[
          Transform.rotate(
            angle: stone.rotation * 3.1415926535 / 180,
            child: CustomPaint(
              size: Size(stone.width * scale, stone.height * scale),
              painter: _DashedPebblePainter(
                color: Color.fromARGB(stone.alpha, 0x78, 0x6C, 0x58),
                strokeWidth: 1.6 * scale,
              ),
            ),
          ),
          SizedBox(height: 5 * scale),
        ],
        SizedBox(
          width: 64 * scale,
          height: 10 * scale,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0x24322A1E), Color(0x00322A1E)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws a dashed outline around a rounded-rect "pebble" shape.
class _DashedPebblePainter extends CustomPainter {
  const _DashedPebblePainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  static const double _dashLength = 3;
  static const double _gapLength = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height * 0.5),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashLength;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPebblePainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}
