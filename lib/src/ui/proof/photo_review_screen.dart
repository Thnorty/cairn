import 'dart:io';

import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../widgets/buttons.dart';
import 'camera_chrome.dart';
import 'verification_chrome.dart' show SealCheckmarkIcon;

/// `Cairn Photo Review.dc.html`: the accept/retake step between a photo
/// existing (just shot by the live camera, or picked from the gallery) and
/// it ever being submitted through `ProofFlowService.submitCapturedProof`.
/// Fills the seam both `camera_capture_screen.dart` and
/// `camera_unavailable_screen.dart` used to leave open for this step (their
/// own doc comments used to call it "not built yet").
///
/// One widget serves both the camera and gallery paths; [secondaryLabel] is
/// the sole visible difference between them (the design's own "Retake" for
/// a just-shot photo vs. "Choose another" for a gallery pick - see the
/// `chooseAnotherPhotoButton` ARB entry's own doc comment). The caller (not
/// this widget) decides which label and which callback to wire up, since
/// only the caller knows whether discarding means "return to the still-live
/// camera" (camera path) or "reopen the gallery picker" (gallery path).
///
/// Dark, full-bleed chrome matching the live camera screen's own distinct
/// dark styling (see that screen's doc comment for why this whole flow
/// departs from the shared warm-parchment `ScreenBackground`) - reuses its
/// top bar, task pill, and refresh-cycle glyph verbatim via
/// `camera_chrome.dart` rather than duplicating them.
///
/// [onUsePhoto]/[onSecondaryAction] are nullable so a caller can disable
/// both actions (dimmed, inert) while a previous tap's async work - a
/// gallery re-pick, or the submit round trip - is still in flight, the same
/// busy-guard convention every other screen in this flow already follows.
/// [onClose] stays a plain, always-active [VoidCallback]: backing out is
/// never blocked on in-flight work, matching the live camera screen's own
/// close button.
class PhotoReviewScreen extends StatelessWidget {
  const PhotoReviewScreen({
    super.key,
    required this.imagePath,
    required this.taskTitle,
    required this.secondaryLabel,
    required this.onUsePhoto,
    required this.onSecondaryAction,
    required this.onClose,
  });

  final String imagePath;
  final String taskTitle;
  final String secondaryLabel;
  final VoidCallback? onUsePhoto;
  final VoidCallback? onSecondaryAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.cameraChromeBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _StillPhoto(path: imagePath),
          const _TopScrim(),
          const _BottomScrim(),
          SafeArea(
            child: Column(
              children: [
                CameraTopBar(onClose: onClose),
                const SizedBox(height: 12),
                CameraTaskPill(label: l10n.provingLabel, taskTitle: taskTitle),
                const Spacer(),
                _ReviewPrompt(text: l10n.photoReviewPrompt),
                const SizedBox(height: 18),
                _BottomActions(
                  useLabel: l10n.usePhotoButton,
                  secondaryLabel: secondaryLabel,
                  onUsePhoto: onUsePhoto,
                  onSecondaryAction: onSecondaryAction,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The captured/picked photo, full-bleed and still (no live preview once
/// this screen is showing). A real file path, read via [Image.file] per
/// this run's spec, so a device user always sees their *actual* proof
/// photo here, not a placeholder - [errorBuilder] only degrades to a plain
/// dark fill on a genuinely unreadable path (e.g. a fake path in a widget
/// test that never wrote a real file), never on a real device, where the
/// path always names a file this app just wrote itself.
class _StillPhoto extends StatelessWidget {
  const _StillPhoto({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const DecoratedBox(decoration: BoxDecoration(color: AppColors.cameraChromeBackground)),
    );
  }
}

/// Top gradient scrim (`rgba(20,18,14,.55) -> transparent`, 210px tall) so
/// the close button and task pill stay legible over an arbitrary photo.
class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 210,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x8C14120E), AppColors.photoScrimEnd],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom gradient scrim (`rgba(20,18,14,.72) -> transparent`, 280px tall)
/// so the review prompt and footer actions stay legible over an arbitrary
/// photo.
class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 280,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xB814120E), AppColors.photoScrimEnd],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Does this show your proof clearly?" pill with a small magnifying
/// glass glyph, sitting above the footer actions.
class _ReviewPrompt extends StatelessWidget {
  const _ReviewPrompt({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.cameraGlassBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x14FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 15, height: 15, child: CustomPaint(painter: _SearchGlyphPainter())),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                fontFamily: 'Work Sans',
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Color(0xFFE9E3D3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal magnifying-glass glyph (circle + diagonal handle), matching the
/// review prompt's SVG (`<circle cx="11" cy="11" r="7.5"/><path d="M16.5 16.5L21 21">`).
class _SearchGlyphPainter extends CustomPainter {
  const _SearchGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.heroLabelSage
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;
    canvas.drawCircle(Offset(11 * w, 11 * h), 7.5 * w, stroke);
    canvas.drawLine(Offset(16.5 * w, 16.5 * h), Offset(21 * w, 21 * h), stroke);
  }

  @override
  bool shouldRepaint(_SearchGlyphPainter oldDelegate) => false;
}

/// The footer's two stacked actions: the terracotta "Use this photo"
/// primary button, then the glass "Retake"/"Choose another" secondary
/// button.
class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.useLabel,
    required this.secondaryLabel,
    required this.onUsePhoto,
    required this.onSecondaryAction,
  });

  final String useLabel;
  final String secondaryLabel;
  final VoidCallback? onUsePhoto;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(26, 0, 26, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            key: const ValueKey('photo-review-use'),
            label: useLabel,
            onPressed: onUsePhoto,
            icon: const SealCheckmarkIcon(color: AppColors.buttonText, size: 19),
          ),
          const SizedBox(height: 10),
          _GlassButton(
            key: const ValueKey('photo-review-secondary'),
            label: secondaryLabel,
            onPressed: onSecondaryAction,
          ),
        ],
      ),
    );
  }
}

/// The dark "glass" secondary button (`rgba(40,36,28,.5)` fill, blurred,
/// `rgba(255,255,255,.16)` border): the design's own treatment for
/// "Retake"/"Choose another", distinct from every warm-parchment button in
/// `widgets/buttons.dart` (none of which is dark-chrome), so this stays
/// private to this screen rather than added to that shared family for one
/// caller.
class _GlassButton extends StatelessWidget {
  const _GlassButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsetsDirectional.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0x8028241C),
            borderRadius: BorderRadius.circular(AppRadii.buttonMedium),
            border: Border.all(color: AppColors.cameraGlassBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const RefreshCycleGlyph(color: AppColors.chipInactiveLight, size: 18),
              const SizedBox(width: 9),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Work Sans',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppColors.chipInactiveLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
