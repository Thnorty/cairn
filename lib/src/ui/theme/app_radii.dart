import 'package:flutter/widgets.dart';

/// Corner-radius tokens extracted from `design/*.dc.html`.
///
/// The parchment cards use deliberately IRREGULAR per-corner radii (e.g.
/// `border-radius: 34px 32px 34px 33px`) to feel hand-made rather than
/// machine-drawn. That asymmetry is a design decision from the source
/// files and must be preserved, not normalised to a single radius: see
/// [cardA] / [cardB] below, both taken verbatim (CSS order is
/// top-left/top-right/bottom-right/bottom-left).
abstract final class AppRadii {
  /// Card 1 (completed) / Card 3 (scheduled) irregular radius:
  /// `34px 32px 34px 33px`.
  static const BorderRadius cardA = BorderRadius.only(
    topLeft: Radius.circular(34),
    topRight: Radius.circular(32),
    bottomRight: Radius.circular(34),
    bottomLeft: Radius.circular(33),
  );

  /// Card 1b (awaiting) / Card 2 (due-now) irregular radius, mirrored from
  /// [cardA]: `32px 34px 33px 34px`.
  static const BorderRadius cardB = BorderRadius.only(
    topLeft: Radius.circular(32),
    topRight: Radius.circular(34),
    bottomRight: Radius.circular(33),
    bottomLeft: Radius.circular(34),
  );

  /// Small proof thumbnail on a task card.
  static const double proofThumb = 14;

  /// Large proof photo pebble on the verification screens.
  static const double proofPhoto = 34;

  /// Generic pill/chip radius (status chips, trail selector chips).
  static const double pill = 20;

  /// Small inline CTA button radius ("Prove it").
  static const double buttonSmall = 22;

  /// Large full-width footer CTA button radius ("Done", "Retake photo").
  static const double buttonLarge = 26;

  /// List-style panel radius (rank ladder, settings list).
  static const double listPanel = 26;

  /// Row-card radius (account status, premium upsell row).
  static const double rowCard = 24;

  /// Dark hero-card radius (Profile rank card).
  static const double heroCard = 30;

  /// Avatar / seal circle - always a perfect circle, kept here only for
  /// discoverability alongside the other radius tokens.
  static const double circle = 999;
}
