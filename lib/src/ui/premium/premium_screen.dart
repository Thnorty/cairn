import 'package:flutter/material.dart'
    show CircularProgressIndicator, Material, MaterialPageRoute, MaterialType, Text;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../config.dart';
import '../../premium/premium_service.dart';
import '../../providers.dart';
import '../proof/verification_chrome.dart'
    show CloseCircleButton, percentPositionToAlignment;
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
/// insights" card) so they all navigate identically.
void openPremiumScreen(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => const PremiumScreen(),
  ));
}

enum _PremiumPlan { yearly, monthly }

/// Fallback savings percentage matching the canonical design ("SAVE 41%"),
/// used whenever a live offering isn't available or its prices don't allow
/// a sane computation.
const int _fallbackSavePercent = 41;

/// Computes how much cheaper the annual plan is versus paying monthly for a
/// year, as a whole-number percentage. Floors rather than rounds so a
/// borderline ratio (e.g. 41.5% or 41.7%) reads as the conservative "SAVE
/// 41%" rather than overstating the discount, and clamps to 0..99 so a
/// malformed store response can never render a negative or absurd figure.
int _computeSavePercent(PremiumOffering? offering) {
  final annual = offering?.annual;
  final monthly = offering?.monthly;
  if (annual == null || monthly == null || monthly.price <= 0) {
    return _fallbackSavePercent;
  }
  final ratio = 1 - (annual.price / (monthly.price * 12));
  final percent = (ratio * 100).floor();
  return percent.clamp(0, 99);
}

