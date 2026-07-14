import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' show MaterialLocalizations, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../db/database.dart' show ProofSource;
import '../../models/local_date.dart';
import '../../providers.dart';
import '../../services/camera_session.dart';
import '../../services/photo_capture.dart' show CapturedPhoto;
import '../../services/proof_flow.dart';
import '../theme/app_gradients.dart';
import '../widgets/status_chip.dart' show CloseGlyph;
import 'proof_outcome_routing.dart';

/// `Cairn Camera Capture.dc.html`: the custom in-app camera screen (live
/// preview, shutter, flip, gallery fallback, and the "Verifying…" overlay).
///
/// A dark, camera-app-style screen rather than the shared warm-parchment
/// [ScreenBackground] every other Phase 3 screen uses - a deliberate
/// exception matching the design file's own distinct dark styling (real
/// camera UIs are conventionally dark so the live feed reads clearly), not
/// an invented departure from the design system.
///
/// Owns a [CameraSession] for exactly its own lifetime (acquired here in
/// `initState`, released in `dispose`) - see `cameraSessionFactoryProvider`'s
/// doc comment for why that's a factory, not a shared provider instance.
/// Degrades gracefully to the gallery-only path when the camera can't be
/// started at all (see [_CameraPhase.unavailable]): there is no canonical
/// design for that state (a noted gap - see the phase-3 implementation
/// report), so it reuses this same screen's own chrome and gallery control
/// rather than inventing a new layout.
class CameraCaptureScreen extends ConsumerStatefulWidget {
  const CameraCaptureScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.cairnNumber,
    required this.occurrenceDate,
    required this.slot,
  });

  final String taskId;
  final String taskTitle;
  final int cairnNumber;
  final LocalDate occurrenceDate;
  final int slot;

  @override
  ConsumerState<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

enum _CameraPhase { initializing, live, unavailable, verifying }

