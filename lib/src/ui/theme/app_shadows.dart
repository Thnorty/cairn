import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Layered drop-shadow tokens extracted from `design/*.dc.html`.
///
/// The designs also use an `inset 0 1px 0 rgba(255,255,255,x)` highlight on
/// every card/button/photo to fake a soft top bevel. Flutter's `BoxShadow`
/// has no inset variant, so that highlight is reproduced separately as a
/// thin gradient line at the top of the surface (see `CardSurface`'s
/// `_TopHighlight`) rather than folded into these shadow lists; that's a
/// deliberate, noted deviation from a literal CSS shadow translation.
abstract final class AppShadows {
  /// Standard raised parchment card (Card 1/1b/2):
  /// `0 16px 24px -16px rgba(60,50,35,.45), 0 4px 8px -4px rgba(60,50,35,.22)`.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x733C3223),
      offset: Offset(0, 16),
      blurRadius: 24,
      spreadRadius: -16,
    ),
    BoxShadow(
      color: Color(0x383C3223),
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: -4,
    ),
  ];

  /// Dimmed/scheduled parchment card (Card 3), a lighter single layer:
  /// `0 10px 18px -14px rgba(60,50,35,.4)`.
  static const List<BoxShadow> cardDimmed = [
    BoxShadow(
      color: Color(0x663C3223),
      offset: Offset(0, 10),
      blurRadius: 18,
      spreadRadius: -14,
    ),
  ];

  /// Large terracotta footer CTA button:
  /// `0 10px 20px -8px rgba(140,74,42,.6)`.
  static const List<BoxShadow> buttonLarge = [
    BoxShadow(
      color: AppColors.buttonShadow,
      offset: Offset(0, 10),
      blurRadius: 20,
      spreadRadius: -8,
    ),
  ];

  /// Small inline terracotta CTA button ("Prove it"):
  /// `0 6px 13px -5px rgba(140,74,42,.6)`.
  static const List<BoxShadow> buttonSmall = [
    BoxShadow(
      color: AppColors.buttonShadow,
      offset: Offset(0, 6),
      blurRadius: 13,
      spreadRadius: -5,
    ),
  ];

  /// Proof photo pebble on the verification screens:
  /// `0 18px 26px -16px rgba(60,50,35,.5), 0 5px 10px -5px rgba(60,50,35,.25)`.
  static const List<BoxShadow> proofPhoto = [
    BoxShadow(
      color: Color(0x803C3223),
      offset: Offset(0, 18),
      blurRadius: 26,
      spreadRadius: -16,
    ),
    BoxShadow(
      color: Color(0x403C3223),
      offset: Offset(0, 5),
      blurRadius: 10,
      spreadRadius: -5,
    ),
  ];

  /// Individual stone drop shadow: `0 2px 3px rgba(60,50,35,.16)`.
  static const List<BoxShadow> stone = [
    BoxShadow(
      color: AppColors.stoneShadow,
      offset: Offset(0, 2),
      blurRadius: 3,
    ),
  ];

  /// Individual stone drop shadow, muted variant:
  /// `0 2px 3px rgba(60,50,35,.14)`.
  static const List<BoxShadow> stoneMuted = [
    BoxShadow(
      color: AppColors.stoneShadowMuted,
      offset: Offset(0, 2),
      blurRadius: 3,
    ),
  ];

  /// Glow ring behind a freshly-placed sage top stone:
  /// `0 0 0 3px rgba(122,141,96,.18)`, approximated as a soft blurred ring
  /// (Flutter's `BoxShadow` has no zero-blur spread-only "ring" primitive
  /// with sharp edges the way CSS's fourth shadow value does).
  static const List<BoxShadow> sageStoneRing = [
    BoxShadow(color: AppColors.sageRing, blurRadius: 4, spreadRadius: 3),
  ];

  /// Glow ring behind an unverified/pending top stone:
  /// `0 0 0 3px rgba(160,148,126,.2)`.
  static const List<BoxShadow> pendingStoneRing = [
    BoxShadow(color: AppColors.pendingRing, blurRadius: 4, spreadRadius: 3),
  ];
}
