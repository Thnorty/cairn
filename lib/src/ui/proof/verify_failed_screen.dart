import 'dart:typed_data';

import 'package:flutter/material.dart' show Colors, Scaffold;
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/date_number_formatting.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../theme/screen_background.dart';
import '../widgets/buttons.dart';
import '../widgets/cairn_stack.dart';
import '../widgets/ghost_cairn.dart';
import '../widgets/status_chip.dart';
import 'verification_chrome.dart';

/// `Cairn Verify Failed.dc.html` / `Cairn Verify Failed - No Retries.dc.html`:
/// one widget covering both design files (they share every part of the
/// layout except the reason banner's copy and the footer action). A verdict
/// rejection is the only outcome this screen handles now:
/// [CompletionRejectedStalePhoto] used to reuse this layout as a stopgap
/// (no canonical design existed for it yet) but now has its own screen,
/// [VerifyTooOldScreen] - see `proof_outcome_routing.dart`'s routing.
///
/// [attemptsRemaining] is the sole discriminator between the two design
/// files: `> 0` renders the "retries remain" footer (Retake photo / tries
/// left / Cancel) with [reason] shown verbatim (the verifier's own freeform
/// text); `<= 0` renders the "No Retries" footer (disabled "Try again
/// tomorrow" / resets-at-midnight / Cancel) with the design's own static
/// copy, ignoring [reason] entirely - see this project's ARB comment on
/// `allAttemptsUsedDetail` for why that copy stays static rather than
/// interpolating a dynamic reason.
class VerifyFailedScreen extends StatelessWidget {
  const VerifyFailedScreen({
    super.key,
    required this.taskTitle,
    required this.atMillis,
    this.imageBytes,
    required this.cairnNumber,
    required this.stoneCount,
    required this.attemptsRemaining,
    this.reason,
    this.onRetake,
    required this.onCancel,
  });

  final String taskTitle;
  final int atMillis;

  /// The just-captured/picked photo bytes, or null when this screen was
  /// reached directly from Home's precheck (attempts already exhausted
  /// before any photo was taken this time - see `proof_outcome_routing.dart`).
  final Uint8List? imageBytes;

  final int cairnNumber;
  final int stoneCount;

  /// Attempts left for this task today, as returned by the repository.
  /// `<= 0` switches this screen into its "No Retries" variant.
  final int attemptsRemaining;

  /// The verifier's own freeform text, or the stale-photo client message.
  /// Only shown (and only meaningful) when [attemptsRemaining] > 0.
  final String? reason;

