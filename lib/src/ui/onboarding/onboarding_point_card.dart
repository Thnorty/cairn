import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/card_surface.dart';

/// One parchment "here is what this permission buys you" card: a tinted
/// icon circle, a title, and a line of body copy.
///
/// Shared by the two onboarding permission steps - Verify
/// (`Cairn Onboarding Verification.dc.html`, three cards) and Reminders
/// (`Cairn Onboarding Notifications.dc.html`, two) - which draw this exact
/// card at the same dimensions. It began as the verification screen's own
/// private `_PointCard` and moved here when the notifications step needed
/// the same thing rather than a near-identical copy.
///
/// [iconBackground] is the only thing the two screens vary: the verification
/// step's cards are all sage, while the reminders step tints its
/// streak-warning card clay to match the warning glyph inside it.
class OnboardingPointCard extends StatelessWidget {
  const OnboardingPointCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.iconBackground = AppColors.sageChipBg,
  });

  final Widget icon;
  final String title;
  final String body;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return ParchmentPill(
      radius: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: icon,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTextStyles.onboardingPointTitle),
                const SizedBox(height: 2),
                Text(body, style: AppTextStyles.onboardingPointBody),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
