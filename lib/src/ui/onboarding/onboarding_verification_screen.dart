import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../proof/verification_chrome.dart'
    show SealCheckmarkIcon, percentPositionToAlignment;
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/card_surface.dart';
import '../widgets/coming_soon_snack_bar.dart';
import 'onboarding_header.dart';

/// `Cairn Onboarding Verification.dc.html`: step 3 of 3 (the last) in the
/// first-launch onboarding flow, reached from
/// [OnboardingHowItWorksScreen]'s "Continue" button - see
/// [OnboardingFlow]'s doc comment for how all three steps are hosted on one
/// nested `Navigator`.
class OnboardingVerificationScreen extends ConsumerStatefulWidget {
  const OnboardingVerificationScreen({
    super.key,
    required this.onBack,
    required this.onAllowCameraComplete,
  });

  /// Pops back to the welcome screen on [OnboardingFlow]'s nested Navigator.
  final VoidCallback onBack;

  /// Called after the OS camera-permission prompt resolves (allowed OR
  /// denied - see [CameraPermissionRequester]'s doc comment on why this
  /// screen never branches on the result). [OnboardingFlow] wires this to
  /// marking onboarding complete and entering the app.
  final VoidCallback onAllowCameraComplete;

  @override
  ConsumerState<OnboardingVerificationScreen> createState() =>
      _OnboardingVerificationScreenState();
}

