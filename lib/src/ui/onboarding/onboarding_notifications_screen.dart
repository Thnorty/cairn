import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../proof/verification_chrome.dart' show percentPositionToAlignment;
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import 'onboarding_background.dart';
import 'onboarding_header.dart';
import 'onboarding_point_card.dart';

/// `Cairn Onboarding Notifications.dc.html`: step 5 of 5 (the last) in the
/// first-launch onboarding flow, reached once the camera ask on step 4 has
/// resolved - see [OnboardingFlow]'s doc comment for how all five steps are
/// hosted on one nested `Navigator`.
///
/// SKIPPABLE, unlike "Your name", and the design's header comment is
/// explicit about why: the user can decline in the system dialog no matter
/// what this screen does, so a required-looking screen would be dishonest.
/// "Not now" is a real, equally-sized choice, and declining is not a dead
/// end - Profile > Settings > Notifications turns reminders on later.
///
/// BOTH footer buttons complete onboarding. They differ only in what they
/// leave behind: "Allow notifications" fires the OS prompt and switches
/// reminders on iff it was granted, while "Not now" writes nothing and
/// leaves them at their default (off). Reminders are never switched on
/// without the permission to deliver them, so the app cannot end onboarding
/// in the silently-broken state of believing it will remind you when it
/// cannot.
class OnboardingNotificationsScreen extends ConsumerStatefulWidget {
  const OnboardingNotificationsScreen({
    super.key,
    required this.onBack,
    required this.onComplete,
  });

  /// Pops back to the Verify step on [OnboardingFlow]'s nested Navigator.
  final VoidCallback onBack;

  /// Called once this step is done, by either footer button.
  /// [OnboardingFlow] wires this to marking onboarding complete and entering
  /// the app.
  final VoidCallback onComplete;

  @override
  ConsumerState<OnboardingNotificationsScreen> createState() =>
      _OnboardingNotificationsScreenState();
}

