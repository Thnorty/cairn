import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_shadows.dart';

/// The app's signature motif: a small stack of organic, hand-stacked
/// pebbles, largest at the base tapering to smallest on top, sitting on a
/// soft elliptical ground shadow.
///
/// Reproduces the four mini-cairn variants in `Cairn Home.dc.html`
/// (Card 1's 9-stone completed stack with its sage-tinted freshly-placed
/// top stone, Card 1b's 9-stone stack with its muted-clay awaiting-
/// verification top stone, Card 2's plain 4-stone stack, Card 3's dimmed
/// 6-stone scheduled stack) from one parameterised widget, so every screen
/// that needs a cairn illustration (Home, Trail, the verification flow)
/// builds on the same component instead of re-drawing pebbles by hand.
///
/// Per-stone size/rotation/radius variation is derived from a seed built
/// from [stoneCount] and the stone's index, so the same
/// `(stoneCount, muted, highlightTop)` combination always renders
/// pixel-identical: the "hand-made" irregularity is deliberate art
/// direction, not visual noise that should differ between rebuilds or
/// break widget-test golden expectations.
///
/// Unlike the other reusable widgets in `ui/widgets/` (status chips, the
/// button family, card surfaces, the tab bar), this widget paints no
/// `Text` at all (just gradient-filled `Container`s), so it doesn't need
/// its own `Material` ancestor to avoid MaterialApp's debug-style fallback
/// for un-Materialed text.
class CairnStack extends StatelessWidget {
  const CairnStack({
    super.key,
    required this.stoneCount,
    this.scale = 1.0,
    this.muted = false,
    this.highlightTop = false,
    this.pendingTop = false,
  })  : assert(stoneCount >= 1, 'a cairn always has at least one stone'),
        assert(
          !(highlightTop && pendingTop),
          'a top stone is either freshly-verified or awaiting verification, never both',
        );

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

  /// Tints the topmost stone a muted clay and gives it the pending glow
  /// ring, marking a stone that's placed but still awaiting verification
  /// (Home Card 1b). Mutually exclusive with [highlightTop]: a top stone
  /// is either freshly-verified or awaiting verification, never both.
  final bool pendingTop;

  /// Width envelope anchors `(stoneCount, width)`, narrowest-stone (top) and
  /// widest-stone (base) sides, sourced from `Cairn Home.dc.html`'s three
  /// mini-cairn examples at N=4 (24/42), N=6 (22/42) and N=9 (20/44): as the
  /// stack gets shorter both ends of the taper creep toward each other
  /// (a shorter stack has proportionally chunkier stones), so a straight
  /// `_topWidth`/`_bottomWidth` constant pair - which is all N=9's example
  /// gives you - is only correct at N=9. Below N=4 there's no design
  /// reference, so the anchor list adds one more point, `(1, _soloWidth)`,
  /// continuing the same "ends converge as N shrinks" trend down to a
  /// single stone, where by construction top and base width must be equal
  /// (there's only one stone to be either). [_widthEnvelope] linearly
  /// interpolates between whichever pair of anchors N falls between, so
  /// N=2/3/5/7/8 (no static mockup, but exercised by tests/screenshots) get
  /// a smooth in-between value rather than a cliff.
  static const double _soloWidth = 25;
  static const List<(int, double)> _topWidthAnchors = [
    (1, _soloWidth),
    (4, 24),
    (6, 22),
    (9, 20),
  ];
  static const List<(int, double)> _bottomWidthAnchors = [
    (1, _soloWidth),
    (4, 42),
    (6, 42),
    (9, 44),
  ];

  /// Stone height is constant across the design's N=4/6/9 examples at both
  /// ends of the taper (11px top, 13px base) - only the width envelope
  /// narrows with fewer stones there. But a lone stone rendered at that
  /// constant 11px top-of-stack height, next to [_soloWidth]'s 27px, is
  /// still a flattened oval (2.45:1) that reads as a puddle rather than a
  /// pebble sitting on the ground - the same failure this whole envelope
  /// exists to fix, just less severe than the old fixed 44x13 base slab. A
  /// solo stone isn't really "the top of a stack" or "the base of a stack"
  /// either one, so unlike width it gets its own distinctly taller,
  /// rounder anchor (16px - a ~1.7:1 aspect, close to the design's own
  /// topmost-stone ratio) rather than reusing the taper's flat ends.
  static const double _soloHeight = 18;
  static const List<(int, double)> _topHeightAnchors = [
    (1, _soloHeight),
    (4, 11),
    (6, 11),
    (9, 11),
  ];
  static const List<(int, double)> _bottomHeightAnchors = [
    (1, _soloHeight),
    (4, 13),
    (6, 13),
    (9, 13),
  ];
  static const double _overlap = 3;
  static const double _groundGap = 3;
  static const double _groundHeightBase = 9;

  static double _envelope(int n, List<(int, double)> anchors) {
    if (n <= anchors.first.$1) return anchors.first.$2;
    if (n >= anchors.last.$1) return anchors.last.$2;
    for (var i = 0; i < anchors.length - 1; i++) {
      final (loN, loV) = anchors[i];
      final (hiN, hiV) = anchors[i + 1];
      if (n <= hiN) {
        return _lerp(loV, hiV, (n - loN) / (hiN - loN));
      }
    }
    return anchors.last.$2; // unreachable given the n >= last check above
  }

  static double _topWidthFor(int n) => _envelope(n, _topWidthAnchors);
  static double _bottomWidthFor(int n) => _envelope(n, _bottomWidthAnchors);
  static double _topHeightFor(int n) => _envelope(n, _topHeightAnchors);
  static double _bottomHeightFor(int n) => _envelope(n, _bottomHeightAnchors);

  @override
  Widget build(BuildContext context) {
    final stones = _layout();

    double contentHeight = 0;
    double contentWidth = 0;
    for (final s in stones) {
      contentHeight = math.max(contentHeight, s.top + s.height);
      contentWidth = math.max(contentWidth, s.width);
    }
    final groundWidth = _bottomWidthFor(stoneCount) * scale + 4 * scale;
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
    final topWidth = _topWidthFor(n);
    final bottomWidth = _bottomWidthFor(n);
    final topHeight = _topHeightFor(n);
    final bottomHeight = _bottomHeightFor(n);

    final layouts = <_StoneLayout>[];
    double cumulativeTop = 0;
    for (var i = 0; i < n; i++) {
      // n == 1 has no "position along the stack" - t is irrelevant since
      // top/bottom converge to the same solo width/height by construction
      // (there's exactly one stone, so it can't be narrower/flatter at one
      // end than the other); 0.0 is as good a value as any.
      final t = n == 1 ? 0.0 : i / (n - 1);
      final rnd = math.Random(n * 97 + i * 13);

      final width =
          (_lerp(topWidth, bottomWidth, t) + (rnd.nextDouble() - 0.5) * 4) *
          scale;
      final height =
          (_lerp(topHeight, bottomHeight, t) +
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
      } else if (isTop && pendingTop) {
        light = AppColors.stonePendingLight;
        dark = AppColors.stonePendingDark;
        ring = AppShadows.pendingStoneRing;
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
