import 'dart:typed_data';

import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/proof_verdict.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/points_service.dart';
import 'package:cairn/src/services/profile_service.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = inMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  ProfileService buildService(Clock clock, {ProofVerifier? verifier}) {
    final completionRepo = CompletionRepository(
      db,
      clock,
      verifier: verifier ?? FakeProofVerifier(),
    );
    return ProfileService(db, completionRepo, const PointsService());
  }

  group('buildSnapshot', () {
    test('a fresh database has zero total/pending altitude and ranks Pebble',
        () async {
      final service = buildService(FixedClock(d(2026, 7, 10)));

      final snapshot = await service.buildSnapshot();

      expect(snapshot.totalAltitude, 0);
      expect(snapshot.pendingAltitude, 0);
      expect(snapshot.rank.tier, RankTier.pebble);
      expect(snapshot.rank.metresToNext, 150);
      expect(snapshot.rank.nextTier, RankTier.cairn);
    });

    test(
        'assembles totalAltitude/pendingAltitude/rank from the real '
        'repositories, matching CompletionRepository and PointsService '
        'directly', () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);

      final verifiedTask = await taskRepo.createTask(
        title: 'Verified habit',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final pendingTask = await taskRepo.createTask(
        title: 'Pending habit',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final verifiedRepo = CompletionRepository(
        db,
        clock,
        verifier: FakeProofVerifier(
          (_) => const VerdictReceived(
            ProofVerdict(
              taskShown: true,
              confidence: 0.95,
              isScreenshotOrScreen: false,
              reason: 'clear photo',
            ),
          ),
        ),
      );
      await verifiedRepo.completeWithProof(
        taskId: verifiedTask.id,
        occurrenceDate: d(2026, 7, 10),
        proof: ProofData(imageBytes: Uint8List.fromList([1])),
      );

      final pendingRepo = CompletionRepository(
        db,
        clock,
        verifier: FakeProofVerifier((_) => const VerifierUnavailable('offline')),
      );
      await pendingRepo.completeWithProof(
        taskId: pendingTask.id,
        occurrenceDate: d(2026, 7, 10),
        proof: ProofData(imageBytes: Uint8List.fromList([2])),
      );

      final service = ProfileService(db, verifiedRepo, const PointsService());
      final snapshot = await service.buildSnapshot();

      final expectedTotal = await verifiedRepo.totalAltitude();
      final expectedPending = await verifiedRepo.pendingAltitude();
      expect(snapshot.totalAltitude, expectedTotal);
      expect(snapshot.pendingAltitude, expectedPending);
      expect(snapshot.totalAltitude, greaterThan(0));
      expect(snapshot.pendingAltitude, greaterThan(0));
      expect(snapshot.rank.tier, const PointsService().rankFor(expectedTotal).tier);
    });
  });

  group('watchProfile', () {
    test('emits an updated snapshot when a completion is recorded elsewhere',
        () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());
      final service = ProfileService(db, completionRepo, const PointsService());

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final snapshots = <ProfileSnapshot>[];
      final subscription = service.watchProfile().listen(snapshots.add);
      addTearDown(subscription.cancel);

      // Let the first (synchronous-ish) emission land.
      await Future<void>.delayed(Duration.zero);
      expect(snapshots, isNotEmpty);
      expect(snapshots.last.totalAltitude, 0);

      await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      await Future<void>.delayed(Duration.zero);

      expect(snapshots.last.totalAltitude, greaterThan(0));
    });
  });
}
