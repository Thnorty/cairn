import 'dart:typed_data';

import '../db/database.dart';
import '../models/local_date.dart';
import '../models/proof_verdict.dart';
import '../repo/completion_repository.dart';
import 'photo_capture.dart';

/// Outcome of [ProofFlowService.completeWithProof].
sealed class ProofFlowResult {
  const ProofFlowResult();
}

/// The user backed out of the camera/gallery picker before a photo was
/// taken. Nothing was saved and the repository was never called.
class ProofFlowCancelled extends ProofFlowResult {
  const ProofFlowCancelled();
}

/// The pipeline ran to completion; [result] is whatever
/// [CompletionRepository.completeWithProof] returned, verified, pending, or
/// any rejection.
class ProofFlowCompleted extends ProofFlowResult {
  final CompleteOccurrenceResult result;

  /// The (compressed) photo bytes just captured/picked, so a caller can show
  /// the photo immediately without reading it back from disk. This matters
  /// most for a rejection: [CompletionRepository]'s photo-lifecycle rule
  /// deletes a rejected proof's file right away (see this class's own doc
  /// comment), so the in-flight bytes are the *only* way left to show the
  /// user the photo that was just rejected. Null only when [result] came
  /// from the precheck short-circuit, before any photo was ever captured.
  final Uint8List? imageBytes;

  const ProofFlowCompleted(this.result, [this.imageBytes]);
}

/// Outcome of [ProofFlowService.captureForReview]: the gallery path's
/// "precheck, then capture" half of the "capture, then review, then submit"
/// split the Photo Review screen (`Cairn Photo Review.dc.html`) needs (see
/// this class's own doc comment). The camera path has no equivalent
/// capture-only entry point on this class: `CameraCaptureScreen` owns its
/// own `CameraSession` and already has a captured photo by the time review
/// begins, so it just builds a [CapturedPhoto] itself from the shutter's
/// result (see that screen's `_handleShutter`) rather than calling into
/// [ProofFlowService] for the capture step too.
sealed class GalleryCaptureOutcome {
  const GalleryCaptureOutcome();
}

/// The user backed out of the gallery picker before choosing a photo.
/// Nothing changes: a caller mid-review (e.g. "Choose another") should
/// simply stay on the review screen showing whatever photo it already had.
class GalleryCaptureCancelled extends GalleryCaptureOutcome {
  const GalleryCaptureCancelled();
}

/// The precheck rejected this attempt before the picker ever opened (e.g.
/// the daily cap was reached by another completion while the user was
/// reviewing a photo, or between opening this screen and tapping "Choose
/// another"). The caller should route straight to [result] - there is no
/// photo to review.
class GalleryCaptureRejected extends GalleryCaptureOutcome {
  final CompleteOccurrenceResult result;
  const GalleryCaptureRejected(this.result);
}

/// A photo was picked and is ready to show on the review screen.
class GalleryCapturePicked extends GalleryCaptureOutcome {
  final CapturedPhoto captured;
  const GalleryCapturePicked(this.captured);
}

/// The single entry point Phase 3's UI calls to record a completion backed
/// by a proof photo. Every path funnels through one compress/persist/verify
/// core ([_compressSaveAndComplete]), reached only once a photo has been
/// accepted on the Photo Review screen (`Cairn Photo Review.dc.html`,
/// "Use this photo") - that review step lives entirely in the UI layer
/// (`CameraCaptureScreen`/`CameraUnavailableScreen` show it,
/// `PhotoReviewScreen` renders it), not in this service.
///
/// - [completeWithProof]: the original all-in-one path (precheck, capture via
///   [PhotoCapture], then the core, with no review step in between) - kept
///   for the Phase 1/2 debug screen, which has no design system and so no
///   Photo Review screen to show either.
/// - [captureForReview]: the gallery path's precheck-then-capture half,
///   returning the picked photo for review instead of continuing straight
///   to submission.
/// - [submitCapturedProof]: the review screen's "Use this photo" action, for
///   a photo the UI already has in hand - either just shot by the live
///   camera (`CameraCaptureScreen` builds the [CapturedPhoto] itself; see
///   its `_handleShutter`) or already returned by [captureForReview].
///
/// Every entry point enforces the same guarantees: [CompletionRepository]
/// stays the single enforcement point (its own guard chain, not this
/// service, is what actually blocks a doomed attempt), and a photo's
/// `takenAt` always comes from the [Clock] the caller used to build it, never
/// `DateTime.now()` in this file.
class ProofFlowService {
  final PhotoCapture _capture;
  final ImageCompressor _compressor;
  final ProofPhotoStore _store;
  final CompletionRepository _completionRepository;

  ProofFlowService({
    required PhotoCapture capture,
    required ImageCompressor compressor,
    required ProofPhotoStore store,
    required CompletionRepository completionRepository,
  })  : _capture = capture,
        _compressor = compressor,
        _store = store,
        _completionRepository = completionRepository;