class _OnboardingVerificationScreenState
    extends ConsumerState<OnboardingVerificationScreen> {
  bool _busy = false;

  Future<void> _handleAllowCamera() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(cameraPermissionRequesterProvider).request();
      widget.onAllowCameraComplete();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showComingSoon(String message) {
    context.showComingSoonSnackBar(message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ModalScaffold(
      washes: const [
        RadialGradient(
          center: Alignment(0, -1.12),
          radius: 1.3,
          colors: [AppColors.onboardingVerificationSageWash, Color(0x0096A678)],
        ),
      ],
      contourOrigin: percentPositionToAlignment(50, -4),
      contourRingColor: AppColors.premiumContourRing,
      child: Column(
        children: [
          OnboardingHeader(activeIndex: 2, onBack: widget.onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(30, 8, 30, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  const _VerifyEmblem(),
                  const SizedBox(height: 18),
                  Text(
                    l10n.onboardingVerificationTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.onboardingVerificationHeadline,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.onboardingVerificationSubhead,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.emptyStateBody,
                  ),
                  const SizedBox(height: 24),
                  _PointCard(
                    icon: const SealCheckmarkIcon(size: 17, color: AppColors.sageText),
                    title: l10n.onboardingPoint1Title,
                    body: l10n.onboardingPoint1Body,
                  ),
                  const SizedBox(height: 11),
                  _PointCard(
                    icon: const _PointGlyph(shape: _PointGlyphShape.lock),
                    title: l10n.onboardingPoint2Title,
                    body: l10n.onboardingPoint2Body,
                  ),
                  const SizedBox(height: 11),
                  _PointCard(
                    icon: const _PointGlyph(shape: _PointGlyphShape.cloud),
                    title: l10n.onboardingPoint3Title,
                    body: l10n.onboardingPoint3Body,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _PermissionFooter(
            l10n: l10n,
            busy: _busy,
            onAllowCamera: _handleAllowCamera,
            onLearnMore: () => _showComingSoon(l10n.onboardingPrivacyComingSoonSnackbar),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shield / verify emblem
// ---------------------------------------------------------------------------

/// The sage shield outline with a small camera badge centered inside it,
/// matching `Cairn Onboarding Verification.dc.html`'s emblem exactly: the
/// shield path is reproduced point-for-point from that file's own SVG `d`
/// attribute (`M12 2.5l7.5 3v6.2c0 4.6-3.2 7.9-7.5 9.3-4.3-1.4-7.5-4.7-7.5-
/// 9.3V5.5z`), not hand-approximated.
class _VerifyEmblem extends StatelessWidget {
  const _VerifyEmblem();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(child: CustomPaint(painter: _ShieldOutlinePainter())),
          const CameraBadgeIcon(
            strokeColor: AppColors.sageText,
            punchColor: AppColors.screenBackground,
          ),
        ],
      ),
    );
  }
}

class _ShieldOutlinePainter extends CustomPainter {
  const _ShieldOutlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 24;
    final h = size.height / 24;
    final path = Path()
      ..moveTo(12 * w, 2.5 * h)
      ..lineTo(19.5 * w, 5.5 * h)
      ..lineTo(19.5 * w, 11.7 * h)
      ..cubicTo(19.5 * w, 16.3 * h, 16.3 * w, 19.6 * h, 12 * w, 21 * h)
      ..cubicTo(7.7 * w, 19.6 * h, 4.5 * w, 16.3 * h, 4.5 * w, 11.7 * h)
      ..lineTo(4.5 * w, 5.5 * h)
      ..close();

    canvas.drawPath(path, Paint()..color = AppColors.onboardingShieldFill);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.sageText
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * w
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ShieldOutlinePainter oldDelegate) => false;
}

/// The small camera glyph reproduced as three CSS box shapes are in the
/// source files (a rounded body, a circular lens, and a top viewfinder bump
/// with no bottom border): the shield emblem's own sage camera icon, and
/// (at different literal dimensions) the footer permission-primer card's
/// terracotta icon. [punchColor] fills the seam where the bump overlaps the
/// body's top edge, matching the design's own `background:` punch-through
/// technique on that bump (see `_CameraBadgePainter`'s doc comment).
class CameraBadgeIcon extends StatelessWidget {
  const CameraBadgeIcon({
    super.key,
    required this.strokeColor,
    required this.punchColor,
    this.bodyWidth = 26,
    this.bodyHeight = 21,
    this.bodyRadius = 6.0,
    this.strokeWidth = 2.2,
    this.bumpWidth = 9.0,
    this.bumpHeight = 6.0,
    this.bumpLeft = 6.0,
    this.bumpRadius = 3.0,
    this.lensDiameter = 9.0,
  });

  final Color strokeColor;
  final Color punchColor;
  final double bodyWidth;
  final double bodyHeight;
  final double bodyRadius;
  final double strokeWidth;
  final double bumpWidth;
  final double bumpHeight;
  final double bumpLeft;
  final double bumpRadius;
  final double lensDiameter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: bodyWidth,
      height: bodyHeight + bumpHeight,
      child: CustomPaint(
        painter: _CameraBadgePainter(
          strokeColor: strokeColor,
          punchColor: punchColor,
          bodyWidth: bodyWidth,
          bodyHeight: bodyHeight,
          bodyRadius: bodyRadius,
          strokeWidth: strokeWidth,
          bumpWidth: bumpWidth,
          bumpHeight: bumpHeight,
          bumpLeft: bumpLeft,
          bumpRadius: bumpRadius,
          lensDiameter: lensDiameter,
        ),
      ),
    );
  }
}

/// Paints in three passes, mirroring the design's own CSS layering: 1) the
/// body's full rounded-rect outline (including the segment of its top edge
/// that the bump will sit over), 2) an opaque [punchColor] fill over that
/// seam (matching the design's own `background:` on the bump - it visually
/// erases the body's top edge under the bump rather than actually clipping
/// it), 3) the bump's own outline with no bottom edge (`border-bottom:none`
/// in the source), so it reads as a viewfinder opening straight into the
/// body rather than a separate shape stacked on top.
class _CameraBadgePainter extends CustomPainter {
  const _CameraBadgePainter({
    required this.strokeColor,
    required this.punchColor,
    required this.bodyWidth,
    required this.bodyHeight,
    required this.bodyRadius,
    required this.strokeWidth,
    required this.bumpWidth,
    required this.bumpHeight,
    required this.bumpLeft,
    required this.bumpRadius,
    required this.lensDiameter,
  });

  final Color strokeColor;
  final Color punchColor;
  final double bodyWidth;
  final double bodyHeight;
  final double bodyRadius;
  final double strokeWidth;
  final double bumpWidth;
  final double bumpHeight;
  final double bumpLeft;
  final double bumpRadius;
  final double lensDiameter;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final bodyRect = Rect.fromLTWH(0, bumpHeight, bodyWidth, bodyHeight);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(bodyRadius)), stroke);

    final punchRect = Rect.fromLTWH(
      bumpLeft - strokeWidth / 2,
      bumpHeight - strokeWidth,
      bumpWidth + strokeWidth,
      strokeWidth * 2,
    );
    canvas.drawRect(punchRect, Paint()..color = punchColor);

    final bump = Path()
      ..moveTo(bumpLeft, bumpHeight)
      ..lineTo(bumpLeft, bumpRadius)
      ..arcToPoint(Offset(bumpLeft + bumpRadius, 0), radius: Radius.circular(bumpRadius))
      ..lineTo(bumpLeft + bumpWidth - bumpRadius, 0)
      ..arcToPoint(Offset(bumpLeft + bumpWidth, bumpRadius), radius: Radius.circular(bumpRadius))
      ..lineTo(bumpLeft + bumpWidth, bumpHeight);
    canvas.drawPath(bump, stroke);

    canvas.drawCircle(
      Offset(bodyWidth / 2, bumpHeight + bodyHeight / 2),
      lensDiameter / 2,
      stroke,
    );
  }

  @override
  bool shouldRepaint(_CameraBadgePainter oldDelegate) =>
      strokeColor != oldDelegate.strokeColor || punchColor != oldDelegate.punchColor;
}

// ---------------------------------------------------------------------------
// Point cards
// ---------------------------------------------------------------------------

class _PointCard extends StatelessWidget {
  const _PointCard({required this.icon, required this.title, required this.body});

