import 'package:flutter/material.dart' show Colors, Material, MaterialType, Scaffold;
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/date_number_formatting.dart';
import '../../services/points_service.dart';
import '../proof/verification_chrome.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/screen_background.dart';
import '../widgets/buttons.dart';
import '../widgets/card_surface.dart';
import '../widgets/cairn_stack.dart';
import '../widgets/glyphs.dart';

/// `Cairn How Cairns Work.dc.html`: a just-in-time explainer sheet for the
/// per-task cairn/stone vocabulary (see CLAUDE.md's "Per-task cairns"
/// domain rule), pushed from a small "?" info button on the Trail screen's
/// header (`trail_screen.dart`'s `_InfoCircleButton`) rather than shown
/// unprompted - a user who already understands cairns should never see
/// this uninvited.
///
/// Reuses [VerificationHeader] for its own close-X/label header shell - the
/// same reuse `PremiumScreen` and `CameraUnavailableScreen` already make of
/// this shared chrome for an unrelated screen's own label - and
/// [ParchmentPill] for the legend and explainer-row cards, rather than
/// inventing new equivalents for either. The second explainer row's
/// mid-sentence bold "+N m" span is composed directly with `Text.rich`
/// (not [ReasonBanner], which owns its own icon/background/padding chrome
/// unsuited to sitting *inside* an existing icon+title+body row) using the
/// same lead/emphasis/trail ARB split [ReasonBanner]'s own `spans` escape
/// hatch documents (see `camera_unavailable_screen.dart`'s identical
/// `settingsHintLead`/`settingsHintEmphasis`/`settingsHintTrail` split).
class HowCairnsWorkScreen extends StatelessWidget {
  const HowCairnsWorkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final bonus = formatMetresNumber(PointsService.cairnCapBonus, locale);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ScreenBackground(
        // A single, lighter sage top wash and no second corner wash -
        // `Cairn How Cairns Work.dc.html`'s own background-image is just
        // one `radial-gradient(135% 46% at 50% -6%, rgba(150,166,120,.24),
        // transparent 62%)`, unlike the two-wash treatment every
        // verification-outcome screen uses.
        washes: const [
          RadialGradient(
            center: Alignment(0, -1.12),
            radius: 1.15,
            colors: [AppColors.onboardingVerificationSageWash, AppColors.sageWashEnd],
          ),
        ],
        contourOrigin: percentPositionToAlignment(50, -4),
        contourRingColor: AppColors.premiumContourRing,
        child: SafeArea(
          child: Column(
            children: [
              VerificationHeader(
                onClose: () => Navigator.of(context).pop(),
                label: l10n.howCairnsWorkHeaderLabel,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 6, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        l10n.howCairnsWorkTitle,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.howCairnsWorkTitle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.howCairnsWorkSubhead,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.howCairnsWorkSubhead,
                      ),
                      const SizedBox(height: 20),
                      const _StateLegendCard(),
                      const SizedBox(height: 16),
                      _ExplainerRow(
                        icon: const _IconCircle(
                          background: AppColors.sageChipBg,
                          child: SealCheckmarkIcon(color: AppColors.sageText, size: 15),
                        ),
                        title: l10n.howCairnsWorkRow1Title,
                        body: Text(
                          l10n.howCairnsWorkRow1Body,
                          style: AppTextStyles.onboardingPointBody,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ExplainerRow(
                        icon: const _IconCircle(
                          background: AppColors.clayTintBg,
                          child: Text(
                            '10',
                            style: TextStyle(
                              fontFamily: AppFontFamilies.zillaSlab,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.terracotta,
                            ),
                          ),
                        ),
                        title: l10n.howCairnsWorkRow2Title,
                        body: Material(
                          type: MaterialType.transparency,
                          child: Text.rich(
                            TextSpan(
                              style: AppTextStyles.onboardingPointBody,
                              children: [
                                TextSpan(text: '${l10n.howCairnsWorkRow2Lead} '),
                                TextSpan(
                                  text: l10n.howCairnsWorkRow2Bonus(bonus),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.clayHeading,
                                  ),
                                ),
                                TextSpan(text: ' ${l10n.howCairnsWorkRow2Trail}'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ExplainerRow(
                        icon: const _IconCircle(
                          background: AppColors.awaitingChipBg,
                          child: LightningGlyph(color: AppColors.clockGlyph, size: 14),
                        ),
                        title: l10n.howCairnsWorkRow3Title,
                        body: Text(
                          l10n.howCairnsWorkRow3Body,
                          style: AppTextStyles.onboardingPointBody,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ExplainerRow(
                        icon: const _RankIconCircle(),
                        title: l10n.howCairnsWorkRow4Title,
                        body: Text(
                          l10n.howCairnsWorkRow4Body,
                          style: AppTextStyles.onboardingPointBody,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              VerificationFooter(
                children: [
                  PrimaryButton(
                    label: l10n.howCairnsWorkGotItButton,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three-state (Growing/Capped/Broken) legend card at the top of the
/// sheet: three small mini-cairns, each mirroring the exact visual
/// treatment the Trail screen itself uses for the same three cairn states
/// (`trail_screen.dart`'s `_GrowingCairnNode`/`_SettledCairnNode`), just at
/// a smaller scale, so this legend is a genuine preview of what a user will
/// see there rather than an invented illustration.
class _StateLegendCard extends StatelessWidget {
  const _StateLegendCard();

  static const double _legendCairnScale = 0.55;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ParchmentPill(
      radius: 24,
      padding: const EdgeInsetsDirectional.fromSTEB(10, 18, 10, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _LegendItem(
            cairn: const CairnStack(
              stoneCount: 3,
              highlightTop: true,
              scale: _legendCairnScale,
            ),
            label: l10n.howCairnsWorkLegendGrowing,
            labelStyle: AppTextStyles.howCairnsWorkLegendLabel.copyWith(
              color: AppColors.sageText,
            ),
          ),
          _LegendItem(
            cairn: const CairnStack(stoneCount: 4, scale: _legendCairnScale),
            label: l10n.howCairnsWorkLegendCapped,
            labelStyle: AppTextStyles.howCairnsWorkLegendLabel.copyWith(
              color: AppColors.inkDimmed,
            ),
          ),
          _LegendItem(
            cairn: Opacity(
              opacity: 0.6,
              child: const CairnStack(
                stoneCount: 3,
                muted: true,
                mutedOpacity: false,
                scale: _legendCairnScale,
              ),
            ),
            label: l10n.howCairnsWorkLegendBroken,
            labelStyle: AppTextStyles.howCairnsWorkLegendLabel.copyWith(
              color: AppColors.textFaint,
            ),
            labelIcon: const LightningGlyph(color: AppColors.textFaint, size: 10),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.cairn,
    required this.label,
    required this.labelStyle,
    this.labelIcon,
  });

  final Widget cairn;
  final String label;
  final TextStyle labelStyle;
  final Widget? labelIcon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 52, child: Center(child: cairn)),
          const SizedBox(height: 9),
          Material(
            type: MaterialType.transparency,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (labelIcon != null) ...[labelIcon!, const SizedBox(width: 3)],
                Text(label, style: labelStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One explainer row: an icon circle, a bold title, and a body line
/// (plain or rich text - the second row needs a mid-sentence bold "+N m"
/// span, the rest don't).
class _ExplainerRow extends StatelessWidget {
  const _ExplainerRow({required this.icon, required this.title, required this.body});

  final Widget icon;
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return ParchmentPill(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTextStyles.howCairnsWorkRowTitle),
                const SizedBox(height: 2),
                body,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.background, required this.child});

  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// The fourth row's icon circle: the same sage-badge gradient/mountain
/// glyph as Profile's rank hero and the Trail rank pill
/// (`AppGradients.heroBadge` + [AppColors.heroMountainStroke]).
class _RankIconCircle extends StatelessWidget {
  const _RankIconCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.42, -1),
          end: Alignment(0.42, 1),
          colors: [AppColors.heroBadgeLight, AppColors.heroBadgeDark],
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const MountainGlyph(color: AppColors.heroMountainStroke, size: 15),
    );
  }
}
