import 'package:flutter/material.dart'
    show Material, MaterialPageRoute, MaterialType, Text;
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../proof/verification_chrome.dart' show CloseCircleButton, percentPositionToAlignment;
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/cairn_stack.dart';
import '../widgets/message_snack_bar.dart';

/// Pushes [PremiumScreen] on top of the current route. Shared by every
/// Premium affordance in the app that navigates via a live [BuildContext]
/// (Profile's "Cairn Premium" row, Stats' "Go unlimited" link and "Deeper
/// insights" card) so they all navigate identically - the same idea as
/// Home's own `_openNewHabitScreen`, exported here since three separate
/// screens share this one destination rather than just one. The Daily Limit
/// screen's own "Go unlimited" is wired at its call site in
/// `proof_outcome_routing.dart` instead, via that function's own captured
/// `NavigatorState` (its callbacks can fire long after the calling screen's
/// `BuildContext` is gone - see that file's doc comment), rather than this
/// helper.
void openPremiumScreen(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => const PremiumScreen(),
  ));
}

enum _PremiumPlan { yearly, monthly }

/// `Cairn Premium.dc.html`: the Premium upsell screen, pushed (not a tab)
/// from every Premium affordance elsewhere in the app. Purely presentational
/// - Premium is post-MVP and there is no billing/IAP integration yet, so the
/// trial button and the plan cards' "selection" never purchase anything;
/// see [openPremiumScreen]'s call sites for the affordances that reach here.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  // Yearly is selected by default, matching the canonical design.
  _PremiumPlan _selectedPlan = _PremiumPlan.yearly;

  void _showComingSoon(AppLocalizations l10n) {
    context.showMessageSnackBar(l10n.premiumComingSoonSnackbar);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ModalScaffold(
      // This screen's own sage + terracotta washes (Cairn Premium.dc.html
      // is one of the few screens with two differently-tinted washes,
      // like Verify Result's own sage-forward pair) - distinct from the
      // washless treatment Trail/Stats use, per this run's spec.
      washes: const [
        RadialGradient(
          center: Alignment(0, -1.12),
          radius: 1.3,
          colors: [AppColors.premiumSageWash, AppColors.sageWashEnd],
        ),
        RadialGradient(
          center: Alignment(1, -0.92),
          radius: 0.9,
          colors: [AppColors.clayTintBg, AppColors.clayWashEnd],
        ),
      ],
      contourOrigin: percentPositionToAlignment(50, -6),
      contourRingColor: AppColors.premiumContourRing,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
            // Symmetric top-left corner (16/16, the same inset and distance
            // from top and left as VerificationHeader's own close button):
            // an authorized deviation from Cairn Premium.dc.html's own
            // top-right close-X, for cross-screen consistency (every
            // close/dismiss control in this app now sits top-left).
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: CloseCircleButton(onTap: () => Navigator.of(context).pop()),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(26, 2, 26, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Crest(l10n: l10n),
                  const SizedBox(height: 22),
                  _ValueList(l10n: l10n),
                  const SizedBox(height: 20),
                  _PlanCards(
                    l10n: l10n,
                    selected: _selectedPlan,
                    onSelect: (plan) => setState(() => _selectedPlan = plan),
                  ),
                ],
              ),
            ),
          ),
          _Footer(l10n: l10n, onStartTrial: () => _showComingSoon(l10n)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Crest: 3-stone cairn + eyebrow + headline
// ---------------------------------------------------------------------------

class _Crest extends StatelessWidget {
  const _Crest({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // The canonical design's crest has no ground shadow under its
        // 3-stone cairn (unlike every other CairnStack use in this app);
        // reusing this shared widget as-is (rather than hand-rolling a
        // shadow-less one-off) introduces one that isn't in the source
        // file - a deliberate, minor deviation noted in this run's report.
        const CairnStack(stoneCount: 3, highlightTop: true, scale: 0.6),
        const SizedBox(height: 12),
        Text(l10n.premiumEyebrow, style: AppTextStyles.premiumEyebrow),
        const SizedBox(height: 8),
        Text(
          l10n.premiumHeadline,
          textAlign: TextAlign.center,
          style: AppTextStyles.premiumHeadline,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Value list
// ---------------------------------------------------------------------------

enum _ValueGlyphShape { check, cloud, insights, widget }

class _ValueList extends StatelessWidget {
  const _ValueList({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _ValueRow(
        icon: const _ValueGlyph(shape: _ValueGlyphShape.check),
        title: l10n.premiumValueUnlimitedProofsTitle,
        subtitle: l10n.premiumValueUnlimitedProofsSubtitle,
      ),
      _ValueRow(
        icon: const _ValueGlyph(shape: _ValueGlyphShape.cloud),
        title: l10n.premiumValueCloudBackupTitle,
        subtitle: l10n.premiumValueCloudBackupSubtitle,
      ),
      _ValueRow(
        icon: const _ValueGlyph(shape: _ValueGlyphShape.insights),
        // Reuses the Stats screen's own "Deeper insights" copy verbatim -
        // identical literal text/meaning in the canonical design, not a
        // duplicate key (see the ARB's own doc comment on these two keys).
        title: l10n.statsDeeperInsightsTitle,
        subtitle: l10n.statsDeeperInsightsSubtitle,
      ),
      _ValueRow(
        icon: const _ValueGlyph(shape: _ValueGlyphShape.widget),
        title: l10n.premiumValueWidgetsTitle,
        subtitle: l10n.premiumValueWidgetsSubtitle,
      ),
      _ValueRow(
        icon: const _StoneStylesGlyph(),
        title: l10n.premiumValueStoneStylesTitle,
        subtitle: l10n.premiumValueStoneStylesSubtitle,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i != rows.length - 1)
            const Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: 4),
              child: SizedBox(height: 1, child: ColoredBox(color: AppColors.hairlineDivider)),
            ),
        ],
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.icon, required this.title, required this.subtitle});

  final Widget icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 11, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(color: AppColors.sageChipBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: icon,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTextStyles.accountStatusTitle),
                const SizedBox(height: 1),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The stacked-bars glyph for the "Stone styles" row: narrow-and-short on
/// top widening toward the bottom, the same `Column`-of-rounded-bars
/// silhouette [_StackedPebbleGlyph]-style widgets already use elsewhere
/// (`stats_screen.dart`, `trail_screen.dart`, `new_habit_screen.dart`'s
/// `_TitleFieldCairnGlyph`), duplicated privately here per this codebase's
/// existing precedent rather than shared, with this row's own literal
/// bar dimensions/colours from `Cairn Premium.dc.html`.
class _StoneStylesGlyph extends StatelessWidget {
  const _StoneStylesGlyph();

  static const _bars = [
    (width: 7.0, height: 3.0, color: AppColors.sageText),
    (width: 11.0, height: 4.0, color: AppColors.premiumStoneStylesMidBar),
    (width: 14.0, height: 4.0, color: AppColors.sageText),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final bar in _bars)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 0.5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bar.color,
                borderRadius: BorderRadius.circular(bar.height / 2),
              ),
              child: SizedBox(width: bar.width, height: bar.height),
            ),
          ),
      ],
    );
  }
}

