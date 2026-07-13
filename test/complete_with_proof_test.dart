import 'dart:convert';
import 'dart:typed_data';

import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/proof_verdict.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _rejectingVerdict = ProofVerdict(
  taskShown: false,
  confidence: 0.1,
  isScreenshotOrScreen: false,
  screenIsPlausibleProof: false,
  reason: 'no push-ups visible',
);

const _passingVerdict = ProofVerdict(
  taskShown: true,
  confidence: 0.95,
  isScreenshotOrScreen: false,
  screenIsPlausibleProof: false,
  reason: 'clear photo of push-ups',
);

ProofData _proof([List<int> bytes = const [1, 2, 3]]) =>
    ProofData(imageBytes: Uint8List.fromList(bytes));

void main() {
  late AppDatabase db;

  setUp(() {
    db = inMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  test('verified path persists status, meta, points and proof fields',
      () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);
    final verifier = FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final completionRepo =
        CompletionRepository(db, clock, verifier: verifier);

    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    final proof = ProofData(
      imageBytes: Uint8List.fromList([1, 2, 3]),
      photoPath: '/tmp/photo.jpg',
      source: ProofSource.camera,
      photoTakenAt: clock.nowEpochMillis(),
    );

    final result = await completionRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: proof,
    );

    expect(result, isA<CompletionRecorded>());
    final completion = (result as CompletionRecorded).completion;
    expect(completion.verificationStatus, VerificationStatus.verified);
    expect(completion.verificationMeta, isNotNull);
    final meta = jsonDecode(completion.verificationMeta!) as Map;
    expect(meta['task_shown'], true);
    expect(meta['reason'], 'clear photo of push-ups');
    expect(completion.proofPhotoPath, '/tmp/photo.jpg');
    expect(completion.proofSource, ProofSource.camera);
    expect(completion.photoTakenAt, proof.photoTakenAt);
    // Only task scheduled today: base 10 + streak 1 + perfect-day 15.
    expect(completion.pointsAwarded, 26);
  });

  test(
      'rejected path writes an attempt row and no completion, reporting '
      'attemptsRemaining 2', () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
    final completionRepo =
        CompletionRepository(db, clock, verifier: verifier);

    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    final result = await completionRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof(),
    );

    expect(result, isA<CompletionRejectedByVerifier>());
    final rejected = result as CompletionRejectedByVerifier;
    expect(rejected.verdict, _rejectingVerdict);
    expect(rejected.attemptsRemaining, 2);

    final completions = await db.select(db.completions).get();
    expect(completions, isEmpty);

    final attempts = await db.select(db.verificationAttempts).get();
    expect(attempts, hasLength(1));
    expect(attempts.single.taskId, task.id);
    expect(attempts.single.occurrenceDate, d(2026, 7, 10));
    expect(attempts.single.slot, 0);
  });

  test('pending path (VerifierUnavailable) persists status pending with points',
      () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);
    final verifier =
        FakeProofVerifier((_) => const VerifierUnavailable('offline'));
    final completionRepo =
        CompletionRepository(db, clock, verifier: verifier);

    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    final result = await completionRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof(),
    );

    expect(result, isA<CompletionPendingVerification>());
    final completion = (result as CompletionPendingVerification).completion;
    expect(completion.verificationStatus, VerificationStatus.pending);
    expect(completion.verificationMeta, isNull);
    expect(completion.pointsAwarded, 26); // same points rule as verified
  });

  test(
      'after 3 rejections the 4th call returns attempts-exhausted without '
      'calling the verifier again', () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
    final completionRepo =
        CompletionRepository(db, clock, verifier: verifier);

    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    for (var i = 0; i < 3; i++) {
      final result = await completionRepo.completeWithProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );
      expect(result, isA<CompletionRejectedByVerifier>());
    }
    expect(verifier.callCount, 3);

    final fourth = await completionRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof(),
    );

    expect(fourth, isA<CompletionRejectedAttemptsExhausted>());
    expect(verifier.callCount, 3); // short-circuited before the verifier
  });

  test('the attempts cap is shared across two slots of the same task',
      () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
    final completionRepo =
        CompletionRepository(db, clock, verifier: verifier);

    final task = await taskRepo.createTask(
      title: 'Meds',
      recurrenceType: RecurrenceType.daily,
      dueTimes: ['08:00', '20:00'],
      startDate: d(2026, 7, 1),
    );

    await completionRepo.completeWithProof(
        taskId: task.id, occurrenceDate: d(2026, 7, 10), slot: 0, proof: _proof());
    await completionRepo.completeWithProof(
        taskId: task.id, occurrenceDate: d(2026, 7, 10), slot: 0, proof: _proof());
    await completionRepo.completeWithProof(
        taskId: task.id, occurrenceDate: d(2026, 7, 10), slot: 1, proof: _proof());
    expect(verifier.callCount, 3);

    final fourth = await completionRepo.completeWithProof(
        taskId: task.id, occurrenceDate: d(2026, 7, 10), slot: 1, proof: _proof());

    expect(fourth, isA<CompletionRejectedAttemptsExhausted>());
    expect(verifier.callCount, 3);
  });

  test('rejections do not burn the daily cap', () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);

    final taskA = await taskRepo.createTask(
      title: 'A',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    final rejectingVerifier =
        FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
    final rejectingRepo =
        CompletionRepository(db, clock, verifier: rejectingVerifier);
    for (var i = 0; i < 3; i++) {
      final r = await rejectingRepo.completeWithProof(
        taskId: taskA.id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );
      expect(r, isA<CompletionRejectedByVerifier>());
    }

    final passingVerifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final passingRepo =
        CompletionRepository(db, clock, verifier: passingVerifier);
    for (var i = 0; i < 5; i++) {
      final t = await taskRepo.createTask(
        title: 'T$i',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final r = await passingRepo.completeWithProof(
        taskId: t.id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );
      expect(r, isA<CompletionRecorded>(), reason: 'completion $i');
    }
  });

  test('after 5 successful completions the 6th hits the daily cap', () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);

    final tasks = <Task>[];
    for (var i = 0; i < 6; i++) {
      tasks.add(await taskRepo.createTask(
        title: 'T$i',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      ));
    }

    final verifyingVerifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final verifiedRepo =
        CompletionRepository(db, clock, verifier: verifyingVerifier);
    for (var i = 0; i < 3; i++) {
      final r = await verifiedRepo.completeWithProof(
        taskId: tasks[i].id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );
      expect(r, isA<CompletionRecorded>());
    }

    final pendingVerifier =
        FakeProofVerifier((_) => const VerifierUnavailable('offline'));
    final pendingRepo =
        CompletionRepository(db, clock, verifier: pendingVerifier);
    for (var i = 3; i < 5; i++) {
      final r = await pendingRepo.completeWithProof(
        taskId: tasks[i].id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );
      expect(r, isA<CompletionPendingVerification>());
    }

    final callCountBefore = verifyingVerifier.callCount;
    final sixth = await verifiedRepo.completeWithProof(
      taskId: tasks[5].id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof(),
    );

    expect(sixth, isA<CompletionRejectedDailyCapReached>());
    expect(verifyingVerifier.callCount, callCountBefore); // short-circuited
  });

  test(
      'backfill, not-scheduled, task-not-found and already-completed all '
      'short-circuit before the verifier is called', () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final completionRepo =
        CompletionRepository(db, clock, verifier: verifier);

    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      dueTimes: ['08:00'], // only slot 0 exists
      startDate: d(2026, 7, 1),
    );

    final backfill = await completionRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 9),
      proof: _proof(),
    );
    expect(backfill, isA<CompletionRejectedBackfill>());
    expect(verifier.callCount, 0);

    final notScheduled = await completionRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      slot: 1,
      proof: _proof(),
    );
    expect(notScheduled, isA<CompletionRejectedNotScheduled>());
    expect(verifier.callCount, 0);

    final notFound = await completionRepo.completeWithProof(
      taskId: 'nonexistent-task',
      occurrenceDate: d(2026, 7, 10),
      proof: _proof(),
    );
    expect(notFound, isA<CompletionRejectedTaskNotFound>());
    expect(verifier.callCount, 0);

    final first = await completionRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof(),
    );
    expect(first, isA<CompletionRecorded>());
    expect(verifier.callCount, 1);

    final alreadyCompleted = await completionRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof(),
    );
    expect(alreadyCompleted, isA<CompletionRejectedAlreadyCompleted>());
    expect(verifier.callCount, 1); // unchanged: guard short-circuited
  });

  test('a pending completion counts toward the perfect-day bonus', () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);

    final taskA = await taskRepo.createTask(
      title: 'A',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );
    final taskB = await taskRepo.createTask(
      title: 'B',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    final pendingVerifier =
        FakeProofVerifier((_) => const VerifierUnavailable('offline'));
    final pendingRepo =
        CompletionRepository(db, clock, verifier: pendingVerifier);
    final firstResult = await pendingRepo.completeWithProof(
      taskId: taskA.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof(),
    );
    expect(firstResult, isA<CompletionPendingVerification>());
    final first = (firstResult as CompletionPendingVerification).completion;
    // taskB is still incomplete, so no perfect-day bonus yet.
    expect(first.pointsAwarded, 11);

    final verifiedVerifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final verifiedRepo =
        CompletionRepository(db, clock, verifier: verifiedVerifier);
    final secondResult = await verifiedRepo.completeWithProof(
      taskId: taskB.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof(),
    );
    expect(secondResult, isA<CompletionRecorded>());
    final second = (secondResult as CompletionRecorded).completion;
    // The pending completion on taskA counts as done, so this is the day's
    // final scheduled occurrence: base 10 + streak 1 + perfect-day 15.
    expect(second.pointsAwarded, 26);
  });
}
