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
  const ProofFlowCompleted(this.result);
}

/// The single entry point Phase 3's UI calls to record a completion backed
/// by a proof photo: capture, compress, persist, then hand off to
/// [CompletionRepository.completeWithProof] for the guard chain and
/// verification.
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
    final captured = await _capture.capture(source);
    if (captured == null) return const ProofFlowCancelled();

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

    return ProofFlowCompleted(result);
  }
}