  /// Reopens the camera for another attempt. Required when
  /// [attemptsRemaining] > 0, ignored otherwise.
  final VoidCallback? onRetake;

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final time = formatTimeOfDay(
      DateTime.fromMillisecondsSinceEpoch(atMillis),
      locale,
    );
    final noRetries = attemptsRemaining <= 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ScreenBackground(
        washes: const [
          RadialGradient(
            center: Alignment(0, -1.16),
            radius: 1.15,
            colors: [Color(0x38B27C5C), Color(0x00B27C5C)],
          ),
          RadialGradient(
            center: Alignment(1, -1),
            radius: 0.9,
            colors: [Color(0x29968368), Color(0x00968368)],
          ),
        ],
        contourOrigin: percentPositionToAlignment(50, -6),
        contourRingColor: const Color(0x0D78503A),
        child: SafeArea(
          child: Column(
            children: [
              VerificationHeader(onClose: onCancel),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SealCircle(
                        gradientColors: [AppColors.clayLight, AppColors.clay],
                        ringColor: AppColors.clayTintBg,
                        shadowColor: Color(0x73965A3C),
                        icon: SealExclamationIcon(),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.couldntVerifyTitle,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.resultTitle.copyWith(
                          color: AppColors.clayHeading,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        l10n.taskNameAtTime(taskTitle, time),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 20),
                      ProofPhotoPebble(
                        imageBytes: imageBytes,
                        height: 180,
                        overlay: StatusChip(
                          variant: StatusChipVariant.notVerified,
                          label: l10n.notVerifiedChip,
                        ),
                      ),
                      const SizedBox(height: 14),
                      noRetries
                          ? ReasonBanner(
                              backgroundColor: AppColors.clayTintBg,
                              iconColor: AppColors.clayIcon,
                              leadText: l10n.allAttemptsUsedLead(3),
                              leadColor: AppColors.clayHeading,
                              bodyText: l10n.allAttemptsUsedDetail,
                              textColor: AppColors.clayText,
                            )
                          : ReasonBanner(
                              backgroundColor: AppColors.clayTintBg,
                              iconColor: AppColors.clayIcon,
                              bodyText: reason ?? '',
                              textColor: AppColors.clayText,
                            ),
                      const SizedBox(height: 22),
                      _CairnNoStonePlaced(stoneCount: stoneCount),
                      const SizedBox(height: 14),
                      Text(
                        l10n.taskSummaryNoStonePlaced(cairnNumber, stoneCount),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ),
              VerificationFooter(
                children: [
                  if (noRetries) ...[
                    _DisabledActionButton(
                      label: l10n.tryAgainTomorrowButton,
                      icon: const SealClockIcon(color: AppColors.labelGrey, size: 18),
                    ),
                    Center(
                      child: Text(
                        l10n.attemptsResetMidnight,
                        style: const TextStyle(
                          fontFamily: AppFontFamilies.workSans,
                          fontSize: 12.5,
                          color: AppColors.labelGrey,
                        ),
                      ),
                    ),
                  ] else ...[
                    // Elevated from a small muted footer caption to the same
                    // clear card treatment `VerifyTooOldScreen` uses for its
                    // own remaining-attempts figure - the plain caption was
                    // too easy to miss (see this run's spec); the wording
                    // itself is unchanged, still sourced from
                    // AppLocalizations.triesLeftToday with the real
                    // [attemptsRemaining] from the repository.
                    //
                    // No explicit SizedBox between these two: `VerificationFooter`
                    // already inserts its own 10px gap between every child in
                    // this list (see its own build()) - an earlier run added
                    // one here anyway, which (stacked with the two automatic
                    // gaps on either side of it) pushed this footer 20px
                    // taller than every sibling screen's, which was the root
                    // cause of the cairn/meta-line/attempts-card overlap this
                    // run's spec reported. Do not re-add it.
                    AttemptsInfoCard(
                      icon: const SealCheckmarkIcon(color: Color(0xFF6D7A52), size: 14),
                      iconBackground: const Color(0x2E786C58),
                      emphasisText: l10n.triesLeftToday(attemptsRemaining),
                    ),
                    PrimaryButton(
                      label: l10n.retakePhotoButton,
                      onPressed: onRetake,
                      icon: const _RetakeCameraIcon(),
                    ),
                  ],
                  Center(
                    child: TextGhostButton(label: l10n.cancelButton, onPressed: onCancel),
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

/// The cairn illustration for a rejected proof: a dashed "ghost" outline
/// where the new stone would have gone, sitting above the task's real,
/// unchanged stack - `Cairn Verify Failed.dc.html`'s "unchanged, ghost slot
/// on top" cairn.
class _CairnNoStonePlaced extends StatelessWidget {
  const _CairnNoStonePlaced({required this.stoneCount});

  final int stoneCount;

  @override
  Widget build(BuildContext context) {
    if (stoneCount <= 0) {
      // No design covers a task's very first-ever attempt being rejected
      // (every static mockup already has an existing stack); falls back to
      // the same dashed illustration Home uses for a zero-stone task rather
      // than inventing a new one.
      return const GhostCairnStack(scale: 1.1);
    }
    final topWidth = CairnStack.topWidthFor(stoneCount) * heroCairnScale;
    final topHeight = CairnStack.topHeightFor(stoneCount) * heroCairnScale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DashedGhostStone(
          width: topWidth,
          height: topHeight,
          rotationDeg: -3,
          alpha: 0x66,
        ),
        const SizedBox(height: 8),
        CairnStack(stoneCount: stoneCount, scale: heroCairnScale),
      ],
    );
  }
}

/// The flat, inert "Try again tomorrow" button once retries are exhausted
/// for the day - deliberately *not* [PrimaryButton] (which would just dim
/// the terracotta gradient): the design switches to a distinct muted-grey
/// fill entirely, matching `rgba(120,108,88,.18)` / `#9c917e` text.
class _DisabledActionButton extends StatelessWidget {
  const _DisabledActionButton({required this.label, required this.icon});

  final String label;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(vertical: 17),
      decoration: BoxDecoration(
        color: const Color(0x2E786C58),
        borderRadius: BorderRadius.circular(AppRadii.buttonLarge),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppFontFamilies.workSans,
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.labelGrey,
            ),
          ),
        ],
      ),
    );
  }
}

/// The small "retake" glyph on the Retake photo button: a rounded frame
/// around a lens circle, matching the design's nested-span icon.
class _RetakeCameraIcon extends StatelessWidget {
  const _RetakeCameraIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 16,
      child: CustomPaint(painter: _RetakeCameraPainter()),
    );
  }
}

class _RetakeCameraPainter extends CustomPainter {
  const _RetakeCameraPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.buttonText
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(4),
      ),
      stroke,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.height * 0.28,
      stroke,
    );
  }

  @override
  bool shouldRepaint(_RetakeCameraPainter oldDelegate) => false;
}
