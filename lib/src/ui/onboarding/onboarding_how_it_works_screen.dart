import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../proof/verification_chrome.dart'
    show SealCheckmarkIcon, percentPositionToAlignment;
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/card_surface.dart';
import 'onboarding_header.dart';

/// Step 2 of 3 in the first-launch onboarding flow (Welcome -\> How It
/// Works -\> Verify - see `onboarding_flow.dart`'s doc comment): the three
/// "Do the thing. / Snap a photo. / AI verifies." step cards, MOVED here
/// out of [OnboardingWelcomeScreen] (step 1) per this consistency pass, so
/// each of the three onboarding ideas gets its own short, indicated step
/// instead of being crowded onto the welcome screen alongside the hero
/// illustration and headline.
///
/// There is no dedicated `.dc.html` for this screen: the canonical
/// `Cairn Onboarding.dc.html` originally carried this exact content (same
/// copy, same card markup) on its single welcome screen. This screen reuses
/// that markup/copy verbatim, just relocated onto its own step - an
/// authorized deviation from the single-screen source file (splitting one
/// screen into three), not invented UI (see this run's report).
class OnboardingHowItWorksScreen extends StatelessWidget {
  const OnboardingHowItWorksScreen({
    super.key,
    required this.onBack,
    required this.onContinue,
  });

  /// Pops back to the welcome screen (step 1) on [OnboardingFlow]'s nested
  /// Navigator.
  final VoidCallback onBack;

  /// Pushes the verification screen (step 3).
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ModalScaffold(
      // The same double sage/clay wash the welcome screen uses: this
      // content is a straight relocation of that screen's own step
      // cards, not a new visual design, so it keeps the background it
      // was authored against.
      washes: const [
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
      ],
      contourOrigin: percentPositionToAlignment(50, -4),
      contourRingColor: AppColors.premiumContourRing,
      child: Column(
        children: [
          OnboardingHeader(activeIndex: 1, onBack: onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(30, 24, 30, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    l10n.onboardingHowItWorksTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.onboardingVerificationHeadline,
                  ),
                  const SizedBox(height: 22),
                  _StepCard(
                    leading: const _NumberCircle(number: '1'),
                    title: l10n.onboardingStep1Title,
                    body: l10n.onboardingStep1Body,
                  ),
                  const SizedBox(height: 12),
                  _StepCard(
                    leading: const _NumberCircle(number: '2'),
                    title: l10n.onboardingStep2Title,
                    body: l10n.onboardingStep2Body,
                  ),
                  const SizedBox(height: 12),
                  _StepCard(
                    sage: true,
                    leading: const _CheckCircle(),
                    title: l10n.onboardingStep3Title,
                    body: l10n.onboardingStep3Body,
                    bodyColor: AppColors.sageReasonBody,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _Footer(l10n: l10n, onContinue: onContinue),
        ],
      ),
    );
  }
}

/// One of the three step rows: a leading circle (a numbered stone or, for
/// step 3, the sage check circle) plus a bold-lead/muted-remainder line,
/// matching `ReasonBanner`'s own lead/body composition elsewhere in this
/// app. [sage] switches the whole card to the design's flat sage-tinted
/// treatment for step 3 ("AI verifies."). Moved verbatim from
/// `onboarding_welcome_screen.dart` alongside the content it renders (see
/// this file's own doc comment).
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.leading,
    required this.title,
    required this.body,
    this.sage = false,
    this.bodyColor = AppColors.emptyStateBodyText,
  });

  final Widget leading;
  final String title;
  final String body;
  final bool sage;
  final Color bodyColor;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        leading,
        const SizedBox(width: 14),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$title ',
                  style: AppTextStyles.onboardingStepLead,
                ),
                TextSpan(
                  text: body,
                  style: AppTextStyles.onboardingStepBody.copyWith(
                    color: bodyColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (!sage) {
      // ParchmentPill's default 16/14 horizontal/vertical padding matches
      // the design's own `padding:14px 16px` for these cards exactly.
      return ParchmentPill(radius: 22, child: content);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.onboardingSageCardBg,
        border: Border.all(color: AppColors.onboardingSageCardBorder),
        borderRadius: BorderRadius.circular(22),
      ),
      child: content,
    );
  }
}

/// The dark "1"/"2" numbered stone circle leading the first two step cards.
class _NumberCircle extends StatelessWidget {
  const _NumberCircle({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: AppColors.inkStrong,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        number,
        style: const TextStyle(
          fontFamily: AppFontFamilies.zillaSlab,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: AppColors.heroInk,
        ),
      ),
    );
  }
}

/// The sage gradient check circle leading the third ("AI verifies.") step
/// card - the same checkmark glyph/path the verification-result screen's
/// own sage seal uses.
class _CheckCircle extends StatelessWidget {
  const _CheckCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: AppGradients.sageCircleSelected,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const SealCheckmarkIcon(size: 17, color: AppColors.sageChipText),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.l10n, required this.onContinue});

  final AppLocalizations l10n;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(30, 16, 30, 30),
      child: PrimaryButton(
        label: l10n.onboardingContinueButton,
        onPressed: onContinue,
      ),
    );
  }
}
