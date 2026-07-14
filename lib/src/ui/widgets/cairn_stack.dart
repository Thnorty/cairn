import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_shadows.dart';

/// The app's signature motif: a small stack of organic, hand-stacked
/// pebbles, largest at the base tapering to smallest on top, sitting on a
/// soft elliptical ground shadow.
///
/// Reproduces the three mini-cairn variants in `Cairn Home.dc.html`
/// (Card 1's 9-stone completed stack with its sage-tinted freshly-placed
/// top stone, Card 2's plain 4-stone stack, Card 3's dimmed 6-stone
/// scheduled stack) from one parameterised widget, so every screen that
/// needs a cairn illustration (Home, Trail, the verification flow) builds
/// on the same component instead of re-drawing pebbles by hand.
///
/// Per-stone size/rotation/radius variation is derived from a seed built
/// from [stoneCount] and the stone's index, so the same
/// `(stoneCount, muted, highlightTop)` combination always renders
/// pixel-identical: the "hand-made" irregularity is deliberate art
/// direction, not visual noise that should differ between rebuilds or
/// break widget-test golden expectations.
class CairnStack extends StatelessWidget {
  const CairnStack({
    super.key,
    required this.stoneCount,
    this.scale = 1.0,
    this.muted = false,
    this.highlightTop = false,
  }) : assert(stoneCount >= 1, 'a cairn always has at least one stone');

  /// Number of stones in the stack (Home shows 9, 4 and 6; other screens
  /// use other counts).
  final int stoneCount;

  /// Uniform size multiplier: the designs reuse this motif at several
  /// sizes (the Home cards' ~60px-wide mini cairns vs. the ~88-100px
  /// cairn on the verification-result screen).
  final double scale;

  /// The dimmed/desaturated variant used for a not-yet-due task (Home
  /// Card 3): lower-saturation stone colours, lighter shadows, and the
  /// whole stack at reduced opacity, matching the source file's
  /// `opacity:.75` wrapper.
  final bool muted;

  /// Tints the topmost stone sage and gives it a soft glow ring, marking
  /// a freshly-placed stone from a just-verified completion (Home
  /// Card 1 / the verification-result screen).
  final bool highlightTop;

  static const double _topWidth = 20;
  static const double _bottomWidth = 44;
  static const double _topHeight = 11;
  static const double _bottomHeight = 13;
  static const double _overlap = 3;
  static const double _groundGap = 3;
  static const double _groundHeightBase = 9;

  @override
  Widget build(BuildContext context) {
    final stones = _layout();

    double contentHeight = 0;
    double contentWidth = 0;
    for (final s in stones) {
      contentHeight = math.max(contentHeight, s.top + s.height);
      contentWidth = math.max(contentWidth, s.width);
    }
    final groundWidth = _bottomWidth * scale + 4 * scale;
    final groundHeight = _groundHeightBase * scale;
    contentWidth = math.max(contentWidth, groundWidth);
    final totalHeight = contentHeight + _groundGap * scale + groundHeight;

    final stack = SizedBox(
      width: contentWidth,
      height: totalHeight,
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: (contentWidth - groundWidth) / 2,
            child: _GroundShadow(
              width: groundWidth,
              height: groundHeight,
              muted: muted,
            ),
          ),
          for (var i = 0; i < stones.length; i++)
            Positioned(
              // Keyed so widget tests can assert stone count/state without
              // reaching into this widget's private stone/layout classes.
              key: ValueKey('cairn-stone-$i'),
              top: stones[i].top,
              left: (contentWidth - stones[i].width) / 2,
              child: Transform.rotate(
                angle: stones[i].rotationDeg * math.pi / 180,
                child: _Stone(
                  width: stones[i].width,
                  height: stones[i].height,
                  light: stones[i].light,
                  dark: stones[i].dark,
                  muted: muted,
                  ring: stones[i].ring,
                ),
              ),
            ),
        ],
      ),
    );

    return muted ? Opacity(opacity: 0.75, child: stack) : stack;
  }

  List<_StoneLayout> _layout() {
    final n = stoneCount;
    final palette = muted
        ? AppColors.stoneGradientsMuted
        : AppColors.stoneGradients;

    final layouts = <_StoneLayout>[];
    double cumulativeTop = 0;
    for (var i = 0; i < n; i++) {
      final t = n == 1 ? 1.0 : i / (n - 1);
      final rnd = math.Random(n * 97 + i * 13);

      final width =
          (_lerp(_topWidth, _bottomWidth, t) + (rnd.nextDouble() - 0.5) * 4) *
          scale;
      final height =
          (_lerp(_topHeight, _bottomHeight, t) +
              (rnd.nextDouble() - 0.5) * 1.2) *
          scale;
      final rotation =
          (i.isEven ? -1 : 1) * (1.5 + rnd.nextDouble() * 2.5);

      final isTop = i == 0;
      final Color light;
      final Color dark;
      List<BoxShadow>? ring;
      if (isTop && highlightTop) {
        light = AppColors.stoneSageLight;
        dark = AppColors.stoneSageDark;
        ring = AppShadows.sageStoneRing;
      } else {
        final pair = palette[i % palette.length];
        light = pair.$1;
        dark = pair.$2;
      }

      layouts.add(
        _StoneLayout(
          top: cumulativeTop,
          width: width,
          height: height,
          rotationDeg: rotation,
          light: light,
          dark: dark,
          ring: ring,
        ),
      );
      cumulativeTop += height - _overlap * scale;
    }
    return layouts;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

class _StoneLayout {
  const _StoneLayout({
    required this.top,
    required this.width,
    required this.height,
    required this.rotationDeg,
    required this.light,
    required this.dark,
    this.ring,
  });

  final double top;
  final double width;
  final double height;
  final double rotationDeg;
  final Color light;
  final Color dark;
  final List<BoxShadow>? ring;
}

class _Stone extends StatelessWidget {
  const _Stone({
    required this.width,
    required this.height,
    required this.light,
    required this.dark,
    required this.muted,
    this.ring,
  });

  final double width;
  final double height;
  final Color light;
  final Color dark;
  final bool muted;
  final List<BoxShadow>? ring;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: Radius.elliptical(width * 0.48, height * 0.62),
      topRight: Radius.elliptical(width * 0.52, height * 0.58),
      bottomRight: Radius.elliptical(width * 0.45, height * 0.42),
      bottomLeft: Radius.elliptical(width * 0.55, height * 0.38),
    );
    final shadows = <BoxShadow>[
      ...?ring,
      ...(muted ? AppShadows.stoneMuted : AppShadows.stone),
    ];
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: AppGradients.stone(light, dark),
        borderRadius: radius,
        boxShadow: shadows,
      ),
    );
  }
}

class _GroundShadow extends StatelessWidget {
  const _GroundShadow({
    required this.width,
    required this.height,
    required this.muted,
  });

  final double width;
  final double height;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted ? AppColors.groundShadowMuted : AppColors.groundShadow;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: RadialGradient(
          colors: [color, color.withAlpha(0)],
        ),
      ),
    );
  }
}
