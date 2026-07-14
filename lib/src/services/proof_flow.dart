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

/// The single entry point Phase 3's UI calls to record a completion backed
/// by a proof photo. Two entry points share one compress/persist/verify
/// core ([_compressSaveAndComplete]):
///
/// - [completeWithProof]: the original all-in-one path (precheck, capture via
///   [PhotoCapture], then the core) - still used for the gallery path (via
///   `image_picker`) and the Phase 1/2 debug screen.
/// - [submitCapturedProof]: for a photo the UI already captured itself. The
///   canonical `Cairn Camera Capture.dc.html` custom in-app camera (live
///   preview, shutter, flip) is driven by `CameraSession`
///   (`camera_session.dart`), a widget-owned resource `ProofFlowService` has
///   no business managing - by the time this is called the shutter has
///   already fired and a temp file already exists, so there is no capture
///   step (or cancellation) left for this method to run.
///
/// Both entry points enforce the same guarantees: [CompletionRepository]
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

    final (result, bytes) = await _compressSaveAndComplete(
      taskId: taskId,
      occurrenceDate: occurrenceDate,
      slot: slot,
      captured: captured,
    );
    return ProofFlowCompleted(result, bytes);
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