class _ValueGlyph extends StatelessWidget {
  const _ValueGlyph({required this.shape});

  final _ValueGlyphShape shape;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _ValueGlyphPainter(shape: shape)),
    );
  }
}

class _ValueGlyphPainter extends CustomPainter {
  const _ValueGlyphPainter({required this.shape});

  final _ValueGlyphShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final paint = Paint()
      ..color = AppColors.sageText
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (shape) {
      case _ValueGlyphShape.check:
        // `M5 12.5l4.2 4.2L19 7`, stroke-width 2.2 - the same check path
        // used elsewhere in this app (e.g. profile_screen.dart's own
        // `_GlyphShape.check`).
        paint.strokeWidth = 2.2 * s;
        canvas.drawPath(
          Path()
            ..moveTo(p(5, 12.5).dx, p(5, 12.5).dy)
            ..lineTo(p(9.2, 16.7).dx, p(9.2, 16.7).dy)
            ..lineTo(p(19, 7).dx, p(19, 7).dy),
          paint,
        );
        break;

      case _ValueGlyphShape.cloud:
        // Faithful silhouette (not an exact bezier reproduction - see this
        // codebase's existing precedent, e.g. profile_screen.dart's bell/
        // shield glyphs) of `M7 17a4 4 0 0 1-.5-8A5.5 5.5 0 0 1 17 9.2 3.8
        // 3.8 0 0 1 16.5 17` (the cloud outline) plus `M12 12v6M12 12l-2.5
        // 2.5M12 12l2.5 2.5` (the download arrow inside it).
        paint.strokeWidth = 2 * s;
        final cloud = Path()
          ..moveTo(p(7, 17).dx, p(7, 17).dy)
          ..cubicTo(p(3.5, 16.5).dx, p(3.5, 16.5).dy, p(3, 11.5).dx, p(3, 11.5).dy,
              p(6.5, 9.5).dx, p(6.5, 9.5).dy)
          ..cubicTo(p(7, 6).dx, p(7, 6).dy, p(13, 5.5).dx, p(13, 5.5).dy, p(15, 9).dx, p(15, 9).dy)
          ..cubicTo(p(18, 9).dx, p(18, 9).dy, p(19, 12.5).dx, p(19, 12.5).dy, p(16.5, 15).dx,
              p(16.5, 15).dy)
          ..cubicTo(p(15.5, 16.5).dx, p(15.5, 16.5).dy, p(9, 17.5).dx, p(9, 17.5).dy, p(7, 17).dx,
              p(7, 17).dy);
        canvas.drawPath(cloud, paint);
        canvas.drawLine(p(12, 12), p(12, 18), paint);
        canvas.drawLine(p(12, 12), p(9.5, 14.5), paint);
        canvas.drawLine(p(12, 12), p(14.5, 14.5), paint);
        break;

      case _ValueGlyphShape.insights:
        // A consistency-curve line + baseline (approximated with cubic
        // curves, not an exact reproduction of the source's smooth-curve
        // `M4 19c3-6 5-8 8-8s3 2 3 4-2 3-3 3M4 19h10`) plus the exact
        // straight-line sparkle `M18 5l1.5 3 3 .5-2 2 .5 3L18 15`.
        paint.strokeWidth = 2 * s;
        canvas.drawPath(
          Path()
            ..moveTo(p(4, 19).dx, p(4, 19).dy)
            ..cubicTo(p(7, 13).dx, p(7, 13).dy, p(9, 11).dx, p(9, 11).dy, p(12, 11).dx, p(12, 11).dy)
            ..cubicTo(p(15, 11).dx, p(15, 11).dy, p(15, 13).dx, p(15, 13).dy, p(12, 14).dx, p(12, 14).dy),
          paint,
        );
        canvas.drawLine(p(4, 19), p(14, 19), paint);
        canvas.drawPath(
          Path()
            ..moveTo(p(18, 5).dx, p(18, 5).dy)
            ..lineTo(p(19.5, 8).dx, p(19.5, 8).dy)
            ..lineTo(p(22.5, 8.5).dx, p(22.5, 8.5).dy)
            ..lineTo(p(20.5, 10.5).dx, p(20.5, 10.5).dy)
            ..lineTo(p(21, 13.5).dx, p(21, 13.5).dy)
            ..lineTo(p(18, 15).dx, p(18, 15).dy),
          paint,
        );
        break;

      case _ValueGlyphShape.widget:
        // `<rect x="4" y="4" width="16" height="16" rx="3">` + `M8 4v4M4 9h4`
        // - a small widget-grid corner mark.
        paint.strokeWidth = 2 * s;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(4 * s, 4 * s, 16 * s, 16 * s),
            Radius.circular(3 * s),
          ),
          paint,
        );
        canvas.drawLine(p(8, 4), p(8, 8), paint);
        canvas.drawLine(p(4, 9), p(8, 9), paint);
        break;
    }
  }

  @override
  bool shouldRepaint(_ValueGlyphPainter oldDelegate) => shape != oldDelegate.shape;
}