  Future<ProofFlowResult> completeWithProof({
    required String taskId,
    required LocalDate occurrenceDate,
    int slot = 0,
    required ProofSource source,
  }) async {
    // UX short-circuit only: CompletionRepository.precheckProof runs the
    // read-only guards that don't need a photo (back-fill, scheduled,
    // duplicate, attempts cap, daily cap), so a doomed attempt never opens
    // the camera/gallery picker and burns a photo for nothing. This does NOT
    // replace the repository's own guard chain inside completeWithProof
    // below, which stays the actual enforcement point since state can
    // change between this call and that one; do not delete either half.
    final precheckRejection = await _completionRepository.precheckProof(
      taskId: taskId,
      occurrenceDate: occurrenceDate,
      slot: slot,
    );
    if (precheckRejection != null) {
      return ProofFlowCompleted(precheckRejection);
    }

    final captured = await _capture.capture(source);
    if (captured == null) return const ProofFlowCancelled();

    // No review step here, deliberately: this all-in-one path only serves
    // the Phase 1/2 debug screen (see this class's doc comment), which has
    // no Photo Review screen to show. The real UI never calls this method -
    // it calls [captureForReview] then [submitCapturedProof] instead, with
    // the review screen interposed between them.
    final (result, bytes) = await _compressSaveAndComplete(
      taskId: taskId,
      occurrenceDate: occurrenceDate,
      slot: slot,
      captured: captured,
    );
    return ProofFlowCompleted(result, bytes);
  }

  /// The gallery path's "precheck, then capture" half of the "capture, then
  /// review, then submit" split (see this class's doc comment): runs the
  /// same UX precheck [completeWithProof] does, then opens the gallery
  /// picker via [PhotoCapture] and returns the picked photo for the caller
  /// to show on the Photo Review screen - rather than continuing straight to
  /// submission the way [completeWithProof] does. [submitCapturedProof] is
  /// that review screen's "Use this photo" action; "Choose another" calls
  /// this again.
  Future<GalleryCaptureOutcome> captureForReview({
    required String taskId,
    required LocalDate occurrenceDate,
    int slot = 0,
    required ProofSource source,
  }) async {
    // Same UX-short-circuit rationale as completeWithProof's own precheck
    // call: doesn't replace CompletionRepository's own guard chain inside
    // submitCapturedProof (the actual enforcement point), just avoids
    // opening the picker on an attempt that's already doomed.
    final precheckRejection = await _completionRepository.precheckProof(
      taskId: taskId,
      occurrenceDate: occurrenceDate,
      slot: slot,
    );
    if (precheckRejection != null) {
      return GalleryCaptureRejected(precheckRejection);
    }

    final captured = await _capture.capture(source);
    if (captured == null) return const GalleryCaptureCancelled();
    return GalleryCapturePicked(captured);
  }

  /// Submits a photo the UI already captured itself (see this class's doc
  /// comment for why). Compresses, persists, hands off to
  /// [CompletionRepository.completeWithProof], then runs the same
  /// photo-lifecycle cleanup [completeWithProof] does.
  ///
  /// Callers must run [CompletionRepository.precheckProof] (or
  /// [CompletionRepository.attemptsUsedToday]/`successfulProofsToday`)
  /// themselves *before* opening the camera - see `precheckProof`'s own doc
  /// comment. This method does not repeat that check: by the time it's
  /// called the shutter has already fired and the photo already exists, so
  /// short-circuiting here would only ever throw away a photo the user just
  /// took, never save them from taking it. [CompletionRepository]'s own guard
  /// chain inside `completeWithProof` remains the actual enforcement point
  /// either way.
  ///
  /// This is the Photo Review screen's "Use this photo" action: [captured]
  /// already names an existing photo file (from either the live camera or a
  /// gallery pick, via [captureForReview]) that the user has already seen and
  /// accepted. "Retake"/"Choose another" never calls this at all - they
  /// discard [captured] and either return to the live camera or reopen the
  /// gallery picker instead, entirely in the UI layer
  /// (`CameraCaptureScreen`/`CameraUnavailableScreen`).
  Future<(CompleteOccurrenceResult, Uint8List)> submitCapturedProof({
    required String taskId,
    required LocalDate occurrenceDate,
    int slot = 0,
    required CapturedPhoto captured,
  }) {
    return _compressSaveAndComplete(
      taskId: taskId,
      occurrenceDate: occurrenceDate,
      slot: slot,
      captured: captured,
    );
  }

  Future<(CompleteOccurrenceResult, Uint8List)> _compressSaveAndComplete({
    required String taskId,
    required LocalDate occurrenceDate,
    required int slot,
    required CapturedPhoto captured,
  }) async {
    final compressed = await _compressor.compress(captured.tempPath);
    final savedPath = await _store.save(compressed);

    final proof = ProofData(
      imageBytes: compressed,
      photoPath: savedPath,
      source: captured.source,
      photoTakenAt: captured.takenAtMillis,
    );

    final result = await _completionRepository.completeWithProof(
      taskId: taskId,
      occurrenceDate: occurrenceDate,
      slot: slot,
      proof: proof,
    );

    // Photo lifecycle: a verified or pending completion keeps the file (a
    // pending one needs it for the retry); any rejection, whatever the
    // reason, deletes it so rejected proofs don't accumulate on disk.
    final isCompletion = result is CompletionRecorded ||
        result is CompletionPendingVerification;
    if (!isCompletion) {
      await _store.delete(savedPath);
    }

    return (result, compressed);
  }
}
