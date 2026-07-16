import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' show Colors, GridView, NeverScrollableScrollPhysics, Scaffold, SliverGridDelegateWithFixedCrossAxisCount;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../db/database.dart' show ProofSource;
import '../../models/local_date.dart';
import '../../providers.dart';
import '../../repo/completion_repository.dart' show CompleteOccurrenceResult;
import '../../services/photo_capture.dart' show CapturedPhoto;
import '../../services/proof_flow.dart';
import '../../services/recent_photo_library.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/screen_background.dart';
import '../widgets/buttons.dart';
import '../widgets/status_chip.dart' show GalleryGlyph;
import 'photo_review_screen.dart';
import 'proof_outcome_routing.dart';
import 'verification_chrome.dart';

/// `Cairn Camera Unavailable.dc.html`: reached when
/// [CameraCaptureScreen]'s live camera can't be started at all (no
/// hardware, permission denied, or the plugin is unavailable). Replaces the
/// earlier stopgap of an inline gallery-only fallback bolted onto the
/// camera screen's own dark chrome, now that a canonical design exists.
///
/// Offers three ways to still prove the task: tap a thumbnail in the
/// "Recent photos" quick-pick grid (real device thumbnails via
/// [RecentPhotoLibrary], not the design's placeholder swatches), the
/// footer's "Choose from gallery" button (the standard `image_picker`
/// gallery flow, same as [CameraCaptureScreen]'s own gallery control), or
/// "Open camera settings" to grant permission and try the camera again
/// later. The grid degrades to a single fallback button in its own place
/// (in addition to the footer's own, unconditionally-present one) when the
/// photo library can't be read or has no photos, rather than ever showing a
/// broken/empty grid.
class CameraUnavailableScreen extends ConsumerStatefulWidget {
  const CameraUnavailableScreen({
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
  ConsumerState<CameraUnavailableScreen> createState() => _CameraUnavailableScreenState();
}

class _CameraUnavailableScreenState extends ConsumerState<CameraUnavailableScreen> {
  /// Matches `Cairn Camera Unavailable.dc.html`'s own grid: a 3-column,
  /// 2-row quick-pick of the 6 most recent photos.
  static const _gridCount = 6;

  RecentPhotosResult? _photos;
  bool _busy = false;

  /// Set once a recent-photo thumbnail is tapped or a gallery pick
  /// succeeds: the picked photo awaiting "Use this photo"/"Choose another"
  /// on `PhotoReviewScreen` - see [build]'s own short-circuit. Every photo
  /// this screen ever shows is gallery-sourced (there is no live camera
  /// here to "retake" from), so the secondary action is always "Choose
  /// another", never "Retake".
  CapturedPhoto? _reviewCapture;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPhotos());
  }

  Future<void> _loadPhotos() async {
    final result = await ref.read(recentPhotoLibraryProvider).loadRecent(count: _gridCount);
    if (mounted) setState(() => _photos = result);
  }

  Future<void> _routeResult(CompleteOccurrenceResult result, Uint8List? bytes) async {
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
    if (!handled && mounted) Navigator.of(context).pop();
  }

