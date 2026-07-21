import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../proof/verification_chrome.dart' show percentPositionToAlignment;
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/cairn_stack.dart';
import 'onboarding_header.dart';

/// `Cairn Onboarding.dc.html`: step 1 of 3 in the first-launch onboarding
/// flow (Welcome -\> How It Works -\> Verify - see `onboarding_flow.dart`'s
/// doc comment), hosted (along with the other two steps) inside
/// [OnboardingFlow]'s own nested `Navigator` - never pushed on the app's
/// root navigator, so completing onboarding can cleanly swap the whole
/// subtree for [AppShell] (see that widget's doc comment).
///
/// The canonical design's single screen originally combined this hero/
/// headline content with the three "Do the thing / Snap a photo / AI
/// verifies" step cards below it. This run's spec splits those cards out
/// into their own step 2 screen ([OnboardingHowItWorksScreen]) so the flow
/// reads as three short, individually-indicated steps rather than one
/// longer one plus a bare second screen - an authorized deviation from the
/// single-screen source file, not invented UI (see this run's report).
class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({
    super.key,
    required this.onStartClimbing,
    required this.onAlreadyHaveAccount,
  });

  /// Pushes the How It Works screen (step 2) on [OnboardingFlow]'s nested
  /// Navigator.
  final VoidCallback onStartClimbing;

  /// Shows the "coming soon" snackbar (Phase 4 accounts are out of scope).
  final VoidCallback onAlreadyHaveAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ModalScaffold(
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
          // No back control on this first step - see this run's spec
          // ("no back control (it's first)"). OnboardingHeader itself
          // is what keeps the indicator's y position identical across
          // all three steps: it renders a same-size spacer here in
          // place of a back button rather than this screen omitting
          // the header row outright.
          const OnboardingHeader(activeIndex: 0),
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
