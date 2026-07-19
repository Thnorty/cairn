import 'package:flutter/material.dart' show Colors, Material, MaterialType, Scaffold;
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/date_number_formatting.dart';
import '../../services/points_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import '../theme/screen_background.dart';
import '../widgets/buttons.dart';
import '../widgets/cairn_stack.dart';
import 'verification_chrome.dart';

/// `Cairn Verify Result - Cairn Complete.dc.html`: the celebration screen
/// pushed on top of [VerifyResultScreen] (never in its place) when the
/// stone that screen just showed happened to be the 10th live stone in the
/// task's current per-task cairn - see `proof_outcome_routing.dart`'s
/// `CompletionRecorded` case for the `cairn.stoneCount ==
/// PointsService.cairnCapStones` check that decides whether this screen
/// ever appears. Deliberately never shown for [CompletionPendingVerification]
/// (an offline/pending cap): CLAUDE.md's pending-completion rule withholds
/// every bonus, the cairn-cap bonus included, until the proof actually
/// verifies, so celebrating a bonus that hasn't landed yet would be a lie.
///
/// Every number here (the cairn's own index, the next cairn's index, the
/// bonus amount, the completion time) is supplied by the caller, never
/// hardcoded or recomputed in this widget - [capBonusMetres] in particular
/// must always be [PointsService.cairnCapBonus] from the caller, not a
/// literal `25` here, so the on-screen figure and the actual awarded bonus
/// can never drift apart. Unlike [VerifyResultScreen] this screen does not
/// show the proof photo again (the photo already had its moment on the
/// screen underneath this one); it shows the *cairn*, not the evidence.
class CairnCompleteScreen extends StatelessWidget {
  const CairnCompleteScreen({
    super.key,
    required this.taskTitle,
    required this.cairnNumber,
    required this.nextCairnNumber,
    required this.capBonusMetres,
    required this.completedAtMillis,
    required this.onDone,
  });

  final String taskTitle;

  /// The just-capped cairn's own index (`CompletionRepository
  /// .currentCairnFor`'s `index`, re-read after the capping stone was
  /// recorded - see this screen's own doc comment).
  final int cairnNumber;

  /// [cairnNumber] + 1: the cairn the task's next stone starts. Passed in
  /// rather than derived here so the caller stays the single source of
  /// truth for every number this screen shows.
  final int nextCairnNumber;

  /// The metres this specific stone earned on top of base/streak/perfect-
  /// day for capping the cairn - always [PointsService.cairnCapBonus] from
  /// the caller.
  final int capBonusMetres;

