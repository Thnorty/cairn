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
  reason: 'no evidence',
);

const _passingVerdict = ProofVerdict(
  taskShown: true,
  confidence: 0.95,
  isScreenshotOrScreen: false,
  reason: 'looks right',
);

ProofData _proof() => ProofData(imageBytes: Uint8List.fromList([1, 2, 3]));

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late TaskRepository taskRepo;

  setUp(() {
    db = inMemoryDatabase();
    clock = FixedClock(d(2026, 7, 10));
    taskRepo = TaskRepository(db, clock);
  });

  tearDown(() async {
    await db.close();
  });

  /// Asserts [body] neither inserts nor tombstones a completions or
  /// verification_attempts row: precheckProof must never write anything, on
  /// any path.
  Future<void> expectNoWrites(Future<void> Function() body) async {
    final completionsBefore = await db.select(db.completions).get();
    final attemptsBefore = await db.select(db.verificationAttempts).get();

    await body();

    final completionsAfter = await db.select(db.completions).get();
    final attemptsAfter = await db.select(db.verificationAttempts).get();
    expect(completionsAfter, completionsBefore);
    expect(attemptsAfter, attemptsBefore);
  }

  test('returns null on a clean, scheduled occurrence', () async {
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final repo = CompletionRepository(db, clock, verifier: verifier);
    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    CompleteOccurrenceResult? result;
    await expectNoWrites(() async {
      result = await repo.precheckProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
    });

    expect(result, isNull);
    expect(verifier.callCount, 0);
  });

  test('returns CompletionRejectedBackfill for a past date', () async {
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final repo = CompletionRepository(db, clock, verifier: verifier);
    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    CompleteOccurrenceResult? result;
    await expectNoWrites(() async {
      result = await repo.precheckProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 9),
      );
    });

    expect(result, isA<CompletionRejectedBackfill>());
  });

  test('returns CompletionRejectedNotScheduled for a slot not due today',
      () async {
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final repo = CompletionRepository(db, clock, verifier: verifier);
    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      dueTimes: ['08:00'], // only slot 0 exists
      startDate: d(2026, 7, 1),
    );

    CompleteOccurrenceResult? result;
    await expectNoWrites(() async {
      result = await repo.precheckProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        slot: 1,
      );
    });

    expect(result, isA<CompletionRejectedNotScheduled>());
  });

  test('returns CompletionRejectedTaskNotFound for an unknown task',
      () async {
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final repo = CompletionRepository(db, clock, verifier: verifier);

    CompleteOccurrenceResult? result;
    await expectNoWrites(() async {
      result = await repo.precheckProof(
        taskId: 'nonexistent-task',
        occurrenceDate: d(2026, 7, 10),
      );
    });

    expect(result, isA<CompletionRejectedTaskNotFound>());
  });

  test('returns CompletionRejectedAlreadyCompleted once the slot is done',
      () async {
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final repo = CompletionRepository(db, clock, verifier: verifier);
    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    final first =
        await repo.completeWithProof(taskId: task.id, occurrenceDate: d(2026, 7, 10), proof: _proof());
    expect(first, isA<CompletionRecorded>());

    CompleteOccurrenceResult? result;
    await expectNoWrites(() async {
      result = await repo.precheckProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
    });

    expect(result, isA<CompletionRejectedAlreadyCompleted>());
  });

  test('returns CompletionRejectedAttemptsExhausted once 3 attempts are '
      'burned', () async {
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
    final repo = CompletionRepository(db, clock, verifier: verifier);
    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    for (var i = 0; i < 3; i++) {
      final r = await repo.completeWithProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );
      expect(r, isA<CompletionRejectedByVerifier>());
    }

    CompleteOccurrenceResult? result;
    await expectNoWrites(() async {
      result = await repo.precheckProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
    });

    expect(result, isA<CompletionRejectedAttemptsExhausted>());
  });

  test('returns CompletionRejectedDailyCapReached once 5 completions exist '
      'across tasks', () async {
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final repo = CompletionRepository(db, clock, verifier: verifier);

    for (var i = 0; i < 5; i++) {
      final t = await taskRepo.createTask(
        title: 'T$i',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final r = await repo.completeWithProof(
        taskId: t.id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );
      expect(r, isA<CompletionRecorded>());
    }

    final sixthTask = await taskRepo.createTask(
      title: 'T-sixth',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    CompleteOccurrenceResult? result;
    await expectNoWrites(() async {
      result = await repo.precheckProof(
        taskId: sixthTask.id,
        occurrenceDate: d(2026, 7, 10),
      );
    });

    expect(result, isA<CompletionRejectedDailyCapReached>());
  });
}
