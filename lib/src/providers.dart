import 'dart:async';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'clock.dart';
import 'db/database.dart';
import 'models/proof_verdict.dart';
import 'repo/completion_repository.dart';
import 'repo/task_repository.dart';
import 'services/auth_service.dart';
import 'services/occurrence_generator.dart';
import 'services/photo_capture.dart';
import 'services/points_service.dart';
import 'services/proof_flow.dart';
import 'services/proof_retry_service.dart';
import 'services/proof_verifier.dart';
import 'services/streak_service.dart';
import 'services/supabase_proof_verifier.dart';

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

/// Debug affordance: lets the debug screen switch the verifier's behaviour
/// on a real device. `real` is the actual Supabase-backed verifier
/// ([SupabaseProofVerifier]), landed in WO-4; `pass`/`reject`/`offline`
/// stay as in-memory fakes so every branch of the pipeline (a clean pass, a
/// rejection with attempts remaining, an unreachable verifier going
/// pending) can still be exercised on a device without burning a real
/// Gemini call.
enum DebugVerifierMode { real, pass, reject, offline }

final debugVerifierModeProvider =
    StateProvider<DebugVerifierMode>((ref) => DebugVerifierMode.real);

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

/// Real by default (see [DebugVerifierMode]); the debug screen's menu can
/// still switch to one of the fakes to exercise a specific branch on
/// demand. Only the `real` case ever touches the network (and only when
/// [ProofVerifier.verify] is actually called, not at construction time), so
/// building this provider is always safe, including under test.
final proofVerifierProvider = Provider<ProofVerifier>((ref) {
  final mode = ref.watch(debugVerifierModeProvider);
  switch (mode) {
    case DebugVerifierMode.real:
      return SupabaseProofVerifier();
    case DebugVerifierMode.pass:
      return FakeProofVerifier((_) => const VerdictReceived(_debugPassVerdict));
    case DebugVerifierMode.reject:
      return FakeProofVerifier((_) => const VerdictReceived(_debugRejectVerdict));
    case DebugVerifierMode.offline:
      return FakeProofVerifier((_) => const VerifierUnavailable('Debug mode: offline'));
  }
});

/// Thin wrapper around Supabase anonymous auth (WO-4). Never touches the
/// Supabase SDK at build time; see [SupabaseAuthService]'s doc comment.
final authServiceProvider = Provider<AuthService>((ref) => SupabaseAuthService());

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(
    ref.watch(databaseProvider),
    ref.watch(clockProvider),
    // ref.read, not ref.watch: the getter is only *called* at insert time,
    // so this deliberately creates no build-time dependency edge on
    // authServiceProvider (same rationale as proofRetryTriggerProvider's
    // factory below).
    currentUserId: () => ref.read(authServiceProvider).currentUserId,
  );
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
    currentUserId: () => ref.read(authServiceProvider).currentUserId,
  );
});

// Photo-library metadata is tried first (its timestamp is harder to forge
// than in-file EXIF); EXIF is the fallback for cases where the library
// lookup can't resolve a match at all, e.g. Android 13+'s system Photo
// Picker handing the app a copy of the asset under a name the library
// lookup can't match (see ExifAssetTimeResolver's doc comment).
final assetTimeResolverProvider = Provider<AssetTimeResolver>(
  (ref) => const ChainedAssetTimeResolver([
    PhotoManagerAssetTimeResolver(),
    ExifAssetTimeResolver(),
  ]),
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
  final service = ProofRetryService(
    ref.watch(completionRepositoryProvider),
    ref.watch(proofPhotoStoreProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Wires [ProofRetryTrigger] into the app lifecycle. Built with a factory
/// (`() => ref.read(proofRetryServiceProvider)`) that resolves the current
/// [ProofRetryService] at call time rather than a watched, fixed instance,
/// so this provider has no dependency edge on [proofVerifierProvider] (or
/// anything else [proofRetryServiceProvider] depends on): it is built once,
/// for the life of the app, and its lifecycle listener/connectivity
/// subscription is started exactly once. Watching the service directly used
/// to rebuild this provider (and re-subscribe to connectivity_plus) every
/// time the verifier changed, which is exactly the bug this factory avoids.
/// Nothing constructs the trigger until something watches this provider, so
/// the app root must watch it once at startup.
final proofRetryTriggerProvider = Provider<ProofRetryTrigger>((ref) {
  final trigger = ProofRetryTrigger(() => ref.read(proofRetryServiceProvider));
  trigger.start();
  ref.onDispose(trigger.dispose);
  return trigger;
});

/// Kicks off anonymous sign-in (a no-op if a session already exists) and
/// then the one-time `user_id` backfill (WO-4), exactly once for the life
/// of the app. Built the same way as [proofRetryTriggerProvider]: resolves
/// [authServiceProvider] and the two repositories via `ref.read` inside the
/// async body rather than `ref.watch`, so this provider has no build-time
/// dependency edge on any of them and is never rebuilt by, say, a change to
/// the debug verifier mode. Nothing runs until something watches this
/// provider, so the app root must watch it once at startup.
///
/// Safe to (re)run on every launch without any separate "already ran"
/// flag: [AuthService.ensureSignedIn] is a no-op once a session exists, and
/// each repository's `backfillUserId` only touches rows still matching
/// `user_id IS NULL`, so it becomes a no-op too once every row has been
/// stamped once.
final authBootstrapProvider = Provider<void>((ref) {
  Future<void> run() async {
    final auth = ref.read(authServiceProvider);
    await auth.ensureSignedIn();
    final userId = auth.currentUserId;
    if (userId == null) return; // still offline/unauthenticated: nothing to backfill yet
    await ref.read(taskRepositoryProvider).backfillUserId(userId);
    await ref.read(completionRepositoryProvider).backfillUserId(userId);
  }

  unawaited(run());
});
