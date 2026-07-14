import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';

/// Which of the two irregular card-corner shapes to use. The designs
/// alternate between these two hand-made-looking radius sets from card to
/// card (see [AppRadii.cardA]/[AppRadii.cardB]) rather than using one
/// shape everywhere.
enum CardRadiusVariant { a, b }

/// The organic gradient card surface used for every task/content card in
/// the designs: a warm parchment gradient fill, an irregular hand-made
/// corner radius, a hairline highlight border, and a soft layered drop
/// shadow - plus a [dimmed] variant for a not-yet-due task (Home Card 3).
///
/// The designs also apply `inset 0 1px 0 rgba(255,255,255,x)` to fake a
/// soft top bevel; Flutter's `BoxShadow` has no inset variant, so that's
/// reproduced here as an actual thin highlight bar clipped to the card's
/// rounded top edge, rather than a shadow.
class CardSurface extends StatelessWidget {
  const CardSurface({
    super.key,
    required this.child,
    this.variant = CardRadiusVariant.a,
    this.dimmed = false,
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 18),
  });

  final Widget child;
  final CardRadiusVariant variant;

  /// The lower-saturation, lower-lift variant for a not-yet-due task
  /// card: a paler gradient, a thinner border, and a lighter single-layer
  /// shadow instead of the standard two-layer lift.
  final bool dimmed;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = variant == CardRadiusVariant.a
        ? AppRadii.cardA
        : AppRadii.cardB;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: dimmed ? AppGradients.cardDimmed : AppGradients.card,
        borderRadius: radius,
        border: Border.all(
          color: dimmed ? AppColors.cardBorderDim : AppColors.cardBorder,
        ),
        boxShadow: dimmed ? AppShadows.cardDimmed : AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 1.5,
                color: dimmed
                    ? AppColors.cardTopHighlightDim
                    : AppColors.cardTopHighlight,
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}