// ---------------------------------------------------------------------------
// Plan cards
// ---------------------------------------------------------------------------

class _PlanCards extends StatelessWidget {
  const _PlanCards({required this.l10n, required this.selected, required this.onSelect});

  final AppLocalizations l10n;
  final _PremiumPlan selected;
  final ValueChanged<_PremiumPlan> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PlanCard(
          key: const ValueKey('plan-card-yearly'),
          selected: selected == _PremiumPlan.yearly,
          title: l10n.premiumYearlyPlanTitle,
          subtitle: l10n.premiumYearlyPlanSubtitle,
          price: l10n.premiumYearlyPlanPrice,
          ribbonLabel: l10n.premiumBestValueRibbon,
          onTap: () => onSelect(_PremiumPlan.yearly),
        ),
        const SizedBox(height: 11),
        _PlanCard(
          key: const ValueKey('plan-card-monthly'),
          selected: selected == _PremiumPlan.monthly,
          title: l10n.premiumMonthlyPlanTitle,
          subtitle: l10n.premiumMonthlyPlanSubtitle,
          price: l10n.premiumMonthlyPlanPrice,
          ribbonLabel: null,
          onTap: () => onSelect(_PremiumPlan.monthly),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    super.key,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.ribbonLabel,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final String price;
  final String? ribbonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.rowCard);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        gradient: selected ? AppGradients.premiumBg : AppGradients.chipInactive,
        borderRadius: radius,
        border: Border.all(
          color: selected ? AppColors.sage : AppColors.premiumUnselectedCardBorder,
          width: selected ? 2 : 1.5,
        ),
        boxShadow: selected ? AppShadows.premiumSelectedPlanCard : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(height: 1.5, child: ColoredBox(color: AppColors.panelTopHighlight)),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 18, vertical: 16),
              child: Material(
                type: MaterialType.transparency,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: selected
                              ? AppTextStyles.premiumPlanTitle
                              : AppTextStyles.premiumPlanTitle.copyWith(color: AppColors.inkDimmed),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: AppTextStyles.caption),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          price,
                          style: selected
                              ? AppTextStyles.premiumPlanPrice
                              : AppTextStyles.premiumPlanPrice.copyWith(color: AppColors.inkDimmed),
                        ),
                        const SizedBox(width: 12),
                        _PlanRadio(selected: selected),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        selected: selected,
        label: title,
        child: ribbonLabel == null
            ? card
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  card,
                  Positioned(top: -11, left: 18, child: _RibbonBadge(label: ribbonLabel!)),
                ],
              ),
      ),
    );
  }
}

