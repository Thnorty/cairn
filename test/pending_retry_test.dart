import 'dart:typed_data';

import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/proof_verdict.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _passingVerdict = ProofVerdict(
  taskShown: true,
  confidence: 0.95,
  isScreenshotOrScreen: false,
  screenIsPlausibleProof: false,
  reason: 'clear photo',
);

const _rejectingVerdict = ProofVerdict(
  taskShown: false,
  confidence: 0.1,
  isScreenshotOrScreen: false,
  screenIsPlausibleProof: false,
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

  test('pending -> verified flips the same row in place', () async {
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
    expect(pending.verificationStatus, VerificationStatus.pending);

    final retryVerifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final retryRepo =
        CompletionRepository(db, clock, verifier: retryVerifier);

    final report = await retryRepo.retryPendingVerifications(
      loadBytes: (completion) async => Uint8List.fromList([9]),
    );

    expect(report.verified, 1);
    expect(report.rejected, 0);
    expect(report.stillPending, 0);
    expect(report.skipped, 0);

    final rows = await db.select(db.completions).get();
    expect(rows, hasLength(1)); // same row, not a new one
    expect(rows.single.id, pending.id);
    expect(rows.single.verificationStatus, VerificationStatus.verified);
    expect(rows.single.pointsAwarded, pending.pointsAwarded); // unchanged
    expect(rows.single.deletedAt, isNull);

    final attempts = await db.select(db.verificationAttempts).get();
    expect(attempts, isEmpty); // a verified retry never writes an attempt
  });

  test(
      'pending -> rejected tombstones the completion, drops total altitude '
      'and writes an attempt with the original date/slot', () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);
    final pendingVerifier =
        FakeProofVerifier((_) => const VerifierUnavailable('offline'));
    final repo = CompletionRepository(db, clock, verifier: pendingVerifier);

    final task = await taskRepo.createTask(
      title: 'Meds',
      recurrenceType: RecurrenceType.daily,
      dueTimes: ['08:00', '20:00'],
      startDate: d(2026, 7, 1),
    );
    final result = await repo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      slot: 1,
      proof: _proof(),
    );
    final pending = (result as CompletionPendingVerification).completion;
    expect(await repo.totalAltitude(), pending.pointsAwarded);

    final retryVerifier =
        FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
    final retryRepo =
        CompletionRepository(db, clock, verifier: retryVerifier);

    final report = await retryRepo.retryPendingVerifications(
      loadBytes: (completion) async => Uint8List.fromList([9]),
    );

    expect(report.rejected, 1);

    final rows = await db.select(db.completions).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, pending.id);
    expect(rows.single.verificationStatus, VerificationStatus.rejected);
    expect(rows.single.deletedAt, isNotNull);

    final attempts = await db.select(db.verificationAttempts).get();
    expect(attempts, hasLength(1));
    expect(attempts.single.taskId, task.id);
    expect(attempts.single.occurrenceDate, d(2026, 7, 10));
    expect(attempts.single.slot, 1);

    expect(await retryRepo.totalAltitude(), 0);
  });

  test('VerifierUnavailable on retry leaves the completion pending', () async {
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
    await repo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof(),
    );

    final retryVerifier =
        FakeProofVerifier((_) => const VerifierUnavailable('still offline'));
    final retryRepo =
        CompletionRepository(db, clock, verifier: retryVerifier);

    final report = await retryRepo.retryPendingVerifications(
      loadBytes: (completion) async => Uint8List.fromList([9]),
    );

    expect(report.stillPending, 1);
    expect(report.verified, 0);
    expect(report.rejected, 0);
    expect(report.skipped, 0);

    final rows = await db.select(db.completions).get();
    expect(rows.single.verificationStatus, VerificationStatus.pending);
    expect(rows.single.deletedAt, isNull);
  });

  test('loadBytes returning null is skipped and leaves the completion pending',
      () async {
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
    await repo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof(),
    );

    final retryVerifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final retryRepo =
        CompletionRepository(db, clock, verifier: retryVerifier);

    final report = await retryRepo.retryPendingVerifications(
      loadBytes: (completion) async => null,
    );

    expect(report.skipped, 1);
    expect(retryVerifier.callCount, 0); // never reached the verifier

    final rows = await db.select(db.completions).get();
    expect(rows.single.verificationStatus, VerificationStatus.pending);
  });

  test('a pending completion dated yesterday still resolves on retry, and '
      'no new completion row is ever created', () async {
    final yesterdayClock = FixedClock(d(2026, 7, 9));
    final taskRepo = TaskRepository(db, yesterdayClock);
    final pendingVerifier =
        FakeProofVerifier((_) => const VerifierUnavailable('offline'));
    final repo =
        CompletionRepository(db, yesterdayClock, verifier: pendingVerifier);

    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );
    final result = await repo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 9),
      proof: _proof(),
    );
    final pending = (result as CompletionPendingVerification).completion;

    // A day has passed; retry now runs under "today" = 2026-07-10.
    final todayClock = FixedClock(d(2026, 7, 10));
    final retryVerifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final retryRepo =
        CompletionRepository(db, todayClock, verifier: retryVerifier);

    final report = await retryRepo.retryPendingVerifications(
      loadBytes: (completion) async => Uint8List.fromList([9]),
    );

    expect(report.verified, 1);

    final rows = await db.select(db.completions).get();
    expect(rows, hasLength(1)); // no new completion row was ever created
    expect(rows.single.id, pending.id);
    expect(rows.single.occurrenceDate, d(2026, 7, 9)); // original date kept
    expect(rows.single.verificationStatus, VerificationStatus.verified);
  });

  test('a mixed batch of pending completions produces the correct report',
      () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);
    final pendingVerifier =
        FakeProofVerifier((_) => const VerifierUnavailable('offline'));
    final setupRepo =
        CompletionRepository(db, clock, verifier: pendingVerifier);

    final taskA = await taskRepo.createTask(
        title: 'A', recurrenceType: RecurrenceType.daily, startDate: d(2026, 7, 1));
    final taskB = await taskRepo.createTask(
        title: 'B', recurrenceType: RecurrenceType.daily, startDate: d(2026, 7, 1));
    final taskC = await taskRepo.createTask(
        title: 'C', recurrenceType: RecurrenceType.daily, startDate: d(2026, 7, 1));
    final taskD = await taskRepo.createTask(
        title: 'D', recurrenceType: RecurrenceType.daily, startDate: d(2026, 7, 1));

    final rA = await setupRepo.completeWithProof(
        taskId: taskA.id, occurrenceDate: d(2026, 7, 10), proof: _proof([1]));
    final rB = await setupRepo.completeWithProof(
        taskId: taskB.id, occurrenceDate: d(2026, 7, 10), proof: _proof([2]));
    final rC = await setupRepo.completeWithProof(
        taskId: taskC.id, occurrenceDate: d(2026, 7, 10), proof: _proof([3]));
    final rD = await setupRepo.completeWithProof(
        taskId: taskD.id, occurrenceDate: d(2026, 7, 10), proof: _proof([4]));

    final completionA = (rA as CompletionPendingVerification).completion;
    final completionB = (rB as CompletionPendingVerification).completion;
    final completionC = (rC as CompletionPendingVerification).completion;
    final completionD = (rD as CompletionPendingVerification).completion;

    final retryVerifier = FakeProofVerifier((req) {
      // Route by the (single-byte) photo content this call is for: A
      // passes, B is rejected, C is still offline. (Each retry photo is a
      // one-byte marker, so `.first`, not `.length`, distinguishes them.)
      switch (req.imageBytes.first) {
        case 1:
          return const VerdictReceived(_passingVerdict);
        case 2:
          return const VerdictReceived(_rejectingVerdict);
        default:
          return const VerifierUnavailable('offline');
      }
    });
    final retryRepo =
        CompletionRepository(db, clock, verifier: retryVerifier);

    final report = await retryRepo.retryPendingVerifications(
      loadBytes: (completion) async {
        if (completion.id == completionA.id) return Uint8List.fromList([1]);
        if (completion.id == completionB.id) return Uint8List.fromList([2]);
        if (completion.id == completionC.id) return Uint8List.fromList([3]);
        if (completion.id == completionD.id) return null; // photo gone
        return null;
      },
    );

    expect(report.verified, 1);
    expect(report.rejected, 1);
    expect(report.stillPending, 1);
    expect(report.skipped, 1);
  });
}
