import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'clock.dart';
import 'db/database.dart';
import 'models/proof_verdict.dart';
import 'repo/completion_repository.dart';
import 'repo/task_repository.dart';
import 'services/occurrence_generator.dart';
import 'services/photo_capture.dart';
import 'services/points_service.dart';
import 'services/proof_flow.dart';
import 'services/proof_retry_service.dart';
import 'services/proof_verifier.dart';
import 'services/streak_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'cairn'));
  ref.onDispose(db.close);
  return db;
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final occurrenceGeneratorProvider =
    Provider<OccurrenceGenerator>((ref) => const OccurrenceGenerator());

final streakServiceProvider = Provider<StreakService>(
  (ref) => StreakService(ref.watch(occurrenceGeneratorProvider)),
);

final pointsServiceProvider =
    Provider<PointsService>((ref) => const PointsService());

final proofPolicyProvider = Provider<ProofPolicy>((ref) => const ProofPolicy());

/// Phase-2a-only debug affordance: lets the debug screen switch the fake
/// verifier's behaviour on a real device without a network call. WO-4
/// removes this, along with [FakeProofVerifier]'s production use, once the
/// real Supabase-backed verifier lands.
enum DebugVerifierMode { pass, reject, offline }

final debugVerifierModeProvider =
    StateProvider<DebugVerifierMode>((ref) => DebugVerifierMode.pass);

const _debugPassVerdict = ProofVerdict(
  taskShown: true,
  confidence: 1.0,
  isScreenshotOrScreen: false,
  screenIsPlausibleProof: false,
  reason: 'Debug mode: pass',
);

const _debugRejectVerdict = ProofVerdict(
  taskShown: false,
  confidence: 0.0,
  isScreenshotOrScreen: false,
  screenIsPlausibleProof: false,
  reason: 'Debug mode: reject',
);

// WO-4 swaps this for the Supabase-backed verifier (Phase 2b); until then the
// fake verifier drives the debug screen so the pipeline is exercisable
// end-to-end without a network call. Its behaviour follows
// [debugVerifierModeProvider], also a Phase-2a-only debug affordance.
final proofVerifierProvider = Provider<ProofVerifier>((ref) {
  final mode = ref.watch(debugVerifierModeProvider);
  return FakeProofVerifier((request) {
    switch (mode) {
      case DebugVerifierMode.pass:
        return const VerdictReceived(_debugPassVerdict);
      case DebugVerifierMode.reject:
        return const VerdictReceived(_debugRejectVerdict);
      case DebugVerifierMode.offline:
        return const VerifierUnavailable('Debug mode: offline');
    }
  });
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(databaseProvider), ref.watch(clockProvider));
});

final completionRepositoryProvider = Provider<CompletionRepository>((ref) {
  return CompletionRepository(
    ref.watch(databaseProvider),
    ref.watch(clockProvider),
    generator: ref.watch(occurrenceGeneratorProvider),
    streaks: ref.watch(streakServiceProvider),
    points: ref.watch(pointsServiceProvider),
    verifier: ref.watch(proofVerifierProvider),
    policy: ref.watch(proofPolicyProvider),
  );
});

final assetTimeResolverProvider = Provider<AssetTimeResolver>(
  (ref) => const PhotoManagerAssetTimeResolver(),
);

final photoCaptureProvider = Provider<PhotoCapture>((ref) {
  return ImagePickerPhotoCapture(
    ref.watch(clockProvider),
    ref.watch(assetTimeResolverProvider),
  );
});

final imageCompressorProvider =
    Provider<ImageCompressor>((ref) => const FlutterImageCompressor());

final proofPhotoStoreProvider =
    Provider<ProofPhotoStore>((ref) => FileProofPhotoStore());

final proofFlowServiceProvider = Provider<ProofFlowService>((ref) {
  return ProofFlowService(
    capture: ref.watch(photoCaptureProvider),
    compressor: ref.watch(imageCompressorProvider),
    store: ref.watch(proofPhotoStoreProvider),
    completionRepository: ref.watch(completionRepositoryProvider),
  );
});

final proofRetryServiceProvider = Provider<ProofRetryService>((ref) {
  return ProofRetryService(
    ref.watch(completionRepositoryProvider),
    ref.watch(proofPhotoStoreProvider),
  );
});

/// Wires [ProofRetryTrigger] into the app lifecycle. Nothing constructs the
/// trigger (and its lifecycle listener/connectivity subscription never
/// starts) until something watches this provider, so the app root must watch
/// it once at startup.
final proofRetryTriggerProvider = Provider<ProofRetryTrigger>((ref) {
  final trigger = ProofRetryTrigger(ref.watch(proofRetryServiceProvider));
  trigger.start();
  ref.onDispose(trigger.dispose);
  return trigger;
});
