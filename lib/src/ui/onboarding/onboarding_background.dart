import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

/// The single shared background washes for all five onboarding screens:
/// sage top-center wash + clay top-right wash.
const kOnboardingWashes = <RadialGradient>[
  RadialGradient(
    center: Alignment(0, -1.12),
    radius: 1.3,
    colors: [AppColors.onboardingWelcomeSageWash, AppColors.sageWashEnd],
  ),
  RadialGradient(
    center: Alignment(1, -0.92),
    radius: 0.9,
    colors: [AppColors.clayTintBg, AppColors.clayWashEnd],
  ),
];
