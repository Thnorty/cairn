/// Shared dark-chrome pieces reused by both `CameraCaptureScreen` (the live
/// viewfinder, `Cairn Camera Capture.dc.html`) and `PhotoReviewScreen` (the
/// accept/retake step right after it, `Cairn Photo Review.dc.html`): the
/// top-left close (X) button and the `"PROVING / <task>"` pill are drawn
/// identically in both canonical designs, and the refresh-cycle glyph is the
/// exact same SVG path in both the flip-camera control and the photo-review
/// "Retake"/"Choose another" button. Factored out here (rather than
/// duplicated) once a second screen needed them.
library;

import 'package:flutter/material.dart' show MaterialLocalizations;
import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../widgets/status_chip.dart' show CloseGlyph;

/// The top bar shared by the live camera screen and the photo review
/// screen: a single top-left circular X (back out), no header label (unlike
/// [VerificationHeader][../proof/verification_chrome.dart], which centers a
/// "VERIFICATION"-style label - these two dark-chrome screens don't).
class CameraTopBar extends StatelessWidget {
  const CameraTopBar({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final closeLabel = MaterialLocalizations.of(context).closeButtonLabel;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Semantics(
            button: true,
            label: closeLabel,
            child: GestureDetector(
              key: const ValueKey('camera-close'),
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: AppColors.cameraGlassBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const CloseGlyph(color: AppColors.chipInactiveLight, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// The centered `"PROVING / <task name>"` pill shown on both the live
/// camera screen and the photo review screen, identical in both canonical
/// designs.
class CameraTaskPill extends StatelessWidget {
  const CameraTaskPill({super.key, required this.label, required this.taskTitle});

  final String label;
  final String taskTitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x6B141210),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Work Sans',
                fontWeight: FontWeight.w600,
                fontSize: 10.5,
                letterSpacing: 2,
                color: AppColors.heroLabelSage,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              taskTitle,
              style: const TextStyle(
                fontFamily: 'Zilla Slab',
                fontWeight: FontWeight.w600,
                fontSize: 19,
                color: AppColors.sageChipText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two-arc "refresh/cycle" glyph: the live camera screen's flip-camera
/// control and the photo review screen's "Retake"/"Choose another" button
/// draw the exact same SVG path in their respective canonical designs (a
/// circular double-arrow, conventionally read as "flip" in one context and
/// "redo" in the other), so this is one glyph parameterised by colour/size
/// rather than two near-identical private painters.
class RefreshCycleGlyph extends StatelessWidget {
  const RefreshCycleGlyph({super.key, this.color = AppColors.chipInactiveLight, this.size = 23});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _RefreshCycleGlyphPainter(color: color)),
    );
  }
}

class _RefreshCycleGlyphPainter extends CustomPainter {
  const _RefreshCycleGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;
    final top = Path()..moveTo(4 * w, 8 * h);
    top.arcToPoint(Offset(17.5 * w, 4 * h), radius: Radius.circular(8 * w), clockwise: true);
    top.lineTo(20 * w, 6 * h);
    canvas.drawPath(top, stroke);
    canvas.drawPath(Path()..moveTo(20 * w, 4 * h)..lineTo(20 * w, 7.5 * h)..lineTo(16.5 * w, 7.5 * h), stroke);

    final bottom = Path()..moveTo(20 * w, 16 * h);
    bottom.arcToPoint(Offset(6.5 * w, 20 * h), radius: Radius.circular(8 * w), clockwise: true);
    bottom.lineTo(4 * w, 18 * h);
    canvas.drawPath(bottom, stroke);
    canvas.drawPath(Path()..moveTo(4 * w, 20 * h)..lineTo(4 * w, 16.5 * h)..lineTo(7.5 * w, 16.5 * h), stroke);
  }

  @override
  bool shouldRepaint(_RefreshCycleGlyphPainter oldDelegate) => color != oldDelegate.color;
}
