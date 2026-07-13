import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clock.dart';
import 'db/database.dart';
import 'models/proof_verdict.dart';
import 'repo/completion_repository.dart';
import 'repo/task_repository.dart';
import 'services/occurrence_generator.dart';
import 'services/points_service.dart';
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

// WO-4 swaps this for the Supabase-backed verifier (Phase 2b); until then the
// fake verifier drives the debug screen so the pipeline is exercisable
// end-to-end without a network call.
final proofVerifierProvider =
    Provider<ProofVerifier>((ref) => FakeProofVerifier());

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
