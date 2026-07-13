import 'dart:typed_data';

import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/proof_verdict.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:drift/drift.dart' show Value;
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
  reason: 'clear photo',
);

ProofData _proof() => ProofData(imageBytes: Uint8List.fromList([1, 2, 3]));

void main() {
  late AppDatabase db;

  setUp(() {
    db = inMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('attemptsUsedToday', () {
    test('counts live verification_attempts rows for the task today',
        () async {
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

      expect(await completionRepo.attemptsUsedToday(task.id), 0);

      await completionRepo.completeWithProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );
      expect(await completionRepo.attemptsUsedToday(task.id), 1);

      await completionRepo.completeWithProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );
      expect(await completionRepo.attemptsUsedToday(task.id), 2);
    });

    test("is scoped to the task: another task's attempts don't count",
        () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final verifier =
          FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
      final completionRepo =
          CompletionRepository(db, clock, verifier: verifier);

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

      await completionRepo.completeWithProof(
        taskId: taskA.id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );

      expect(await completionRepo.attemptsUsedToday(taskA.id), 1);
      expect(await completionRepo.attemptsUsedToday(taskB.id), 0);
    });

    test("is scoped to today: a prior day's attempts don't count", () async {
      final day1Clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, day1Clock);
      final verifier =
          FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
      final day1Repo = CompletionRepository(db, day1Clock, verifier: verifier);

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      await day1Repo.completeWithProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );
      expect(await day1Repo.attemptsUsedToday(task.id), 1);

      // A repository whose Clock has moved on to the next day only sees
      // attempts recorded against *that* day.
      final day2Clock = FixedClock(d(2026, 7, 11));
      final day2Repo = CompletionRepository(db, day2Clock, verifier: verifier);
      expect(await day2Repo.attemptsUsedToday(task.id), 0);
    });

    test('a tombstoned attempt row is excluded from the count', () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo =
          CompletionRepository(db, clock, verifier: FakeProofVerifier());

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final now = clock.nowEpochMillis();
      await db.into(db.verificationAttempts).insert(
            VerificationAttemptsCompanion.insert(
              id: 'attempt-tombstoned',
              taskId: task.id,
              occurrenceDate: d(2026, 7, 10),
              attemptedAt: now,
              updatedAt: now,
              deletedAt: const Value(1),
            ),
          );

      expect(await completionRepo.attemptsUsedToday(task.id), 0);
    });
  });

  group('successfulProofsToday', () {
    test('counts verified and pending completions across all tasks',
        () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);

      final verifiedVerifier =
          FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
      final pendingVerifier =
          FakeProofVerifier((_) => const VerifierUnavailable('offline'));

      final verifiedRepo =
          CompletionRepository(db, clock, verifier: verifiedVerifier);
      final pendingRepo =
          CompletionRepository(db, clock, verifier: pendingVerifier);

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

      expect(await verifiedRepo.successfulProofsToday(), 0);

      await verifiedRepo.completeWithProof(
        taskId: taskA.id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );
      expect(await verifiedRepo.successfulProofsToday(), 1);

      await pendingRepo.completeWithProof(
        taskId: taskB.id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );
      expect(await verifiedRepo.successfulProofsToday(), 2);
    });

    test('a verifier-rejected attempt is never counted (no completion row '
        'is ever written for it)', () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final rejectingVerifier =
          FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
      final completionRepo =
          CompletionRepository(db, clock, verifier: rejectingVerifier);

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

      expect(await completionRepo.successfulProofsToday(), 0);
    });

    test(
        'a pending completion later rejected on retry is tombstoned and '
        'drops out of the count', () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final pendingVerifier =
          FakeProofVerifier((_) => const VerifierUnavailable('offline'));
      final setupRepo =
          CompletionRepository(db, clock, verifier: pendingVerifier);

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      await setupRepo.completeWithProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        proof: ProofData(
          imageBytes: Uint8List.fromList([9]),
          photoPath: '/fake/proofs/a.jpg',
        ),
      );
      expect(await setupRepo.successfulProofsToday(), 1);

      final rejectingVerifier =
          FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
      final retryRepo =
          CompletionRepository(db, clock, verifier: rejectingVerifier);
      final report = await retryRepo.retryPendingVerifications(
        loadBytes: (_) async => Uint8List.fromList([9]),
      );
      expect(report.rejected, 1);

      expect(await retryRepo.successfulProofsToday(), 0);
    });

    test('a directly tombstoned (e.g. synced-deleted) completion is '
        'excluded', () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final verifier =
          FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
      final completionRepo = CompletionRepository(db, clock, verifier: verifier);

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
      final completion = (result as CompletionRecorded).completion;
      expect(await completionRepo.successfulProofsToday(), 1);

      await completionRepo.tombstoneDelete(completion.id);
      expect(await completionRepo.successfulProofsToday(), 0);
    });

    test("is scoped to today: a prior day's proofs don't count", () async {
      final day1Clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, day1Clock);
      final verifier =
          FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
      final day1Repo = CompletionRepository(db, day1Clock, verifier: verifier);

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      await day1Repo.completeWithProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );
      expect(await day1Repo.successfulProofsToday(), 1);

      final day2Clock = FixedClock(d(2026, 7, 11));
      final day2Repo = CompletionRepository(db, day2Clock, verifier: verifier);
      expect(await day2Repo.successfulProofsToday(), 0);
    });
  });
}
