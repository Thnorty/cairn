import 'package:flutter/material.dart' show Colors, Scaffold;
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../proof/verification_chrome.dart'
    show SealCheckmarkIcon, percentPositionToAlignment;
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_text_styles.dart';
import '../theme/screen_background.dart';
import '../widgets/buttons.dart';
import '../widgets/cairn_stack.dart';
import '../widgets/card_surface.dart';

/// `Cairn Onboarding.dc.html`: the first of the two first-launch onboarding
/// screens, hosted (along with [OnboardingVerificationScreen]) inside
/// [OnboardingFlow]'s own nested `Navigator` - never pushed on the app's
/// root navigator, so completing onboarding can cleanly swap the whole
/// subtree for [AppShell] (see that widget's doc comment).
class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({
    super.key,
    required this.onStartClimbing,
    required this.onAlreadyHaveAccount,
  });

  /// Pushes the verification screen on [OnboardingFlow]'s nested Navigator.
  final VoidCallback onStartClimbing;

  /// Shows the "coming soon" snackbar (Phase 4 accounts are out of scope).
  final VoidCallback onAlreadyHaveAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ScreenBackground(
        washes: const [
          RadialGradient(
            center: Alignment(0, -1.12),
            radius: 1.3,
            colors: [AppColors.onboardingWelcomeSageWash, Color(0x0096A678)],
          ),
          RadialGradient(
            center: Alignment(1, -0.92),
            radius: 0.9,
            colors: [AppColors.clayTintBg, Color(0x00B27C5C)],
          ),
        ],
        contourOrigin: percentPositionToAlignment(50, -4),
        contourRingColor: AppColors.premiumContourRing,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                // LayoutBuilder + a minHeight-constrained inner Column
                // vertically centers this screen's content when it's
                // shorter than the viewport (this screen has noticeably
                // less content than the canonical design's own fixed
                // 392x846 mockup, since Flutter's text/spacing metrics
                // don't reproduce the source CSS pixel-for-pixel) while
                // still scrolling normally on a shorter/narrower real
                // device where it doesn't fit.
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      30,
                      14,
                      30,
                      0,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CairnStack(
                            stoneCount: 6,
                            highlightTop: true,
                            scale: 1.15,
                          ),
                          const SizedBox(height: 30),
                          _Headline(l10n: l10n),
                          const SizedBox(height: 12),
                          Text(
                            l10n.onboardingWelcomeSubhead,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.emptyStateBody,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.onboardingWelcomeClarifier,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.onboardingClarifier,
                          ),
                          const SizedBox(height: 28),
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
                ),
              ),
              _Footer(
                l10n: l10n,
                onStartClimbing: onStartClimbing,
                onAlreadyHaveAccount: onAlreadyHaveAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two-line headline, rendered as two separate [Text] widgets (rather
/// than one `Text.rich`) so each line remains independently discoverable via
/// `find.text()` in widget tests - the design's own markup is a `<br>`
/// inside one text block, but there is no bold-lead/plain-remainder split
/// within either line the way the step cards below have, so two stacked
/// [Text] widgets reproduce it exactly with none of `Text.rich`'s
/// whole-string-only matching caveat (see `ReasonBanner`'s own leadText/
/// bodyText split for the pattern this app uses when a mid-line style split
/// is actually needed).
class _Headline extends StatelessWidget {
  const _Headline({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          l10n.onboardingWelcomeHeadlineLine1,
          textAlign: TextAlign.center,
          style: AppTextStyles.onboardingHeadline,
        ),
        Text(
          l10n.onboardingWelcomeHeadlineAccent,
          textAlign: TextAlign.center,
          style: AppTextStyles.onboardingHeadline.copyWith(
            color: AppColors.sageText,
          ),
        ),
      ],
    );
  }
}

/// One of the three step rows: a leading circle (a numbered stone or, for
/// step 3, the sage check circle) plus a bold-lead/muted-remainder line,
/// matching `ReasonBanner`'s own lead/body composition elsewhere in this
/// app. [sage] switches the whole card to the design's flat sage-tinted
/// treatment for step 3 ("AI verifies.").
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
  const _Footer({
    required this.l10n,
    required this.onStartClimbing,
    required this.onAlreadyHaveAccount,
  });

  final AppLocalizations l10n;
  final VoidCallback onStartClimbing;
  final VoidCallback onAlreadyHaveAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(30, 16, 30, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: l10n.onboardingStartClimbingButton,
            onPressed: onStartClimbing,
          ),
          const SizedBox(height: 10),
          Center(
            child: TextGhostButton(
              label: l10n.onboardingAlreadyHaveAccountButton,
              onPressed: onAlreadyHaveAccount,
            ),
          ),
        ],
      ),
    );
  }
}
