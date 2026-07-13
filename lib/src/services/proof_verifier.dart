import 'dart:typed_data';

import '../models/proof_verdict.dart';

/// What the verifier needs to judge a proof photo against a task.
class ProofRequest {
  final Uint8List imageBytes;
  final String taskTitle;
  final String? taskDescription;

  const ProofRequest({
    required this.imageBytes,
    required this.taskTitle,
    this.taskDescription,
  });
}

/// Outcome of a verification call.
sealed class ProofVerifierResponse {
  const ProofVerifierResponse();
}

/// The verifier returned a verdict (which may pass or fail policy).
class VerdictReceived extends ProofVerifierResponse {
  final ProofVerdict verdict;
  const VerdictReceived(this.verdict);
}

/// The verifier could not be reached (offline, server error). This is NOT a
/// rejection: the completion goes to `pending` and resolves via retry.
class VerifierUnavailable extends ProofVerifierResponse {
  final String reason;
  const VerifierUnavailable(this.reason);
}

/// Judges whether a proof photo shows the given task being done.
///
/// The real implementation (a Supabase Edge Function holding the Gemini key)
/// arrives in a later work order; until then [FakeProofVerifier] stands in.
abstract class ProofVerifier {
  Future<ProofVerifierResponse> verify(ProofRequest request);
}

/// In-memory verifier for tests and the Phase 2 debug screen.
///
/// Production-visible on purpose: the debug screen uses it until the real
/// Supabase-backed verifier exists. The optional [handler] lets tests script
/// arbitrary responses; without one, every request passes.
class FakeProofVerifier implements ProofVerifier {
  final ProofVerifierResponse Function(ProofRequest request)? _handler;

  /// How many times [verify] was called.
  int callCount = 0;

  /// Every request seen, in order.
  final List<ProofRequest> requests = [];

  FakeProofVerifier([this._handler]);

  static const ProofVerdict _passingVerdict = ProofVerdict(
    taskShown: true,
    confidence: 1.0,
    isScreenshotOrScreen: false,
    screenIsPlausibleProof: false,
    reason: 'fake',
  );

  @override
  Future<ProofVerifierResponse> verify(ProofRequest request) async {
    callCount++;
    requests.add(request);
    final handler = _handler;
    if (handler != null) return handler(request);
    return const VerdictReceived(_passingVerdict);
  }
}
