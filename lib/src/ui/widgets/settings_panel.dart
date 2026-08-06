import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radii.dart';

/// The gradient/border/top-highlight/radius recipe shared by the rank
/// ladder, Profile's settings list, and the Notifications settings screen's
/// preferences panel - a uniform-radius parchment panel, distinct from
/// [CardSurface]'s deliberately irregular per-corner shape (none of these
/// panels uses that shape in their source files).
///
/// Began as `profile_screen.dart`'s private `_PanelSurface` and moved here
/// when the Notifications screen needed the identical surface; the source
/// designs describe it identically in both places
/// (`linear-gradient(165deg,#f3eee3,#e4dccb)`, radius 26, 18px horizontal
/// padding, a 1px white border and an inset top bevel).
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.listPanel);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: radius,
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 1.5,
                child: ColoredBox(color: AppColors.panelTopHighlight),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 18,
                vertical: 4,
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// The 1px rule between two rows inside a [SettingsPanel].
class HairlineDivider extends StatelessWidget {
  const HairlineDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1,
      child: ColoredBox(color: AppColors.hairlineDivider),
    );
  }
}