/// `Cairn Premium.dc.html` & `Cairn Premium - Billing States.dc.html`:
/// the Premium paywall screen.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  // Yearly is selected by default, matching the canonical design.
  _PremiumPlan _selectedPlan = _PremiumPlan.yearly;
  bool _inFlight = false;

  Future<void> _launchUrl(String urlString) async {
    if (urlString.isEmpty) return;
    try {
      final uri = Uri.parse(urlString);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _handleManageSubscription() {
    _launchUrl('https://play.google.com/store/account/subscriptions');
  }

  Future<void> _handlePurchase(PremiumOffering offering) async {
    final plan =
        _selectedPlan == _PremiumPlan.yearly ? offering.annual : offering.monthly;
    if (plan == null) return;
    setState(() => _inFlight = true);
    try {
      final outcome = await ref.read(premiumServiceProvider).purchase(plan);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      switch (outcome) {
        case PremiumPurchaseSucceeded():
          context.showMessageSnackBar(
            l10n.premiumSuccessSnackbar,
            tone: MessageTone.success,
          );
          Navigator.of(context).pop();
        case PremiumPurchaseCancelled():
          break;
        case PremiumPurchaseFailed(:final message):
          context.showMessageSnackBar(
            message,
            tone: MessageTone.neutral,
          );
      }
    } finally {
      if (mounted) {
        setState(() => _inFlight = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _inFlight = true);
    try {
      final outcome = await ref.read(premiumServiceProvider).restore();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      switch (outcome) {
        case PremiumPurchaseSucceeded(:final isPremium):
          if (isPremium) {
            context.showMessageSnackBar(
              l10n.premiumRestoreSuccessSnackbar,
              tone: MessageTone.success,
            );
            Navigator.of(context).pop();
          } else {
            context.showMessageSnackBar(
              l10n.premiumRestoreNoneSnackbar,
              tone: MessageTone.muted,
            );
          }
        case PremiumPurchaseCancelled():
          break;
        case PremiumPurchaseFailed(:final message):
          context.showMessageSnackBar(
            message,
            tone: MessageTone.neutral,
          );
      }
    } finally {
      if (mounted) {
        setState(() => _inFlight = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final offeringAsync = ref.watch(premiumOfferingProvider);
    final offering = offeringAsync.asData?.value;
    final isPremium = ref.watch(premiumStatusProvider);

    final yearlyPrice = offering?.annual?.priceString ?? l10n.premiumYearlyPlanPrice;
    final monthlyPrice = offering?.monthly?.priceString ?? l10n.premiumMonthlyPlanPrice;
    final yearlyPerMonth =
        offering?.annual?.pricePerMonthString ?? l10n.premiumYearlyPerMonthPrice;
    final savePercent = _computeSavePercent(offering);

    final VoidCallback? onStartTrial = (!isPremium && offering != null && !_inFlight)
        ? () => _handlePurchase(offering)
        : null;

    final VoidCallback? onRestore = !_inFlight ? _handleRestore : null;

    return ModalScaffold(
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
                  if (isPremium) ...[
                    _EntitlementPanel(l10n: l10n),
                    const SizedBox(height: 18),
                  ],
                  _ValueList(l10n: l10n),
                  if (!isPremium) ...[
                    const SizedBox(height: 20),
                    _PlanCards(
                      l10n: l10n,
                      selected: _selectedPlan,
                      yearlyPrice: yearlyPrice,
                      monthlyPrice: monthlyPrice,
                      yearlyPerMonth: yearlyPerMonth,
                      savePercent: savePercent,
                      enabled: !_inFlight,
                      onSelect: (plan) => setState(() => _selectedPlan = plan),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isPremium)
            _AlreadyPremiumFooter(
              l10n: l10n,
              onManageSubscription: _handleManageSubscription,
              onRestore: onRestore,
            )
          else
            _Footer(
              l10n: l10n,
              inFlight: _inFlight,
              selectedPeriod: _selectedPlan,
              selectedPrice:
                  _selectedPlan == _PremiumPlan.yearly ? yearlyPrice : monthlyPrice,
              onStartTrial: onStartTrial,
              onRestore: onRestore,
            ),
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
// Entitlement panel (already premium)
// ---------------------------------------------------------------------------

class _EntitlementPanel extends StatelessWidget {
  const _EntitlementPanel({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF2EDE2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x593C3223),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.sage,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CustomPaint(
                painter: _RadioCheckPainter(
                  color: Color(0xFFF4F0E6),
                  strokeWidth: 2.8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.premiumAlreadySubscribedTitle,
                  style: AppTextStyles.premiumPlanTitle,
                ),
                const SizedBox(height: 1),
                Text(
                  l10n.premiumAlreadySubscribedSubtitle,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
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
        icon: const _ValueGlyph(shape: _ValueGlyphShape.check, isLive: true),
        title: l10n.premiumValueUnlimitedProofsTitle,
        subtitle: l10n.premiumValueUnlimitedProofsSubtitle,
        tag: l10n.premiumTagAvailableNow,
        isLive: true,
      ),
      _ValueRow(
        icon: const _ValueGlyph(shape: _ValueGlyphShape.cloud, isLive: false),
        title: l10n.premiumValueCloudBackupTitle,
        subtitle: l10n.premiumValueCloudBackupSubtitle,
        tag: l10n.premiumTagComingSoon,
        isLive: false,
      ),
      _ValueRow(
        icon: const _ValueGlyph(shape: _ValueGlyphShape.insights, isLive: true),
        title: l10n.statsDeeperInsightsTitle,
        subtitle: l10n.statsDeeperInsightsSubtitle,
        tag: l10n.premiumTagAvailableNow,
        isLive: true,
      ),
      _ValueRow(
        icon: const _ValueGlyph(shape: _ValueGlyphShape.widget, isLive: false),
        title: l10n.premiumValueWidgetsTitle,
        subtitle: l10n.premiumValueWidgetsSubtitle,
        tag: l10n.premiumTagComingSoon,
        isLive: false,
      ),
      _ValueRow(
        icon: const _StoneStylesGlyph(isLive: true),
        title: l10n.premiumValueStoneStylesTitle,
        subtitle: l10n.premiumValueStoneStylesSubtitle,
        tag: l10n.premiumTagAvailableNow,
        isLive: true,
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
  const _ValueRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.isLive,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final String tag;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final titleColor = isLive ? AppColors.inkPrimary : AppColors.premiumDimmedTitle;
    final subtitleColor = isLive ? AppColors.textMuted : AppColors.premiumDimmedSubtitle;
    final tagColor = isLive ? AppColors.premiumTagAvailableNowText : AppColors.premiumTagComingSoonText;
    final tagBg = isLive ? AppColors.premiumTagAvailableNowBg : AppColors.premiumTagComingSoonBg;

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
                Text(title, style: AppTextStyles.accountStatusTitle.copyWith(color: titleColor)),
                const SizedBox(height: 1),
                Text(subtitle, style: AppTextStyles.caption.copyWith(color: subtitleColor)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(8)),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: tagColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoneStylesGlyph extends StatelessWidget {
  const _StoneStylesGlyph({this.isLive = true});

  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final topBottomColor = isLive ? AppColors.sageText : AppColors.premiumDimmedIcon;
    final midColor = isLive ? AppColors.premiumStoneStylesMidBar : AppColors.premiumDimmedIcon;
    final bars = [
      (width: 7.0, height: 3.0, color: topBottomColor),
      (width: 11.0, height: 4.0, color: midColor),
      (width: 14.0, height: 4.0, color: topBottomColor),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final bar in bars)
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
  const _ValueGlyph({required this.shape, this.isLive = true});

  final _ValueGlyphShape shape;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _ValueGlyphPainter(shape: shape, isLive: isLive)),
    );
  }
}

class _ValueGlyphPainter extends CustomPainter {
  const _ValueGlyphPainter({required this.shape, required this.isLive});

  final _ValueGlyphShape shape;
  final bool isLive;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final strokeColor = isLive ? AppColors.sageText : AppColors.premiumDimmedIcon;
    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (shape) {
      case _ValueGlyphShape.check:
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
  bool shouldRepaint(_ValueGlyphPainter oldDelegate) =>
      shape != oldDelegate.shape || isLive != oldDelegate.isLive;
}

// ---------------------------------------------------------------------------
// Plan cards
// ---------------------------------------------------------------------------

class _PlanCards extends StatelessWidget {
  const _PlanCards({
    required this.l10n,
    required this.selected,
    required this.yearlyPrice,
    required this.monthlyPrice,
    required this.yearlyPerMonth,
    required this.savePercent,
    required this.enabled,
    required this.onSelect,
  });

  final AppLocalizations l10n;
  final _PremiumPlan selected;
  final String yearlyPrice;
  final String monthlyPrice;
  final String yearlyPerMonth;
  final int savePercent;
  final bool enabled;
  final ValueChanged<_PremiumPlan> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PlanCard(
          key: const ValueKey('plan-card-yearly'),
          selected: selected == _PremiumPlan.yearly,
          title: l10n.premiumYearlyPlanTitle,
          subtitle: l10n.premiumYearlyPlanSubtitle(yearlyPrice, yearlyPerMonth),
          price: yearlyPrice,
          ribbonLabel: l10n.premiumBestValueRibbon(savePercent),
          onTap: enabled ? () => onSelect(_PremiumPlan.yearly) : null,
        ),
        const SizedBox(height: 11),
        _PlanCard(
          key: const ValueKey('plan-card-monthly'),
          selected: selected == _PremiumPlan.monthly,
          title: l10n.premiumMonthlyPlanTitle,
          subtitle: l10n.premiumMonthlyPlanSubtitle,
          price: monthlyPrice,
          ribbonLabel: null,
          onTap: enabled ? () => onSelect(_PremiumPlan.monthly) : null,
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
  final VoidCallback? onTap;

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
        enabled: onTap != null,
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
      child: const SizedBox(
        width: 13,
        height: 13,
        child: CustomPaint(painter: _RadioCheckPainter()),
      ),
    );
  }
}

class _RadioCheckPainter extends CustomPainter {
  const _RadioCheckPainter({
    this.color = AppColors.premiumOnSageText,
    this.strokeWidth = 3.0,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * s
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
  bool shouldRepaint(_RadioCheckPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
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
// Footers
// ---------------------------------------------------------------------------

class _Footer extends StatelessWidget {
  const _Footer({
    required this.l10n,
    required this.inFlight,
    required this.selectedPeriod,
    required this.selectedPrice,
    required this.onStartTrial,
    required this.onRestore,
  });

  final AppLocalizations l10n;
  final bool inFlight;
  final _PremiumPlan selectedPeriod;
  final String selectedPrice;
  final VoidCallback? onStartTrial;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final trialSubtitle = selectedPeriod == _PremiumPlan.yearly
        ? l10n.premiumTrialSubtitleYearly(selectedPrice)
        : l10n.premiumTrialSubtitleMonthly(selectedPrice);

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(26, 12, 26, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: inFlight
                ? l10n.premiumPurchasingButtonLabel
                : l10n.premiumStartTrialButton,
            onPressed: onStartTrial,
            icon: inFlight
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.buttonText,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 9),
          Text(
            trialSubtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.premiumTrialSubtitle,
          ),
          const SizedBox(height: 9),
          _FooterLinks(l10n: l10n, onRestore: onRestore),
        ],
      ),
    );
  }
}

class _AlreadyPremiumFooter extends StatelessWidget {
  const _AlreadyPremiumFooter({
    required this.l10n,
    required this.onManageSubscription,
    required this.onRestore,
  });

  final AppLocalizations l10n;
  final VoidCallback onManageSubscription;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(26, 12, 26, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ManageSubscriptionButton(onPressed: onManageSubscription),
          const SizedBox(height: 12),
          _FooterLinks(l10n: l10n, onRestore: onRestore),
        ],
      ),
    );
  }
}

class _ManageSubscriptionButton extends StatelessWidget {
  const _ManageSubscriptionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: AppGradients.chipInactive,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.premiumUnselectedCardBorder, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          AppLocalizations.of(context)!.premiumManageSubscriptionButton,
          style: AppTextStyles.buttonLabelLarge.copyWith(color: AppColors.inkDimmed),
        ),
      ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks({required this.l10n, this.onRestore});

  final AppLocalizations l10n;
  final VoidCallback? onRestore;

  Future<void> _launchUrl(String urlString) async {
    if (urlString.isEmpty) return;
    try {
      final uri = Uri.parse(urlString);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    Widget link(String label, VoidCallback? onTap) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          button: true,
          enabled: onTap != null,
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
        link(l10n.profileRestorePurchaseRow, onRestore),
        dot(),
        link(
          l10n.premiumTermsLink,
          AppConfig.termsUrl.isNotEmpty ? () => _launchUrl(AppConfig.termsUrl) : null,
        ),
        dot(),
        link(
          l10n.premiumPrivacyLink,
          AppConfig.privacyUrl.isNotEmpty ? () => _launchUrl(AppConfig.privacyUrl) : null,
        ),
      ],
    );
  }
}
