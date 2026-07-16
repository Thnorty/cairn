import 'dart:typed_data';

import 'package:flutter/material.dart' show Colors, Scaffold;
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/date_number_formatting.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/screen_background.dart';
import '../widgets/buttons.dart';
import '../widgets/status_chip.dart';
import 'verification_chrome.dart';

/// `Cairn Verify Too Old.dc.html`: shown for [CompletionRejectedStalePhoto]
/// - a proof photo whose own capture timestamp fell outside
/// [ProofPolicy.recencyWindow]. This never reached the verifier and never
/// burned an attempt (the recency pre-filter runs before any verifier call
/// or `verification_attempts` write - see
/// `CompletionRepository.completeWithProof`'s own doc comment), so
/// [attemptsRemaining] here is always the task's full, un-decremented
/// remaining count: there is no "no retries" variant of this screen the way
/// [VerifyFailedScreen] has one, since staleness never counts against the
/// cap that variant exists to communicate.
///
/// Replaces the earlier stopgap of reusing [VerifyFailedScreen] for this
/// outcome now that a canonical design exists for it.
class VerifyTooOldScreen extends StatelessWidget {
  const VerifyTooOldScreen({
    super.key,
    required this.taskTitle,
    required this.photoTakenAtMillis,
    required this.ageMinutes,
    required this.imageBytes,
    required this.attemptsRemaining,
    required this.recencyWindowMinutes,
    required this.onRetake,
    required this.onCancel,
  });

  final String taskTitle;

  /// The photo's own capture timestamp (epoch millis), for the "taken
  /// HH:MM" subtitle. Computed by the caller (`proof_outcome_routing.dart`)
  /// from [CompletionRejectedStalePhoto.photoAgeMillis] and the [Clock]'s
  /// "now" at rejection time - never `DateTime.now()`, and never
  /// recomputed in this widget.
  final int photoTakenAtMillis;

  /// Whole minutes old, from [stalePhotoAgeMinutes] - computed by the
  /// caller, not this widget (CLAUDE.md: nothing computed in a widget).
  final int ageMinutes;

  final Uint8List imageBytes;

  /// The user's full remaining attempts for this task today
  /// (`attemptsPerTaskPerDay - attemptsUsedToday`), unaffected by this
  /// rejection - see this class's own doc comment.
  final int attemptsRemaining;

  /// [ProofPolicy.recencyWindow] in whole minutes, for the reassurance
  /// banner's "N minutes" figure - sourced from policy, never hardcoded.
  final int recencyWindowMinutes;

  /// Reopens the camera for another attempt.
  final VoidCallback onRetake;

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final takenAt = formatTimeOfDay(
      DateTime.fromMillisecondsSinceEpoch(photoTakenAtMillis),
      locale,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ScreenBackground(
        washes: const [
          RadialGradient(
            center: Alignment(0, -1.16),
            radius: 1.15,
            colors: [Color(0x24968368), Color(0x00968368)],
          ),
        ],
        contourOrigin: percentPositionToAlignment(50, -6),
        contourRingColor: const Color(0x0D463C2C),
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
                        gradientColors: [AppColors.pendingSealLight, AppColors.pendingSealDark],
                        ringColor: Color(0x29A0947E),
                        shadowColor: Color(0x735A503C),
                        icon: SealHistoryIcon(),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.verifyTooOldTitle,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.resultTitle.copyWith(color: AppColors.pendingHeading),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        l10n.taskNameTakenAt(taskTitle, takenAt),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 20),
                      ProofPhotoPebble(
                        imageBytes: imageBytes,
                        height: 176,
                        overlay: StatusChip(
                          variant: StatusChipVariant.awaiting,
                          onPhoto: true,
                          label: l10n.stalePhotoAgeBadge(ageMinutes),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ReasonBanner(
                        backgroundColor: const Color(0x1F786C58),
                        iconColor: const Color(0xFF8A7F6C),
                        leadText: l10n.stalePhotoReassuranceLead,
                        leadColor: const Color(0xFF463F31),
                        bodyText: l10n.stalePhotoReassuranceBody(recencyWindowMinutes),
                        textColor: const Color(0xFF544D40),
                      ),
                      const SizedBox(height: 12),
                      AttemptsInfoCard(
                        icon: const SealCheckmarkIcon(color: Color(0xFF6D7A52), size: 14),
                        iconBackground: const Color(0x2E786C58),
                        leadText: l10n.stalePhotoAttemptsIntro,
                        emphasisText: '${l10n.stalePhotoAttemptsCount(attemptsRemaining)}.',
                      ),
                    ],
                  ),
                ),
              ),
              VerificationFooter(
                children: [
                  PrimaryButton(
                    label: l10n.takeNewPhotoButton,
                    onPressed: onRetake,
                    icon: const _TakePhotoCameraIcon(),
                  ),
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

/// The plain camera glyph on the "Take a new photo" button (rounded frame,
/// lens circle, small viewfinder bump on top) - matching
/// `Cairn Verify Too Old.dc.html`'s footer icon, distinct from
/// [VerifyFailedScreen]'s own retake-camera glyph (that one has no bump).
class _TakePhotoCameraIcon extends StatelessWidget {
  const _TakePhotoCameraIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 19, height: 18, child: CustomPaint(painter: _TakePhotoCameraPainter()));
  }
}

class _TakePhotoCameraPainter extends CustomPainter {
  const _TakePhotoCameraPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.buttonText
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final bodyRect = Rect.fromLTWH(0, size.height - 16, size.width, 16);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(4)), stroke);
    canvas.drawCircle(bodyRect.center, bodyRect.height * 0.28, stroke);
    final bumpRect = Rect.fromLTWH(bodyRect.left + 4, 0, 6, 4);
    canvas.drawPath(
      Path()
        ..moveTo(bumpRect.left, bumpRect.bottom)
        ..lineTo(bumpRect.left, bumpRect.top)
        ..lineTo(bumpRect.right, bumpRect.top)
        ..lineTo(bumpRect.right, bumpRect.bottom),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_TakePhotoCameraPainter oldDelegate) => false;
}
