import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' show MaterialPageRoute, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../db/database.dart' show ProofSource;
import '../../models/local_date.dart';
import '../../providers.dart';
import '../../services/camera_session.dart';
import '../../services/photo_capture.dart' show CapturedPhoto;
import '../../services/proof_flow.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../widgets/status_chip.dart' show GalleryGlyph;
import 'camera_chrome.dart';
import 'camera_unavailable_screen.dart';
import 'photo_review_screen.dart';
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
/// Degrades gracefully when the camera can't be started at all: navigates
/// (`pushReplacement`) to [CameraUnavailableScreen] - its own canonical
/// design (`Cairn Camera Unavailable.dc.html`), not an inline fallback
/// bolted onto this screen's own dark camera-app chrome.
class CameraCaptureScreen extends ConsumerStatefulWidget {
  const CameraCaptureScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.occurrenceDate,
    required this.slot,
  });

  final String taskId;
  final String taskTitle;
  final LocalDate occurrenceDate;
  final int slot;

  @override
  ConsumerState<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

enum _CameraPhase { initializing, live, reviewing, verifying }

class _CameraCaptureScreenState extends ConsumerState<CameraCaptureScreen> {
  late final CameraSession _session;
  _CameraPhase _phase = _CameraPhase.initializing;
  bool _busy = false;

  /// Set once the shutter fires or a gallery pick succeeds, while
  /// [_phase] is [_CameraPhase.reviewing]: the just-shot/picked photo
  /// awaiting "Use this photo"/"Retake" (or "Choose another") on
  /// [PhotoReviewScreen] - see [build]'s own short-circuit. Cleared again on
  /// a camera retake; replaced (not cleared) by a fresh pick on "Choose
  /// another".
  CapturedPhoto? _reviewCapture;

  @override
  void initState() {
    super.initState();
    _session = ref.read(cameraSessionFactoryProvider)();
    unawaited(_initCamera());
  }