  /// Tapping a recent-photo thumbnail: resolves the asset to a file path and
  /// shows it on the Photo Review screen - it does NOT submit. Submission
  /// only happens if/when the user taps "Use this photo" (see
  /// [_handleUsePhoto]).
  Future<void> _selectAsset(RecentPhotoAsset asset) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await ref.read(recentPhotoLibraryProvider).filePathFor(asset.id);
      // The asset vanished between the grid load and the tap (e.g. deleted
      // from the library): stay put rather than reviewing nothing.
      if (path == null) return;
      setState(() {
        _reviewCapture = CapturedPhoto(
          tempPath: path,
          source: ProofSource.gallery,
          takenAtMillis: asset.takenAtMillis,
        );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Runs [ProofFlowService.captureForReview] and acts on its outcome.
  /// Shared by the footer's "Choose from gallery" button (the first pick,
  /// reached with [_reviewCapture] still null), the empty-grid fallback
  /// button (same), and the Photo Review screen's own "Choose another"
  /// (every re-pick, reached with [_reviewCapture] already set to a
  /// previous photo) - all three do exactly the same thing: reopen the
  /// gallery picker and, on success, show (or replace) the review photo. A
  /// cancel leaves whatever was on screen before untouched.
  Future<void> _openGalleryPicker() async {
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
          await _routeResult(result, null);
        case GalleryCapturePicked(:final captured):
          setState(() => _reviewCapture = captured);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The Photo Review screen's "Use this photo" action: submits
  /// [_reviewCapture] via `ProofFlowService.submitCapturedProof` and routes
  /// to the matching outcome screen, exactly as this screen's pre-review
  /// selection/pick flows always did.
  Future<void> _handleUsePhoto() async {
    final captured = _reviewCapture;
    if (captured == null || _busy) return;
    setState(() => _busy = true);
    try {
      final proofFlow = ref.read(proofFlowServiceProvider);
      final (result, bytes) = await proofFlow.submitCapturedProof(
        taskId: widget.taskId,
        occurrenceDate: widget.occurrenceDate,
        slot: widget.slot,
        captured: captured,
      );
      await _routeResult(result, bytes);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final reviewCapture = _reviewCapture;
    if (reviewCapture != null) {
      return PhotoReviewScreen(
        imagePath: reviewCapture.tempPath,
        taskTitle: widget.taskTitle,
        secondaryLabel: l10n.chooseAnotherPhotoButton,
        onUsePhoto: _busy ? null : _handleUsePhoto,
        onSecondaryAction: _busy ? null : _openGalleryPicker,
        onClose: () => Navigator.of(context).pop(),
      );
    }

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
              VerificationHeader(
                onClose: () => Navigator.of(context).pop(),
                label: l10n.proveItHeaderLabel,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SealCircle(
                        size: 64,
                        gradientColors: [AppColors.pendingSealLight, AppColors.pendingSealDark],
                        ringColor: Color(0x29A0947E),
                        shadowColor: Color(0x735A503C),
                        icon: SealCameraOffIcon(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.cameraUnavailableTitle,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.resultTitle.copyWith(color: AppColors.pendingHeading),
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          style: AppTextStyles.body,
                          children: [
                            TextSpan(text: '${l10n.cameraUnavailableBodyLead} '),
                            TextSpan(
                              text: '${widget.taskTitle} ',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF544D40)),
                            ),
                            TextSpan(text: l10n.cameraUnavailableBodyTrail),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 26),
                      _RecentPhotosSection(
                        result: _photos,
                        busy: _busy,
                        onSelect: _selectAsset,
                        onFallbackGallery: _openGalleryPicker,
                        label: l10n.recentPhotosLabel,
                        fallbackLabel: l10n.chooseFromGalleryButton,
                        thumbnailSemanticLabel: l10n.recentPhotoThumbnailLabel,
                      ),
                      const SizedBox(height: 18),
                      ReasonBanner(
                        backgroundColor: const Color(0x1F786C58),
                        iconColor: const Color(0xFF8A7F6C),
                        textColor: const Color(0xFF544D40),
                        spans: [
                          TextSpan(text: '${l10n.settingsHintLead} '),
                          TextSpan(
                            text: l10n.settingsHintEmphasis,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF463F31)),
                          ),
                          TextSpan(text: l10n.settingsHintTrail),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              VerificationFooter(
                children: [
                  PrimaryButton(
                    label: l10n.chooseFromGalleryButton,
                    onPressed: _busy ? null : _openGalleryPicker,
                    icon: const GalleryGlyph(color: AppColors.buttonText, size: 20),
                  ),
                  Center(
                    child: TextGhostButton(
                      label: l10n.openCameraSettingsButton,
                      onPressed: () => ref.read(appSettingsOpenerProvider).openCameraSettings(),
                    ),
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

/// The "Recent photos" quick-pick grid, or its graceful fallback: a plain
/// "Choose from gallery" button when the library can't be read, or has no
/// photos (see [CameraUnavailableScreen]'s own doc comment on why this
/// fallback button exists alongside the footer's own, always-present one).
/// Renders nothing while [result] is still null (the load hasn't resolved
/// yet), rather than flashing an empty grid or a premature fallback.
class _RecentPhotosSection extends StatelessWidget {
  const _RecentPhotosSection({
    required this.result,
    required this.busy,
    required this.onSelect,
    required this.onFallbackGallery,
    required this.label,
    required this.fallbackLabel,
    required this.thumbnailSemanticLabel,
  });

  final RecentPhotosResult? result;
  final bool busy;
  final ValueChanged<RecentPhotoAsset> onSelect;
  final VoidCallback onFallbackGallery;
  final String label;
  final String fallbackLabel;
  final String thumbnailSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final photos = result;
    if (photos == null) return const SizedBox.shrink();

    final assets = switch (photos) {
      RecentPhotosLoaded(:final assets) => assets,
      RecentPhotosUnavailable() => const <RecentPhotoAsset>[],
    };

    if (assets.isEmpty) {
      return Center(
        child: PrimaryButton(
          key: const ValueKey('recent-photos-fallback-button'),
          label: fallbackLabel,
          onPressed: busy ? null : onFallbackGallery,
          size: PrimaryButtonSize.medium,
          expand: false,
          icon: const GalleryGlyph(color: AppColors.buttonText, size: 18),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.sectionLabel),
        const SizedBox(height: 12),
        GridView(
          key: const ValueKey('recent-photos-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          children: [
            for (final asset in assets)
              _RecentPhotoThumbnail(
                key: ValueKey('recent-photo-${asset.id}'),
                asset: asset,
                enabled: !busy,
                semanticLabel: thumbnailSemanticLabel,
                onTap: () => onSelect(asset),
              ),
          ],
        ),
      ],
    );
  }
}

class _RecentPhotoThumbnail extends StatelessWidget {
  const _RecentPhotoThumbnail({
    super.key,
    required this.asset,
    required this.enabled,
    required this.semanticLabel,
    required this.onTap,
  });

  final RecentPhotoAsset asset;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.umberShadowBase.withAlpha(0x1A)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.umberShadowBase.withAlpha(0x38),
                  offset: const Offset(0, 3),
                  blurRadius: 6,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Image.memory(asset.thumbnail, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

/// The camera-off glyph inside the muted stone seal
/// (`Cairn Camera Unavailable.dc.html`'s `M2.5 8.2A2 2 0 0 1 4.5 6.5...` +
/// lens arc + diagonal slash): a hand-approximated reading of that SVG,
/// same convention as every other seal icon in this app (see
/// `verification_chrome.dart`'s [SealClockIcon]/[SealHistoryIcon]).
class SealCameraOffIcon extends StatelessWidget {
  const SealCameraOffIcon({super.key, this.color = AppColors.richCream, this.size = 30});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CameraOffPainter(color: color)),
    );
  }
}

class _CameraOffPainter extends CustomPainter {
  const _CameraOffPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.083
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;

    // Camera body, left/top fragment (viewfinder bump + left wall).
    canvas.drawPath(
      Path()
        ..moveTo(2.5 * w, 8.2 * h)
        ..arcToPoint(Offset(4.5 * w, 6.5 * h), radius: Radius.circular(2 * w))
        ..lineTo(5.7 * w, 6.5 * h)
        ..lineTo(7.0 * w, 4.6 * h)
        ..lineTo(12.0 * w, 4.6 * h),
      paint,
    );

    // Camera body, right wall fragment.
    canvas.drawPath(
      Path()
        ..moveTo(21.5 * w, 15.8 * h)
        ..lineTo(21.5 * w, 8.5 * h)
        ..arcToPoint(Offset(19.5 * w, 6.5 * h), radius: Radius.circular(2 * w))
        ..lineTo(17.3 * w, 6.5 * h),
      paint,
    );

    // Lens arc fragment.
    canvas.drawPath(
      Path()
        ..moveTo(9.8 * w, 9.9 * h)
        ..arcToPoint(Offset(14.0 * w, 14.1 * h), radius: Radius.circular(3 * w)),
      paint,
    );

    // Camera body, bottom fragment.
    canvas.drawPath(
      Path()
        ..moveTo(21.5 * w, 17.5 * h)
        ..arcToPoint(Offset(19.5 * w, 19.5 * h), radius: Radius.circular(2 * w))
        ..lineTo(6.0 * w, 19.5 * h),
      paint,
    );

    // Diagonal slash.
    canvas.drawLine(Offset(3 * w, 3.5 * h), Offset(21 * w, 21.5 * h), paint);
  }

  @override
  bool shouldRepaint(_CameraOffPainter oldDelegate) => color != oldDelegate.color;
}