class _OnboardingNotificationsScreenState
    extends ConsumerState<OnboardingNotificationsScreen> {
  bool _busy = false;

  Future<void> _handleAllow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final granted =
          await ref.read(notificationPermissionRequesterProvider).request();
      if (granted) {
        await ref.read(settingsRepositoryProvider).setRemindersEnabled(true);
        ref.invalidate(remindersEnabledProvider);
        ref.invalidate(notificationPermissionGrantedProvider);
        // Plans and schedules straight away rather than waiting for the next
        // foreground: a user who just granted permission and then creates
        // their first habit should get that habit's reminder, and the
        // trigger's own database subscription will cover it from there.
        unawaited(ref.read(notificationTriggerProvider).runOnce());
      }
      widget.onComplete();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ModalScaffold(
      washes: kOnboardingWashes,
      contourOrigin: percentPositionToAlignment(50, -4),
      contourRingColor: AppColors.premiumContourRing,
      child: Column(
        children: [
          OnboardingHeader(activeIndex: 4, onBack: widget.onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(30, 8, 30, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  const _BellEmblem(),
                  const SizedBox(height: 18),
                  Text(
                    l10n.onboardingNotificationsTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.onboardingVerificationHeadline,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.onboardingNotificationsSubhead,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.emptyStateBody,
                  ),
                  const SizedBox(height: 24),
                  OnboardingPointCard(
                    icon: const NotificationPointGlyph(
                      shape: NotificationGlyphShape.clock,
                      color: AppColors.sageText,
                    ),
                    title: l10n.onboardingNotificationsPoint1Title,
                    body: l10n.onboardingNotificationsPoint1Body,
                  ),
                  const SizedBox(height: 11),
                  OnboardingPointCard(
                    iconBackground: AppColors.onboardingClayPointIconBg,
                    icon: const NotificationPointGlyph(
                      shape: NotificationGlyphShape.warningTriangle,
                      color: AppColors.terracotta,
                    ),
                    title: l10n.onboardingNotificationsPoint2Title,
                    body: l10n.onboardingNotificationsPoint2Body,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _Footer(
            l10n: l10n,
            busy: _busy,
            onAllow: _handleAllow,
            onNotNow: widget.onComplete,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bell emblem
// ---------------------------------------------------------------------------

/// The sage bell in a tinted circle, mirroring the verification step's own
/// shield emblem at the same 78px size (the design says so in as many
/// words).
class _BellEmblem extends StatelessWidget {
  const _BellEmblem();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      decoration: const BoxDecoration(
        color: AppColors.onboardingBellEmblemBg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 38,
        height: 38,
        child: CustomPaint(
          painter: _BellPainter(color: AppColors.sageText, strokeWidth: 1.9),
        ),
      ),
    );
  }
}

/// The bell outline plus its clapper arc, reproduced point-for-point from
/// the design's own SVG `d` attributes
/// (`M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9` and
/// `M10.5 21a1.8 1.8 0 0 0 3 0`), the same precision approach the
/// verification screen's `_ShieldOutlinePainter` uses.
///
/// [struck] draws the "blocked" variant instead - the same bell with a slash
/// through it (`M4 4l16 16`), which is what the Notifications settings
/// screen's "Android is blocking these" notice uses.
class _BellPainter extends CustomPainter {
  const _BellPainter({
    required this.color,
    required this.strokeWidth,
    this.struck = false,
  });

  final Color color;
  final double strokeWidth;
  final bool struck;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 24;
    final h = size.height / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final bell = Path()
      ..moveTo(18 * w, 8 * h)
      ..cubicTo(18 * w, 4.7 * h, 15.3 * w, 2 * h, 12 * w, 2 * h)
      ..cubicTo(8.7 * w, 2 * h, 6 * w, 4.7 * h, 6 * w, 8 * h)
      ..cubicTo(6 * w, 15 * h, 3 * w, 17 * h, 3 * w, 17 * h)
      ..lineTo(21 * w, 17 * h)
      ..cubicTo(21 * w, 17 * h, 18 * w, 15 * h, 18 * w, 8 * h);
    canvas.drawPath(bell, paint);

    if (struck) {
      canvas.drawLine(Offset(4 * w, 4 * h), Offset(20 * w, 20 * h), paint);
      return;
    }

    // The clapper: `M10.5 21a1.8 1.8 0 0 0 3 0`, a shallow arc under the
    // bell's mouth. Omitted on the struck variant, exactly as the design's
    // own blocked-notice icon omits it.
    final clapper = Path()
      ..moveTo(10.5 * w, 21 * h)
      ..cubicTo(10.5 * w, 22 * h, 13.5 * w, 22 * h, 13.5 * w, 21 * h);
    canvas.drawPath(clapper, paint);
  }

  @override
  bool shouldRepaint(_BellPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      struck != oldDelegate.struck;
}

/// The struck-bell glyph, exported so the Notifications settings screen's
/// blocked notice can draw the identical icon rather than a second copy of
/// this path.
class StruckBellIcon extends StatelessWidget {
  const StruckBellIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BellPainter(color: color, strokeWidth: 2, struck: true),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Point-card glyphs
// ---------------------------------------------------------------------------

/// Which of the reminders step's two point-card icons to draw.
enum NotificationGlyphShape {
  /// A circle with hour/minute hands: "when a habit is due".
  clock,

  /// A triangle with an exclamation: "before a streak breaks".
  warningTriangle,
}

/// The two 17px point-card glyphs on the reminders onboarding step,
/// reproduced from the design's own SVG paths. Public (unlike the
/// verification screen's equivalent private `_PointGlyph`) because the
/// Notifications settings screen has no glyphs of its own and the clock here
/// is the same drawing.
class NotificationPointGlyph extends StatelessWidget {
  const NotificationPointGlyph({
    super.key,
    required this.shape,
    required this.color,
    this.size = 17,
  });

  final NotificationGlyphShape shape;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _NotificationGlyphPainter(shape: shape, color: color),
      ),
    );
  }
}

class _NotificationGlyphPainter extends CustomPainter {
  const _NotificationGlyphPainter({required this.shape, required this.color});

  final NotificationGlyphShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 24;
    final h = size.height / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (shape) {
      case NotificationGlyphShape.clock:
        // `<circle cx="12" cy="12" r="8.5"/>` + `M12 7.5v5l3.2 2`.
        canvas.drawCircle(Offset(12 * w, 12 * h), 8.5 * w, paint);
        canvas.drawPath(
          Path()
            ..moveTo(12 * w, 7.5 * h)
            ..lineTo(12 * w, 12.5 * h)
            ..lineTo(15.2 * w, 14.5 * h),
          paint,
        );
        break;

      case NotificationGlyphShape.warningTriangle:
        // `M12 3.5l8.5 15h-17z` + `M12 9.5v4` + a filled dot at (12, 16.4).
        canvas.drawPath(
          Path()
            ..moveTo(12 * w, 3.5 * h)
            ..lineTo(20.5 * w, 18.5 * h)
            ..lineTo(3.5 * w, 18.5 * h)
            ..close(),
          paint,
        );
        canvas.drawLine(Offset(12 * w, 9.5 * h), Offset(12 * w, 13.5 * h), paint);
        canvas.drawCircle(
          Offset(12 * w, 16.4 * h),
          0.9 * w,
          Paint()..color = color,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(_NotificationGlyphPainter oldDelegate) =>
      shape != oldDelegate.shape || color != oldDelegate.color;
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------

/// "Allow notifications" over a real, equally-tappable "Not now" - see this
/// screen's own doc comment on why the skip is not a greyed-out afterthought.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.l10n,
    required this.busy,
    required this.onAllow,
    required this.onNotNow,
  });

  final AppLocalizations l10n;
  final bool busy;
  final Future<void> Function() onAllow;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(30, 16, 30, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: l10n.onboardingAllowNotificationsButton,
            onPressed: busy ? null : () => unawaited(onAllow()),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            key: const ValueKey('onboarding-notifications-not-now'),
            onTap: busy ? null : onNotNow,
            behavior: HitTestBehavior.opaque,
            child: Semantics(
              button: true,
              label: l10n.onboardingNotNowButton,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsetsDirectional.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Text(
                  l10n.onboardingNotNowButton,
                  style: AppTextStyles.onboardingNotNowLabel,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