class _CameraCaptureScreenState extends ConsumerState<CameraCaptureScreen> {
  late final CameraSession _session;
  _CameraPhase _phase = _CameraPhase.initializing;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _session = ref.read(cameraSessionFactoryProvider)();
    unawaited(_initCamera());
  }

  Future<void> _initCamera() async {
    final ok = await _session.initialize();
    if (!mounted) return;
    setState(() => _phase = ok ? _CameraPhase.live : _CameraPhase.unavailable);
  }

  @override
  void dispose() {
    unawaited(_session.dispose());
    super.dispose();
  }

  Future<void> _handleShutter() async {
    if (_busy || _phase != _CameraPhase.live) return;
    setState(() {
      _busy = true;
      _phase = _CameraPhase.verifying;
    });
    try {
      final path = await _session.takePicture();
      if (!mounted) return;
      final clock = ref.read(clockProvider);
      final captured = CapturedPhoto(
        tempPath: path,
        source: ProofSource.camera,
        takenAtMillis: clock.nowEpochMillis(),
      );
      final proofFlow = ref.read(proofFlowServiceProvider);
      final (result, bytes) = await proofFlow.submitCapturedProof(
        taskId: widget.taskId,
        occurrenceDate: widget.occurrenceDate,
        slot: widget.slot,
        captured: captured,
      );
      if (!mounted) return;
      final handled = await routeToProofOutcome(
        context,
        ref,
        result: result,
        taskId: widget.taskId,
        taskTitle: widget.taskTitle,
        cairnNumber: widget.cairnNumber,
        occurrenceDate: widget.occurrenceDate,
        slot: widget.slot,
        imageBytes: bytes,
        replace: true,
      );
      if (!handled && mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      // The shutter/network hiccuped: back to a live viewfinder rather than
      // stranding the user on a permanent "Verifying…" screen.
      if (mounted) setState(() => _phase = _CameraPhase.live);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final proofFlow = ref.read(proofFlowServiceProvider);
      final flowResult = await proofFlow.completeWithProof(
        taskId: widget.taskId,
        occurrenceDate: widget.occurrenceDate,
        slot: widget.slot,
        source: ProofSource.gallery,
      );
      if (!mounted) return;
      switch (flowResult) {
        case ProofFlowCancelled():
          break; // stay on this screen; nothing to route
        case ProofFlowCompleted(result: final result, imageBytes: final bytes):
          final handled = await routeToProofOutcome(
            context,
            ref,
            result: result,
            taskId: widget.taskId,
            taskTitle: widget.taskTitle,
            cairnNumber: widget.cairnNumber,
            occurrenceDate: widget.occurrenceDate,
            slot: widget.slot,
            imageBytes: bytes,
            replace: true,
          );
          if (!handled && mounted) Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleFlip() async {
    if (_phase != _CameraPhase.live) return;
    await _session.switchCamera();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF211D18),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackdrop(),
          if (_phase == _CameraPhase.live)
            const Positioned(
              left: 40,
              right: 40,
              top: 150,
              bottom: 210,
              child: IgnorePointer(child: _FramingCorners()),
            ),
          if (_phase == _CameraPhase.verifying)
            const DecoratedBox(decoration: BoxDecoration(color: Color(0x9E1A1E14))),
          if (_phase != _CameraPhase.verifying) _buildChrome(l10n),
          if (_phase == _CameraPhase.verifying)
            Center(child: _VerifyingOverlay(taskTitle: widget.taskTitle)),
        ],
      ),
    );
  }

  Widget _buildBackdrop() {
    switch (_phase) {
      case _CameraPhase.live:
      case _CameraPhase.verifying:
        return _session.buildPreview();
      case _CameraPhase.initializing:
      case _CameraPhase.unavailable:
        return const DecoratedBox(decoration: BoxDecoration(color: Color(0xFF211D18)));
    }
  }

  Widget _buildChrome(AppLocalizations l10n) {
    return SafeArea(
      child: Column(
        children: [
          _TopBar(onClose: () => Navigator.of(context).pop()),
          const SizedBox(height: 12),
          _TaskPill(label: l10n.provingLabel, taskTitle: widget.taskTitle),
          const Spacer(),
          if (_phase == _CameraPhase.unavailable)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 32, vertical: 24),
              child: Text(
                l10n.cameraUnavailableMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Work Sans',
                  fontSize: 14,
                  color: Color(0xFFE4DECE),
                ),
              ),
            ),
          _BottomControls(
            galleryLabel: l10n.galleryButton,
            flipLabel: l10n.flipCameraButton,
            onGallery: _busy ? null : _handleGallery,
            onShutter: _phase == _CameraPhase.live && !_busy ? _handleShutter : null,
            onFlip: _phase == _CameraPhase.live && _session.hasMultipleCameras && !_busy
                ? _handleFlip
                : null,
            showShutter: _phase == _CameraPhase.live,
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

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
                decoration: const BoxDecoration(color: Color(0x66141210), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const CloseGlyph(color: Color(0xFFF2EDE2), size: 16),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _TaskPill extends StatelessWidget {
  const _TaskPill({required this.label, required this.taskTitle});

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
                color: Color(0xFFC2CDAE),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              taskTitle,
              style: const TextStyle(
                fontFamily: 'Zilla Slab',
                fontWeight: FontWeight.w600,
                fontSize: 19,
                color: Color(0xFFF4F0E6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.galleryLabel,
    required this.flipLabel,
    required this.onGallery,
    required this.onShutter,
    required this.onFlip,
    required this.showShutter,
  });

  final String galleryLabel;
  final String flipLabel;
  final VoidCallback? onGallery;
  final VoidCallback? onShutter;
  final VoidCallback? onFlip;
  final bool showShutter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(34, 0, 34, 34),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _IconLabelButton(
            key: const ValueKey('camera-gallery'),
            icon: const _GalleryGlyph(),
            label: galleryLabel,
            onTap: onGallery,
          ),
          if (showShutter)
            _ShutterButton(key: const ValueKey('camera-shutter'), onTap: onShutter)
          else
            const SizedBox(width: 82, height: 82),
          if (showShutter)
            _IconLabelButton(
              key: const ValueKey('camera-flip'),
              icon: const _FlipGlyph(),
              label: flipLabel,
              onTap: onFlip,
            )
          else
            const SizedBox(width: 62),
        ],
      ),
    );
  }
}

class _IconLabelButton extends StatelessWidget {
  const _IconLabelButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: SizedBox(
          width: 62,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0x80282420),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x29FFFFFF)),
                ),
                alignment: Alignment.center,
                child: icon,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Work Sans',
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: Color(0xFFE4DECE),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          width: 82,
          height: 82,
          padding: const EdgeInsets.all(5),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x47F4F0E6),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.terracottaButton,
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryGlyph extends StatelessWidget {
  const _GalleryGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 24, height: 24, child: CustomPaint(painter: _GalleryGlyphPainter()));
  }
}

