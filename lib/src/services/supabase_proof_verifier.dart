import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart'
    show FunctionException, Supabase;

import '../models/proof_verdict.dart';
import 'proof_verifier.dart';

/// The wire payload sent to the `verify-proof` Edge Function: snake_case
/// keys to match what the Deno handler reads. Building this (base64 image
/// encoding included) lives outside the injectable seam below so it stays
/// covered by plain, network-free unit tests.
typedef ProofRequestPayload = Map<String, dynamic>;

/// Invokes `verify-proof` with [payload] and returns its decoded JSON body
/// on success, or throws on failure: a [FunctionException] for any non-2xx
/// response (the real Supabase SDK's own contract - see
/// `FunctionsClient.invoke`), or any other error for a network failure.
///
/// A function type, not a method, so [SupabaseProofVerifier] can be
/// constructed and unit-tested with zero network access and without the
/// Supabase SDK in the loop: tests hand it a fake that returns a canned map
/// or throws a canned exception, and drive that seam directly. Only
/// [SupabaseProofVerifier.new]'s default wires the real Supabase call.
typedef ProofInvoker = Future<Map<String, dynamic>> Function(
  ProofRequestPayload payload,
);

/// [ProofVerifier] backed by the `verify-proof` Supabase Edge Function,
/// which holds the Gemini API key server-side and returns a structured
/// [ProofVerdict] as JSON.
///
/// Every failure mode maps to [VerifierUnavailable], never to a rejection:
/// a non-2xx status (including a 401/403 auth failure or a 429 rate limit),
/// a request timeout, a thrown network error, or a 200 whose body isn't a
/// well-formed verdict (missing/mistyped fields). A rejection may only ever
/// come from an actual, well-formed verdict that fails
/// [ProofPolicy.isVerified] - that mapping happens one layer up, in
/// [CompletionRepository.completeWithProof]; this class only ever produces
/// [VerdictReceived] or [VerifierUnavailable].
class SupabaseProofVerifier implements ProofVerifier {
  /// Name of the deployed Edge Function.
  static const String functionName = 'verify-proof';

  /// Every proof photo reaches this class already compressed to JPEG by
  /// [FlutterImageCompressor], so the mime type is always this constant;
  /// there is no path that produces any other format.
  static const String _imageMimeType = 'image/jpeg';

  final ProofInvoker _invoke;
  final Duration _timeout;

  SupabaseProofVerifier({
    ProofInvoker invoke = _defaultInvoke,
    Duration timeout = const Duration(seconds: 30),
  })  : _invoke = invoke,
        _timeout = timeout;

  @override
  Future<ProofVerifierResponse> verify(ProofRequest request) async {
    final payload = <String, dynamic>{
      'task_title': request.taskTitle,
      'task_description': request.taskDescription,
      'image_base64': base64Encode(request.imageBytes),
      'mime_type': _imageMimeType,
    };

    final Map<String, dynamic> json;
    try {
      json = await _invoke(payload).timeout(_timeout);
    } on TimeoutException {
      return const VerifierUnavailable('verify-proof timed out');
    } on FunctionException catch (e) {
      return VerifierUnavailable(
        'verify-proof returned ${e.status}: ${e.reasonPhrase ?? e.details}',
      );
    } catch (e) {
      return VerifierUnavailable('verify-proof call failed: $e');
    }

    try {
      return VerdictReceived(ProofVerdict.fromJson(json));
    } catch (e) {
      return VerifierUnavailable('verify-proof returned a malformed verdict: $e');
    }
  }

  /// The real network call, wired as [_invoke]'s default. Never evaluated
  /// (and so never touches [Supabase.instance]) until [verify] actually
  /// runs, which keeps merely *constructing* a [SupabaseProofVerifier] safe
  /// even before `Supabase.initialize()` has run (e.g. under test).
  static Future<Map<String, dynamic>> _defaultInvoke(
    ProofRequestPayload payload,
  ) async {
    final response = await Supabase.instance.client.functions.invoke(
      functionName,
      body: payload,
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw FormatException(
      'verify-proof returned non-object JSON: ${data.runtimeType}',
    );
  }
}