  Future<void> _initCamera() async {
    final ok = await _session.initialize();
    if (!mounted) return;
    if (!ok) {
      // The camera couldn't be started at all (no hardware, permission
      // denied, or the plugin is unavailable): hand off to its own
      // canonical screen rather than degrading in place. `pushReplacement`
      // (not `push`): this screen's live camera resource is now pointless
      // to keep around underneath, and closing the unavailable screen
      // should return the user to wherever "Prove it" was tapped from, not
      // back to a dead viewfinder.
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => CameraUnavailableScreen(
          taskId: widget.taskId,
          taskTitle: widget.taskTitle,
          occurrenceDate: widget.occurrenceDate,
          slot: widget.slot,
        ),
      ));
      return;
    }
    setState(() => _phase = _CameraPhase.live);
  }

  @override
  void dispose() {
    unawaited(_session.dispose());
    super.dispose();
  }

  /// Fires the shutter and shows the just-shot still on [PhotoReviewScreen]
  /// (`Cairn Photo Review.dc.html`) - does NOT submit. Submission only
  /// happens if/when the user taps "Use this photo" (see [_handleUsePhoto]);
  /// "Retake" (see [_handleRetakeCameraPhoto]) discards this capture and
  /// returns here to [_CameraPhase.live] without ever calling
  /// `ProofFlowService.submitCapturedProof`.
  Future<void> _handleShutter() async {
    if (_busy || _phase != _CameraPhase.live) return;
    setState(() => _busy = true);
    try {
      final path = await _session.takePicture();
      if (!mounted) return;
      final clock = ref.read(clockProvider);
      setState(() {
        _reviewCapture = CapturedPhoto(
          tempPath: path,
          source: ProofSource.camera,
          takenAtMillis: clock.nowEpochMillis(),
        );
        _phase = _CameraPhase.reviewing;
      });
    } catch (_) {
      // The shutter hiccuped: stay on a live viewfinder rather than
      // stranding the user on a broken review screen.
      if (mounted) setState(() => _phase = _CameraPhase.live);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Runs [ProofFlowService.captureForReview] for the gallery path and acts
  /// on its outcome. Shared by the live screen's own "Gallery" control (the
  /// first pick) and the Photo Review screen's "Choose another" (every
  /// re-pick) - both do exactly the same thing: reopen the gallery picker
  /// and, on success, show (or replace) the review photo. A cancel leaves
  /// whatever was on screen before untouched (the live camera on a first
  /// pick, the previous review photo on a re-pick).
  Future<void> _pickFromGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final proofFlow = ref.read(proofFlowServiceProvider);
      final outcome = await proofFlow.captureForReview(
        taskId: widget.taskId,
        occurrenceDate: widget.occurrenceDate,
        slot: widget.slot,
        source: ProofSource.gallery,
      );
      if (!mounted) return;
      switch (outcome) {
        case GalleryCaptureCancelled():
          break; // stay put; nothing to route
        case GalleryCaptureRejected(:final result):
          final handled = await routeToProofOutcome(
            context,
            ref,
            result: result,
            taskId: widget.taskId,
            taskTitle: widget.taskTitle,
            occurrenceDate: widget.occurrenceDate,
            slot: widget.slot,
            replace: true,
          );
          if (!handled && mounted) Navigator.of(context).pop();
        case GalleryCapturePicked(:final captured):
          setState(() {
            _reviewCapture = captured;
            _phase = _CameraPhase.reviewing;
          });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The Photo Review screen's "Use this photo" action: submits
  /// [_reviewCapture] via `ProofFlowService.submitCapturedProof` and routes
  /// to the matching outcome screen, exactly as the pre-review shutter flow
  /// always did. Only a just-shot camera photo switches to the
  /// pulsing "Verifying…" overlay ([_CameraPhase.verifying]) while the
  /// round trip runs, matching that overlay's own camera-shutter origin; a
  /// gallery-sourced photo just stays on the (busy-disabled) review screen
  /// until routing happens, matching this screen's pre-review gallery
  /// behaviour (which never showed that overlay either).
  Future<void> _handleUsePhoto() async {
    final captured = _reviewCapture;
    if (captured == null || _busy) return;
    final isCameraSource = captured.source == ProofSource.camera;
    setState(() {
      _busy = true;
      if (isCameraSource) _phase = _CameraPhase.verifying;
    });
    try {
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
        occurrenceDate: widget.occurrenceDate,
        slot: widget.slot,
        imageBytes: bytes,
        replace: true,
      );
      if (!handled && mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      // The submit round trip hiccuped (e.g. a transient compress/IO
      // error): back to reviewing the same photo rather than losing it or
      // stranding the user on a permanent verifying overlay.
      if (mounted) setState(() => _phase = _CameraPhase.reviewing);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The Photo Review screen's "Retake" action for a just-shot camera
  /// photo: discards [_reviewCapture] (best-effort deleting its raw temp
  /// file - this app owns that file, unlike a gallery pick, whose file the
  /// OS/photo library owns and this app must never delete) and returns to
  /// the still-live camera. Never calls `submitCapturedProof`.
  ///
  /// Cleanup goes through the injected [ProofPhotoStore] (`delete` is a
  /// generic "remove whatever's at this path, ignore failures" operation,
  /// not tied to a path the store itself produced via `save`) rather than a
  /// raw `dart:io` File call: every widget test already fakes that provider
  /// (`FakeProofPhotoStore`), and real file I/O started directly from a
  /// widget callback doesn't resolve reliably under `flutter_test`'s pumped
  /// frames - the exact reason `PhotoCapture`/`ImageCompressor` are
  /// injected abstractions here too, never touched directly.
  Future<void> _handleRetakeCameraPhoto() async {
    final captured = _reviewCapture;
    if (captured == null) return;
    try {
      await ref.read(proofPhotoStoreProvider).delete(captured.tempPath);
    } catch (_) {
      // Best-effort only: a stray temp file left behind costs only disk
      // space, so this never surfaces an error to the user.
    }
    if (!mounted) return;
    setState(() {
      _reviewCapture = null;
      _phase = _CameraPhase.live;
    });
  }

  Future<void> _handleFlip() async {
    if (_phase != _CameraPhase.live) return;
    await _session.switchCamera();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final reviewCapture = _reviewCapture;
    if (_phase == _CameraPhase.reviewing && reviewCapture != null) {
      final isCameraSource = reviewCapture.source == ProofSource.camera;
      return PhotoReviewScreen(
        imagePath: reviewCapture.tempPath,
        taskTitle: widget.taskTitle,
        secondaryLabel: isCameraSource ? l10n.retakeButton : l10n.chooseAnotherPhotoButton,
        onUsePhoto: _busy ? null : _handleUsePhoto,
        onSecondaryAction: _busy
            ? null
            : (isCameraSource ? _handleRetakeCameraPhoto : _pickFromGallery),
        onClose: () => Navigator.of(context).pop(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.cameraChromeBackground,
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
        return _CoverCameraPreview(
          aspectRatio: _session.previewAspectRatio,
          child: _session.buildPreview(),
        );
      case _CameraPhase.reviewing:
        // Unreachable in practice: build() short-circuits to
        // PhotoReviewScreen before ever calling this method while
        // reviewing. Kept only so this switch stays exhaustive.
        return const SizedBox.shrink();
      case _CameraPhase.initializing:
        return const DecoratedBox(decoration: BoxDecoration(color: AppColors.cameraChromeBackground));
    }
  }

  Widget _buildChrome(AppLocalizations l10n) {
    return SafeArea(
      child: Column(
        children: [
          CameraTopBar(onClose: () => Navigator.of(context).pop()),
          const SizedBox(height: 12),
          CameraTaskPill(label: l10n.provingLabel, taskTitle: widget.taskTitle),
          const Spacer(),
          _BottomControls(
            galleryLabel: l10n.galleryButton,
            flipLabel: l10n.flipCameraButton,
            onGallery: _busy ? null : _pickFromGallery,
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

/// Sizes [child] (the live camera preview) to [aspectRatio] and scales it up
/// to fill the viewfinder by center-cropping (`BoxFit.cover`), never by
/// stretching.
///
/// Needed because this screen sits its preview inside a
/// `Stack(fit: StackFit.expand)` (see `build()`/`_buildBackdrop()` above),
/// which hands its non-positioned children *tight* constraints - and a
/// tight-constrained `AspectRatio` (which is exactly what `package:camera`'s
/// own `CameraPreview` wraps itself in) can't honour its own ratio and just
/// stretches to fill instead, distorting the live feed. Wrapping the preview
/// in a correctly-proportioned box first (whose absolute size doesn't
/// matter, only its ratio), then letting `FittedBox(fit: cover)` do the
/// scaling/cropping against an unconstrained `OverflowBox`, is the standard
/// fix for that Stack/AspectRatio interaction - `CameraPreview`'s own inner
/// `AspectRatio` still runs, but by the time it does, the box it's laying
/// out into already has the right proportions, so being forced to fill it
/// exactly causes no distortion.
class _CoverCameraPreview extends StatelessWidget {
  const _CoverCameraPreview({required this.aspectRatio, required this.child});

  final double aspectRatio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: 100 * aspectRatio, height: 100, child: child),
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
            icon: const GalleryGlyph(color: AppColors.chipInactiveLight),
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
              icon: const RefreshCycleGlyph(),
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
                  border: Border.all(color: AppColors.cameraGlassBorder),
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
                            colors: [Color(0x807A8D60), AppColors.sageGlowEnd],
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
            color: AppColors.sageChipText,
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
    (width: 14.0, color: AppColors.heroLabelSage),
    (width: 22.0, color: AppColors.miniCairnMid),
    (width: 30.0, color: AppColors.miniCairnDark),
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
