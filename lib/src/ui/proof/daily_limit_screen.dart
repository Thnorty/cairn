import 'package:flutter/material.dart' show Colors, Scaffold;
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_text_styles.dart';
import '../theme/screen_background.dart';
import '../widgets/buttons.dart';
import '../widgets/cairn_stack.dart';
import '../widgets/ghost_cairn.dart';
import 'verification_chrome.dart';

/// `Cairn Daily Limit.dc.html`: shown for [CompletionRejectedDailyCapReached]
/// (the 5-successful-proofs/day cap). Not tied to any one task - the
/// illustration is the same fixed "a stone is ready, waiting to settle"
/// motif regardless of which task's "Prove it" triggered it - so this
/// screen only needs the policy's own daily cap number, sourced from
/// [ProofPolicy.dailyCap] by the caller, never hardcoded here.
class DailyLimitScreen extends StatelessWidget {
  const DailyLimitScreen({
    super.key,
    required this.dailyCap,
    required this.onGoUnlimited,
    required this.onMaybeLater,
  });

  final int dailyCap;
  final VoidCallback onGoUnlimited;
  final VoidCallback onMaybeLater;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ScreenBackground(
        washes: const [
          RadialGradient(
            center: Alignment(0, -1.16),
            radius: 1.15,
            colors: [Color(0x33968368), Color(0x00968368)],
          ),
        ],
        contourOrigin: percentPositionToAlignment(50, -6),
        contourRingColor: const Color(0x0D463C2C),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(22, 8, 22, 0),
                // Top-left, mirroring VerificationHeader's own close-button
                // placement (this run's spec): an authorized deviation from
                // Cairn Daily Limit.dc.html's own top-right close-X, for
                // cross-screen consistency (every close/dismiss control in
                // this app now sits top-left).
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: CloseCircleButton(onTap: onMaybeLater),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const _ReadyStoneIllustration(),
                      const SizedBox(height: 34),
                      Text(
                        l10n.dailyLimitTitle,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.resultTitle,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.dailyLimitBody(dailyCap),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(fontSize: 14.5, height: 1.55),
                      ),
                      const SizedBox(height: 20),
                      _ResetPill(label: l10n.resetsAtMidnight),
                    ],
                  ),
                ),
              ),
              VerificationFooter(
                children: [
                  PrimaryButton(
                    label: l10n.goUnlimitedButton,
                    onPressed: onGoUnlimited,
                    icon: const _MountainGlyph(),
                  ),
                  Center(
                    child: TextGhostButton(label: l10n.maybeLaterButton, onPressed: onMaybeLater),
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

/// The "a stone is ready" motif: a hovering solid stone above a dashed ghost
/// slot, sitting above the task-agnostic 3-stone cairn illustration.
class _ReadyStoneIllustration extends StatelessWidget {
  const _ReadyStoneIllustration();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: -4 * 3.1415926535 / 180,
          child: Container(
            width: 32,
            height: 15,
            decoration: BoxDecoration(
              gradient: AppGradients.stone(
                AppColors.stoneGradients[0].$1,
                AppColors.stoneGradients[0].$2,
              ),
              borderRadius: BorderRadius.circular(7),
              boxShadow: const [
                BoxShadow(color: Color(0x803C3223), offset: Offset(0, 8), blurRadius: 14, spreadRadius: -6),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const DashedGhostStone(width: 36, height: 15, alpha: 0x80),
        const SizedBox(height: 8),
        const CairnStack(stoneCount: 3, scale: 1.3),
      ],
    );
  }
}

class _ResetPill extends StatelessWidget {
  const _ResetPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x21786C58),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SealClockIcon(color: Color(0xFF6A6153), size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppFontFamilies.workSans,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// The little mountain-peaks glyph on the "Go unlimited" button
/// (`M4 19l6-10 4 6 3-4 3 8z`).
class _MountainGlyph extends StatelessWidget {
  const _MountainGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 17,
      height: 17,
      child: CustomPaint(painter: _MountainGlyphPainter()),
    );
  }
}

class _MountainGlyphPainter extends CustomPainter {
  const _MountainGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.buttonText
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final w = size.width / 24;
    final h = size.height / 24;
    final path = Path()
      ..moveTo(4 * w, 19 * h)
      ..lineTo(10 * w, 9 * h)
      ..lineTo(14 * w, 15 * h)
      ..lineTo(17 * w, 11 * h)
      ..lineTo(20 * w, 19 * h);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MountainGlyphPainter oldDelegate) => false;
}