class _GalleryGlyphPainter extends CustomPainter {
  const _GalleryGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFFF2EDE2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3 * w, 4 * h, 18 * w, 16 * h),
        Radius.circular(3 * w),
      ),
      stroke,
    );
    canvas.drawCircle(Offset(8.5 * w, 9.5 * h), 1.6 * w, stroke);
    final path = Path()
      ..moveTo(3.5 * w, 17 * h)
      ..lineTo(8.5 * w, 12.5 * h)
      ..lineTo(12.5 * w, 16 * h)
      ..lineTo(15.5 * w, 13.5 * h)
      ..lineTo(20.5 * w, 18 * h);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_GalleryGlyphPainter oldDelegate) => false;
}

class _FlipGlyph extends StatelessWidget {
  const _FlipGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 23, height: 23, child: CustomPaint(painter: _FlipGlyphPainter()));
  }
}

class _FlipGlyphPainter extends CustomPainter {
  const _FlipGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFFF2EDE2)
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
  bool shouldRepaint(_FlipGlyphPainter oldDelegate) => false;
}

/// The "Verifying…" overlay (state 2 of `Cairn Camera Capture.dc.html`): a
/// pulsing sage ring behind a small cairn glyph, the verifying title, and a
/// subtitle naming the task. Runs a repeating animation (matching the
/// design's `cairnPulse` CSS keyframe) - callers/tests must not
/// `pumpAndSettle()` while this is on screen, since a repeating
/// [AnimationController] never settles.
class _VerifyingOverlay extends StatefulWidget {
  const _VerifyingOverlay({required this.taskTitle});

  final String taskTitle;

  @override
  State<_VerifyingOverlay> createState() => _VerifyingOverlayState();
}

class _VerifyingOverlayState extends State<_VerifyingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final pulse = (math.sin(_controller.value * 2 * math.pi) + 1) / 2;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0.55 + pulse * 0.35,
                    child: Transform.scale(
                      scale: 1.0 + pulse * 0.12,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0x807A8D60), Color(0x007A8D60)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const _MiniCairnGlyph(),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        Text(
          l10n.verifyingTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Zilla Slab',
            fontWeight: FontWeight.w600,
            fontSize: 24,
            color: Color(0xFFF4F0E6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.verifyingSubtitle(widget.taskTitle),
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Work Sans', fontSize: 13, color: Color(0xFFC8D0B6)),
        ),
      ],
    );
  }
}

/// The tiny 3-stone sage cairn glyph inside the verifying pulse ring.
class _MiniCairnGlyph extends StatelessWidget {
  const _MiniCairnGlyph();

  static const _bars = [
    (width: 14.0, color: Color(0xFFC2CDAE)),
    (width: 22.0, color: Color(0xFFA9B78E)),
    (width: 30.0, color: Color(0xFF93A473)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final bar in _bars)
          Container(
            width: bar.width,
            height: 8,
            margin: const EdgeInsets.only(bottom: 1),
            decoration: BoxDecoration(color: bar.color, borderRadius: BorderRadius.circular(4)),
          ),
      ],
    );
  }
}

/// The four L-shaped viewfinder corner brackets over the live preview
/// (`Cairn Camera Capture.dc.html`'s "framing corners" overlay), purely
/// decorative - it doesn't affect what the shutter actually captures (the
/// full frame, same as any camera app).
class _FramingCorners extends StatelessWidget {
  const _FramingCorners();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _FramingCornersPainter());
  }
}

class _FramingCornersPainter extends CustomPainter {
  const _FramingCornersPainter();

  static const _cornerLength = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xB3F4F0E6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    const l = _cornerLength;

    // Top-left
    canvas.drawLine(Offset.zero, const Offset(l, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, l), paint);
    // Top-right
    canvas.drawLine(Offset(w, 0), Offset(w - l, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, l), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, h), Offset(l, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - l), paint);
    // Bottom-right
    canvas.drawLine(Offset(w, h), Offset(w - l, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - l), paint);
  }

  @override
  bool shouldRepaint(_FramingCornersPainter oldDelegate) => false;
}