  final Widget icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ParchmentPill(
      radius: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
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
                Text(title, style: AppTextStyles.onboardingPointTitle),
                const SizedBox(height: 2),
                Text(body, style: AppTextStyles.onboardingPointBody),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _PointGlyphShape { lock, cloud }

/// The lock and cloud point-card icons, reproduced point-for-point from the
/// design's own SVG `d` attributes (same precision approach as
/// [_ShieldOutlinePainter]); the cloud path is byte-for-byte the same curve
/// `premium_screen.dart`'s own `_ValueGlyphShape.cloud` uses (minus that
/// one's inner download-arrow strokes, which this point card's source file
/// doesn't have), duplicated privately per this codebase's existing
/// precedent for genuinely-distinct one-off glyphs rather than shared (see
/// `premium_screen.dart`'s `_RadioCheckPainter` doc comment for another).
class _PointGlyph extends StatelessWidget {
  const _PointGlyph({required this.shape});

  final _PointGlyphShape shape;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 17, height: 17, child: CustomPaint(painter: _PointGlyphPainter(shape: shape)));
  }
}

class _PointGlyphPainter extends CustomPainter {
  const _PointGlyphPainter({required this.shape});

  final _PointGlyphShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 24;
    final h = size.height / 24;
    final paint = Paint()
      ..color = AppColors.sageText
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (shape) {
      case _PointGlyphShape.lock:
        // `<rect x="4" y="10" width="16" height="11" rx="2.5"/>` (body) +
        // `M8 10V7a4 4 0 0 1 8 0v3` (shackle).
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(4 * w, 10 * h, 16 * w, 11 * h),
            Radius.circular(2.5 * w),
          ),
          paint,
        );
        canvas.drawLine(Offset(8 * w, 10 * h), Offset(8 * w, 7 * h), paint);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(12 * w, 7 * h), radius: 4 * w),
          math.pi,
          math.pi,
          false,
          paint,
        );
        canvas.drawLine(Offset(16 * w, 7 * h), Offset(16 * w, 10 * h), paint);
        break;

      case _PointGlyphShape.cloud:
        // `M7 17a4 4 0 0 1-.5-8A5.5 5.5 0 0 1 17 9.2 3.8 3.8 0 0 1 16.5 17z`
        // - the same cloud outline curve as premium_screen.dart's own
        // `_ValueGlyphShape.cloud`, without that one's inner arrow strokes.
        canvas.drawPath(
          Path()
            ..moveTo(7 * w, 17 * h)
            ..cubicTo(3.5 * w, 16.5 * h, 3 * w, 11.5 * h, 6.5 * w, 9.5 * h)
            ..cubicTo(7 * w, 6 * h, 13 * w, 5.5 * h, 15 * w, 9 * h)
            ..cubicTo(18 * w, 9 * h, 19 * w, 12.5 * h, 16.5 * w, 15 * h)
            ..cubicTo(15.5 * w, 16.5 * h, 9 * w, 17.5 * h, 7 * w, 17 * h),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(_PointGlyphPainter oldDelegate) => shape != oldDelegate.shape;
}

// ---------------------------------------------------------------------------
// Footer: permission primer card
// ---------------------------------------------------------------------------

class _PermissionFooter extends StatelessWidget {
  const _PermissionFooter({
    required this.l10n,
    required this.busy,
    required this.onAllowCamera,
    required this.onLearnMore,
  });

  final AppLocalizations l10n;
  final bool busy;
  final Future<void> Function() onAllowCamera;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsetsDirectional.all(16),
            decoration: BoxDecoration(
              color: AppColors.accountStatusBg,
              border: Border.all(color: AppColors.accountStatusBorder),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.onboardingPermissionIconBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const CameraBadgeIcon(
                        strokeColor: AppColors.terracotta,
                        punchColor: AppColors.onboardingPermissionIconBg,
                        bodyWidth: 19,
                        bodyHeight: 15,
                        bodyRadius: 5,
                        strokeWidth: 2,
                        bumpWidth: 6,
                        bumpHeight: 4,
                        bumpLeft: 4,
                        bumpRadius: 2,
                        lensDiameter: 7,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${l10n.onboardingCameraPermissionLead} ',
                              style: AppTextStyles.onboardingPermissionLead,
                            ),
                            TextSpan(
                              text: l10n.onboardingCameraPermissionBody,
                              style: AppTextStyles.onboardingPermissionBody,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                PrimaryButton(
                  label: l10n.onboardingAllowCameraButton,
                  onPressed: busy ? null : () => unawaited(onAllowCamera()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onLearnMore,
            behavior: HitTestBehavior.opaque,
            child: Semantics(
              button: true,
              label: l10n.onboardingLearnMorePrivacyLink,
              child: Text(l10n.onboardingLearnMorePrivacyLink, style: AppTextStyles.onboardingPrivacyLinkLabel),
            ),
          ),
        ],
      ),
    );
  }
}