  final int completedAtMillis;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final time = formatTimeOfDay(
      DateTime.fromMillisecondsSinceEpoch(completedAtMillis),
      locale,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ScreenBackground(
        // Same sage-forward wash position/contour tint as
        // `Cairn Verify Result.dc.html` (this screen's own source CSS uses
        // an identical `50% -8%` top-wash position and `50% -6%` /
        // rgba(90,110,72,.05) contour ring tint), just a stronger top-wash
        // alpha (.34 vs VerifyResultScreen's .28) matching this screen's
        // own more saturated celebration wash.
        washes: const [
          RadialGradient(
            center: Alignment(0, -1.16),
            radius: 1.2,
            colors: [Color(0x5796A678), Color(0x0096A678)],
          ),
          RadialGradient(
            center: Alignment(1, -1),
            radius: 0.9,
            colors: [Color(0x29968368), Color(0x00968368)],
          ),
        ],
        contourOrigin: percentPositionToAlignment(50, -6),
        contourRingColor: const Color(0x0D5A6E48),
        child: SafeArea(
          child: Column(
            children: [
              VerificationHeader(
                onClose: onDone,
                label: l10n.cairnCompleteHeaderLabel,
                labelColor: AppColors.sageText,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _CompactVerifiedRow(taskTitle: taskTitle, time: time),
                      const SizedBox(height: 26),
                      const _CompletedCairnHero(),
                      const SizedBox(height: 20),
                      Text(
                        l10n.cairnCompleteHeadline(cairnNumber),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.cairnCompleteHeadline,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.cairnCompleteSubline,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 20),
                      _CairnBonusPill(
                        label: l10n.cairnCompleteBonusAmount(
                          formatMetresNumber(capBonusMetres, locale),
                        ),
                        trailing: l10n.cairnCompleteBonusLabel,
                      ),
                      const SizedBox(height: 22),
                      ReasonBanner(
                        backgroundColor: AppColors.sageBannerBg,
                        iconColor: AppColors.sageText,
                        textColor: AppColors.sageReasonBody,
                        spans: [
                          TextSpan(text: '${l10n.cairnCompleteTeachingLead} '),
                          TextSpan(
                            text: l10n.cairnCompleteTeachingNext(nextCairnNumber),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.sageReasonBold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              VerificationFooter(
                children: [
                  PrimaryButton(label: l10n.doneButton, onPressed: onDone),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The compact "Verified · task · time" confirmation row at the top of the
/// body: a small sage checkmark badge (a scaled-down [SealCircle], not the
/// full-size one [VerifyResultScreen] uses up top - this screen's own hero
/// is the cairn below, not this badge) plus one line of text with a bold
/// "Verified" lead, matching `Cairn Verify Result - Cairn Complete.dc.html`'s
/// `<strong>Verified</strong> · Read 20 pages · 7:16 AM` row.
class _CompactVerifiedRow extends StatelessWidget {
  const _CompactVerifiedRow({required this.taskTitle, required this.time});

  final String taskTitle;
  final String time;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment(-0.64, -1),
              end: Alignment(0.64, 1),
              colors: [AppColors.sageLight, AppColors.sage],
            ),
            boxShadow: [
              BoxShadow(color: AppColors.sageChipBg, spreadRadius: 5),
            ],
          ),
          alignment: Alignment.center,
          child: const SealCheckmarkIcon(size: 14),
        ),
        const SizedBox(width: 9),
        Material(
          type: MaterialType.transparency,
          child: Text.rich(
            TextSpan(
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              children: [
                TextSpan(
                  text: '${l10n.verifiedTitle} · ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.sageHeading,
                  ),
                ),
                TextSpan(text: l10n.taskNameAtTime(taskTitle, time)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The completed-cairn hero: a full [PointsService.cairnCapStones]-stone
/// stack with its sage-highlighted capping stone, sitting inside a soft
/// sage "completion glow" halo - `Cairn Verify Result - Cairn
/// Complete.dc.html`'s own `<!-- completed cairn hero -->` block. The stone
/// count is always the cap threshold itself (this screen only ever shows a
/// cairn that just capped), not a caller-supplied number.
class _CompletedCairnHero extends StatelessWidget {
  const _CompletedCairnHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x387A8D60), Color(0x007A8D60)],
                stops: [0, 0.68],
              ),
            ),
          ),
          CairnStack(
            stoneCount: PointsService.cairnCapStones,
            highlightTop: true,
            scale: heroCairnScale,
            // The 10-stone hero is a tall, narrow tower; widen its ground
            // shadow a touch beyond the bottom stone so it reads as a
            // grounded stone shadow.
            groundShadowWidthFactor: 1.4,
          ),
        ],
      ),
    );
  }
}

/// The terracotta "+N m cairn bonus" pill.
class _CairnBonusPill extends StatelessWidget {
  const _CairnBonusPill({required this.label, required this.trailing});

  /// The bold "+N m" figure, already composed via
  /// [AppLocalizations.cairnCompleteBonusAmount].
  final String label;

  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 18, 11),
      decoration: BoxDecoration(
        gradient: AppGradients.terracottaButton,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.buttonLarge,
        border: Border.all(color: AppColors.buttonInsetHighlight, width: 0.5),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BonusMountainGlyph(),
            const SizedBox(width: 9),
            Text(label, style: AppTextStyles.buttonLabelLarge),
            const SizedBox(width: 6),
            Text(
              trailing,
              style: const TextStyle(
                fontFamily: AppFontFamilies.workSans,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Color(0xE6F6EFE6), // rgba(246,239,230,.9) - buttonText @ 90% alpha
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bonus pill's small mountain glyph (`M3 19l5.5-9 3.5 5 2-3 6.5 7z`) -
/// the same path Profile's rank-hero badge and the Trail rank pill draw,
/// duplicated privately here rather than shared, matching this codebase's
/// existing precedent for small one-off glyph painters (see
/// `trail_screen.dart`'s `_MountainGlyphPainter` doc comment).
class _BonusMountainGlyph extends StatelessWidget {
  const _BonusMountainGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _BonusMountainGlyphPainter()),
    );
  }
}

class _BonusMountainGlyphPainter extends CustomPainter {
  const _BonusMountainGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final paint = Paint()
      ..color = AppColors.buttonText
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(p(3, 19).dx, p(3, 19).dy)
      ..lineTo(p(8.5, 10).dx, p(8.5, 10).dy)
      ..lineTo(p(12, 15).dx, p(12, 15).dy)
      ..lineTo(p(14, 12).dx, p(14, 12).dy)
      ..lineTo(p(20.5, 19).dx, p(20.5, 19).dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BonusMountainGlyphPainter oldDelegate) => false;
}
