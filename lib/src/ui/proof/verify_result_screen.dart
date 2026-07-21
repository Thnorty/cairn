import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/date_number_formatting.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/buttons.dart';
import '../widgets/cairn_stack.dart';
import 'verification_chrome.dart';

/// `Cairn Verify Result.dc.html`: the outcome screen shown after
/// [CompletionRecorded] - a proof that passed verification. Every number
/// shown (the time, the reason, the cairn number/stone count) comes from the
/// repositories via the caller ([routeToProofOutcome] in
/// `proof_outcome_routing.dart`); nothing here is hardcoded or computed in
/// this widget.
class VerifyResultScreen extends StatelessWidget {
  const VerifyResultScreen({
    super.key,
    required this.taskTitle,
    required this.completedAtMillis,
    required this.imageBytes,
    required this.reason,
    required this.cairnNumber,
    required this.stoneCount,
    required this.onDone,
  });

  final String taskTitle;
  final int completedAtMillis;
  final Uint8List imageBytes;

  /// The verifier's own freeform explanation (Gemini's text), shown after
  /// the static "Looks good." lead-in. Server-generated, not ARB copy.
  final String reason;

  /// The task's *current* cairn: which of its own per-task cairns it is
  /// currently "on" (see `CairnGrouping.currentCairn`), NOT a creation-order
  /// ordinal across tasks and NOT its lifetime completion total. Re-read
  /// via `CompletionRepository.currentCairnFor` AFTER this completion was
  /// already recorded, so [stoneCount] naturally includes the new stone.
  final int cairnNumber;
  final int stoneCount;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final time = formatTimeOfDay(
      DateTime.fromMillisecondsSinceEpoch(completedAtMillis),
      locale,
    );

    return ProofOutcomeScaffold(
      washes: const [
        RadialGradient(
          center: Alignment(0, -1.16),
          radius: 1.15,
          colors: [Color(0x477A8D60), Color(0x007A8D60)],
        ),
        RadialGradient(
          center: Alignment(1, -1),
          radius: 0.9,
          colors: [Color(0x29968368), Color(0x00968368)],
        ),
      ],
      contourOrigin: percentPositionToAlignment(50, -6),
      contourRingColor: const Color(0x0D5A6E48),
      onClose: onDone,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SealCircle(
            gradientColors: [AppColors.sageLight, AppColors.sage],
            ringColor: Color(0x297A8D60),
            shadowColor: Color(0x8C5A6E3C),
            icon: SealCheckmarkIcon(),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.verifiedTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.resultTitle.copyWith(
              color: AppColors.sageHeading,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            l10n.taskNameAtTime(taskTitle, time),
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 20),
          ProofPhotoPebble(imageBytes: imageBytes, height: 186),
          const SizedBox(height: 14),
          ReasonBanner(
            backgroundColor: AppColors.sageBannerBg,
            iconColor: AppColors.sageText,
            leadText: l10n.verifyReasonPositiveLead,
            leadColor: AppColors.sageReasonBold,
            bodyText: reason,
            textColor: AppColors.sageReasonBody,
          ),
          const SizedBox(height: 22),
          CairnStack(
            stoneCount: stoneCount,
            highlightTop: true,
            scale: heroCairnScale,
          ),
          const SizedBox(height: 14),
          Text(
            l10n.taskSummaryVerifiedNewStone(cairnNumber, stoneCount),
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
      footer: [
        PrimaryButton(label: l10n.doneButton, onPressed: onDone),
      ],
    );
  }
}
