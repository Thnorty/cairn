import 'package:flutter/material.dart' show MaterialLocalizations;
import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../widgets/glyphs.dart';

/// Shared header for the three first-launch onboarding screens (Welcome /
/// How It Works / Verify - see `onboarding_flow.dart`'s doc comment): a
/// back-chevron slot on the left, the centered [OnboardingProgressDots]
/// indicator, and a matching spacer on the right so the indicator stays
/// visually centered. Extracted from what used to be the verification
/// screen's own private `_ProgressHeader`/`_BackButton` (the only screen
/// that showed a progress indicator before this run's 2-\>3-screen split)
/// so all three steps render this header identically: same insets, same
/// back-chevron slot, same indicator position.
///
/// [onBack] is null on the first step (Welcome has no previous step to
/// return to); a same-size `SizedBox` spacer takes the back button's place
/// there instead of just omitting it, so the indicator lands at the exact
/// same x position on every screen (this run's spec: "the indicator in the
/// same position on each").
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({super.key, required this.activeIndex, this.onBack});

  /// Which of the three dots is active (0 = Welcome, 1 = How It Works,
  /// 2 = Verify) - see [OnboardingProgressDots].
  final int activeIndex;

  /// Pops the onboarding flow's nested Navigator back to the previous step.
  /// Null on the first step (no back control there).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final back = onBack;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 10, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          back != null
              ? _BackButton(onTap: back)
              : const SizedBox(width: 36, height: 36),
          OnboardingProgressDots(activeIndex: activeIndex),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

/// The literal 3-dot progress indicator: the [activeIndex]-th dot renders
/// wide/sage, every other dot renders small/faded. Generalised over the
/// original hand-rolled two-screen version (which only ever had one fixed
/// "dot 2 is active" state) so all three onboarding steps share one
/// implementation instead of three near-identical copies.
class OnboardingProgressDots extends StatelessWidget {
  const OnboardingProgressDots({super.key, required this.activeIndex, this.count = 3});

  final int activeIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    Widget smallDot() => Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.onboardingDotInactive,
            shape: BoxShape.circle,
          ),
        );
    Widget activeDot() => Container(
          width: 18,
          height: 7,
          decoration: BoxDecoration(
            color: AppColors.sage,
            borderRadius: BorderRadius.circular(4),
          ),
        );
    return Row(
      key: const ValueKey('onboarding-progress-dots'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i != 0) const SizedBox(width: 6),
          i == activeIndex ? activeDot() : smallDot(),
        ],
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: GestureDetector(
        key: const ValueKey('onboarding-back-button'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(color: AppColors.awaitingChipBg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const BackChevronGlyph(color: AppColors.iconMuted, size: 16),
        ),
      ),
    );
  }
}
