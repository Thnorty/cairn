import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/local_date.dart';
import 'package:cairn/src/models/proof_verdict.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/services/streak_service.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Coverage for the domain rule change: a pending completion must not
/// contribute metres to altitude, since altitude is a permanent cumulative
/// score and a later rejection tombstoning the row must never make it (or
/// the displayed rank) move backwards. `points_awarded` is still computed
/// and stored on the row at insert time exactly as before; it simply isn't
/// summed into [CompletionRepository.totalAltitude] until the row's status
/// flips to verified. What deliberately does NOT change: pending still
/// counts toward streaks, the daily cap, and the perfect-day bonus
/// (existing coverage for those three lives in complete_with_proof_test.dart
/// and is untouched by this file).
const _passingVerdict = ProofVerdict(
  taskShown: true,
  confidence: 0.95,
  isScreenshotOrScreen: false,
  reason: 'clear photo',
);

const _rejectingVerdict = ProofVerdict(
  taskShown: false,
  confidence: 0.1,
  isScreenshotOrScreen: false,
  reason: 'no evidence',
);

ProofData _proof([List<int> bytes = const [9]]) =>
    ProofData(imageBytes: Uint8List.fromList(bytes));

void main() {
  late AppDatabase db;

  setUp(() {
    db = inMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  test(
      'a pending completion contributes 0 to totalAltitude even though '
      'points_awarded is stored on the row', () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);
    final pendingVerifier =
        FakeProofVerifier((_) => const VerifierUnavailable('offline'));
    final repo = CompletionRepository(db, clock, verifier: pendingVerifier);

    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    final result = await repo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof(),
    );
    final pending = (result as CompletionPendingVerification).completion;

    expect(pending.pointsAwarded, greaterThan(0)); // stored, as always
    expect(await repo.totalAltitude(), 0); // but not counted yet
    expect(await repo.pendingAltitude(), pending.pointsAwarded);
  });

  test(
      'rank never decreases: with a nonzero baseline from a verified '
      'completion, a rejected retry leaves totalAltitude exactly where it '
      'was before the pending completion ever existed', () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);

    final taskA = await taskRepo.createTask(
      title: 'A (verified baseline)',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );
    final taskB = await taskRepo.createTask(
      title: 'B (goes pending, then rejected)',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    final verifiedVerifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final verifiedRepo =
        CompletionRepository(db, clock, verifier: verifiedVerifier);
    await verifiedRepo.completeWithProof(
      taskId: taskA.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof([1]),
    );

    final baseline = await verifiedRepo.totalAltitude();
    expect(baseline, greaterThan(0));

    final pendingVerifier =
        FakeProofVerifier((_) => const VerifierUnavailable('offline'));
    final pendingRepo =
        CompletionRepository(db, clock, verifier: pendingVerifier);
    await pendingRepo.completeWithProof(
      taskId: taskB.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof([2]),
    );

    // While pending, altitude must not have moved from the baseline.
    expect(await pendingRepo.totalAltitude(), baseline);

    final rejectingVerifier =
        FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
    final retryRepo =
        CompletionRepository(db, clock, verifier: rejectingVerifier);
    final report = await retryRepo.retryPendingVerifications(
      loadBytes: (completion) async => Uint8List.fromList([2]),
    );
    expect(report.rejected, 1);

    // After the rejection: still exactly the baseline. The rank cannot have
    // moved backwards, because it never counted the pending row in the
    // first place.
    expect(await retryRepo.totalAltitude(), baseline);
  });

  test(
      'pendingAltitude sums every live pending completion and drops to '
      'zero once each one resolves, whether verified or rejected', () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);

    final taskC = await taskRepo.createTask(
      title: 'C (will verify)',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );
    final taskD = await taskRepo.createTask(
      title: 'D (will reject)',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    final pendingVerifier =
        FakeProofVerifier((_) => const VerifierUnavailable('offline'));
    final setupRepo =
        CompletionRepository(db, clock, verifier: pendingVerifier);

    final resultC = await setupRepo.completeWithProof(
      taskId: taskC.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof([3]),
    );
    final resultD = await setupRepo.completeWithProof(
      taskId: taskD.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof([4]),
    );
    final pendingC = (resultC as CompletionPendingVerification).completion;
    final pendingD = (resultD as CompletionPendingVerification).completion;

    expect(
      await setupRepo.pendingAltitude(),
      pendingC.pointsAwarded + pendingD.pointsAwarded,
    );
    expect(await setupRepo.totalAltitude(), 0);

    final retryVerifier = FakeProofVerifier((req) {
      switch (req.imageBytes.first) {
        case 3:
          return const VerdictReceived(_passingVerdict);
        default:
          return const VerdictReceived(_rejectingVerdict);
      }
    });
    final retryRepo = CompletionRepository(db, clock, verifier: retryVerifier);
    final report = await retryRepo.retryPendingVerifications(
      loadBytes: (completion) async {
        if (completion.id == pendingC.id) return Uint8List.fromList([3]);
        if (completion.id == pendingD.id) return Uint8List.fromList([4]);
        return null;
      },
    );
    expect(report.verified, 1);
    expect(report.rejected, 1);

    // Every pending completion has resolved: nothing left in pendingAltitude.
    expect(await retryRepo.pendingAltitude(), 0);
    // Only C's stored points count now (unchanged from insert time, not
    // recomputed); D's were tombstoned and were never counted to begin with.
    expect(await retryRepo.totalAltitude(), pendingC.pointsAwarded);
  });

  test('a pending completion still keeps the streak alive', () async {
    final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
    const streaks = StreakService();

    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    // Days 8 and 9 verified; day 10 (today) recorded while the verifier is
    // offline, so it lands as pending.
    for (final day in [8, 9]) {
      final dayClock = FixedClock(d(2026, 7, day));
      final verifiedVerifier =
          FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
      final repo =
          CompletionRepository(db, dayClock, verifier: verifiedVerifier);
      await repo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, day),
      );
    }

    final todayClock = FixedClock(d(2026, 7, 10));
    final pendingVerifier =
        FakeProofVerifier((_) => const VerifierUnavailable('offline'));
    final pendingRepo =
        CompletionRepository(db, todayClock, verifier: pendingVerifier);
    final result = await pendingRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof(),
    );
    expect(result, isA<CompletionPendingVerification>());

    // Same query shape the app uses to feed StreakService: every live
    // completion counts, regardless of verification_status.
    final allCompletions = await (db.select(db.completions)
          ..where((c) => c.taskId.equals(task.id) & c.deletedAt.isNull()))
        .get();
    final doneSet = <(LocalDate, int)>{
      for (final c in allCompletions) (c.occurrenceDate, c.slot),
    };

    expect(
      streaks.currentStreak(
        task,
        d(2026, 7, 10),
        (date, slot) => doneSet.contains((date, slot)),
      ),
      3, // days 8, 9, and the pending day 10 all count as complete
      reason: 'a pending completion counts as done for streak purposes, '
          'exactly like a verified one',
    );
  });
}