class _PlanRadio extends StatelessWidget {
  const _PlanRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.scheduledPillBorder, width: 2),
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(color: AppColors.sage, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const SizedBox(width: 13, height: 13, child: CustomPaint(painter: _RadioCheckPainter())),
    );
  }
}

/// The selected radio's checkmark (`M5 12.5l4.2 4.2L19 7`, stroke-width 3) -
/// the same check path drawn elsewhere in this app, at a heavier stroke to
/// match the design's filled-radio treatment.
class _RadioCheckPainter extends CustomPainter {
  const _RadioCheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final paint = Paint()
      ..color = AppColors.premiumOnSageText
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(p(5, 12.5).dx, p(5, 12.5).dy)
        ..lineTo(p(9.2, 16.7).dx, p(9.2, 16.7).dy)
        ..lineTo(p(19, 7).dx, p(19, 7).dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(_RadioCheckPainter oldDelegate) => false;
}

class _RibbonBadge extends StatelessWidget {
  const _RibbonBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        gradient: AppGradients.premiumRibbonBg,
        borderRadius: BorderRadius.circular(11),
        boxShadow: AppShadows.premiumRibbon,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Text(label, style: AppTextStyles.premiumRibbonLabel),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------

class _Footer extends StatelessWidget {
  const _Footer({required this.l10n, required this.onStartTrial});

  final AppLocalizations l10n;
  final VoidCallback onStartTrial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(26, 12, 26, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(label: l10n.premiumStartTrialButton, onPressed: onStartTrial),
          const SizedBox(height: 9),
          Text(
            l10n.premiumTrialSubtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.premiumTrialSubtitle,
          ),
          const SizedBox(height: 9),
          _FooterLinks(l10n: l10n),
        ],
      ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks({required this.l10n});

  final AppLocalizations l10n;

  // Restore/Terms/Privacy have no real destination yet: Restore purchase is
  // a Phase 4/premium-billing concern and Terms/Privacy have no legal
  // screens in this app at all. Silent no-ops-for-now, same scope decision
  // as the Profile settings list's own navigational placeholders
  // (`_SettingsSection._noOp` in profile_screen.dart) - a later phase wires
  // real destinations.
  static void _noOp() {}

  @override
  Widget build(BuildContext context) {
    Widget link(String label) {
      return GestureDetector(
        onTap: _noOp,
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          button: true,
          label: label,
          child: Text(label, style: AppTextStyles.premiumFooterLinkLabel),
        ),
      );
    }

    Widget dot() => Container(
          width: 3,
          height: 3,
          margin: const EdgeInsetsDirectional.symmetric(horizontal: 8),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.premiumFooterDotColor),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reuses the Profile settings list's own "Restore purchase" copy
        // verbatim - identical literal text/meaning, not a duplicate key.
        link(l10n.profileRestorePurchaseRow),
        dot(),
        link(l10n.premiumTermsLink),
        dot(),
        link(l10n.premiumPrivacyLink),
      ],
    );
  }
}
