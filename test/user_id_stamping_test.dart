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

ProofData _proof([List<int> bytes = const [1, 2, 3]]) =>
    ProofData(imageBytes: Uint8List.fromList(bytes));

void main() {
  late AppDatabase db;
  final clock = FixedClock(d(2026, 7, 10));

  setUp(() {
    db = inMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('WO-4: user_id stamping at insert time', () {
    test('createTask carries the current user id when one is available',
        () async {
      final taskRepo =
          TaskRepository(db, clock, currentUserId: () => 'user-1');

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      expect(task.userId, 'user-1');
    });

    test('createTask leaves user_id NULL when no user id is available',
        () async {
      final taskRepo = TaskRepository(db, clock);

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      expect(task.userId, isNull);
    });

    test(
        'completeOccurrence (Phase 1 debug path) stamps user_id when '
        'available', () async {
      final taskRepo =
          TaskRepository(db, clock, currentUserId: () => 'user-1');
      final completionRepo = CompletionRepository(
        db,
        clock,
        verifier: FakeProofVerifier(),
        currentUserId: () => 'user-1',
      );

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final result = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );

      final completion = (result as CompletionRecorded).completion;
      expect(completion.userId, 'user-1');
    });

    test('completeOccurrence leaves user_id NULL when no user id is available',
        () async {
      final taskRepo = TaskRepository(db, clock);
      final completionRepo =
          CompletionRepository(db, clock, verifier: FakeProofVerifier());

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final result = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );

      final completion = (result as CompletionRecorded).completion;
      expect(completion.userId, isNull);
    });

    test('completeWithProof (verified) stamps user_id on the completion',
        () async {
      final taskRepo = TaskRepository(db, clock);
      final verifier =
          FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
      final completionRepo = CompletionRepository(
        db,
        clock,
        verifier: verifier,
        currentUserId: () => 'user-1',
      );

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
      expect(completion.userId, 'user-1');
    });

    test('completeWithProof (pending) stamps user_id on the completion',
        () async {
      final taskRepo = TaskRepository(db, clock);
      final verifier =
          FakeProofVerifier((_) => const VerifierUnavailable('offline'));
      final completionRepo = CompletionRepository(
        db,
        clock,
        verifier: verifier,
        currentUserId: () => 'user-1',
      );

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

      final completion = (result as CompletionPendingVerification).completion;
      expect(completion.userId, 'user-1');
    });

    test(
        'a rejected proof stamps user_id on the verification_attempts row',
        () async {
      final taskRepo = TaskRepository(db, clock);
      final verifier =
          FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
      final completionRepo = CompletionRepository(
        db,
        clock,
        verifier: verifier,
        currentUserId: () => 'user-1',
      );

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      await completionRepo.completeWithProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );

      final attempts = await db.select(db.verificationAttempts).get();
      expect(attempts, hasLength(1));
      expect(attempts.single.userId, 'user-1');
    });

    test('a rejection on retry stamps user_id on its attempt row', () async {
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
        proof: _proof(),
      );

      final retryVerifier =
          FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
      final retryRepo = CompletionRepository(
        db,
        clock,
        verifier: retryVerifier,
        currentUserId: () => 'user-2',
      );

      await retryRepo.retryPendingVerifications(
        loadBytes: (_) async => Uint8List.fromList([9]),
      );

      final attempts = await db.select(db.verificationAttempts).get();
      expect(attempts, hasLength(1));
      expect(attempts.single.userId, 'user-2');
    });
  });

  group('WO-4: backfillUserId is idempotent and never overwrites', () {
    test('TaskRepository.backfillUserId stamps every NULL row', () async {
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
      expect(taskA.userId, isNull);
      expect(taskB.userId, isNull);

      final updated = await taskRepo.backfillUserId('user-1');
      expect(updated, 2);

      final reloaded = await db.select(db.tasks).get();
      expect(reloaded.map((t) => t.userId), everyElement('user-1'));
    });

    test(
        'TaskRepository.backfillUserId does not overwrite a row that already '
        'has a (different) user_id', () async {
      final taskRepo =
          TaskRepository(db, clock, currentUserId: () => 'user-existing');
      final existing = await taskRepo.createTask(
        title: 'Has a user already',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final nullRepo = TaskRepository(db, clock);
      final blank = await nullRepo.createTask(
        title: 'No user yet',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      await taskRepo.backfillUserId('user-new');

      final reloadedExisting =
          await (db.select(db.tasks)..where((t) => t.id.equals(existing.id)))
              .getSingle();
      final reloadedBlank =
          await (db.select(db.tasks)..where((t) => t.id.equals(blank.id)))
              .getSingle();
      expect(reloadedExisting.userId, 'user-existing'); // untouched
      expect(reloadedBlank.userId, 'user-new'); // backfilled
    });

    test('TaskRepository.backfillUserId is idempotent: running it twice '
        'changes nothing further', () async {
      final taskRepo = TaskRepository(db, clock);
      await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final first = await taskRepo.backfillUserId('user-1');
      expect(first, 1);

      final second = await taskRepo.backfillUserId('user-1');
      expect(second, 0); // nothing left matching user_id IS NULL

      final rows = await db.select(db.tasks).get();
      expect(rows.single.userId, 'user-1');
    });

    test(
        'CompletionRepository.backfillUserId stamps completions and '
        'verification_attempts, but never overwrites an existing user_id',
        () async {
      final taskRepo = TaskRepository(db, clock);
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      // One completion with no user id (pre-auth), one already stamped.
      final verifier =
          FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
      final blankRepo =
          CompletionRepository(db, clock, verifier: verifier);
      final blankResult = await blankRepo.completeWithProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        slot: 0,
        proof: _proof([1]),
      );
      final blankCompletion = (blankResult as CompletionRecorded).completion;

      final now = clock.nowEpochMillis();
      await db.into(db.verificationAttempts).insert(
            VerificationAttemptsCompanion.insert(
              id: 'attempt-existing',
              taskId: task.id,
              occurrenceDate: d(2026, 7, 10),
              attemptedAt: now,
              userId: const Value('user-existing'),
              updatedAt: now,
            ),
          );
      await db.into(db.verificationAttempts).insert(
            VerificationAttemptsCompanion.insert(
              id: 'attempt-blank',
              taskId: task.id,
              occurrenceDate: d(2026, 7, 10),
              attemptedAt: now,
              updatedAt: now,
            ),
          );

      final repo = CompletionRepository(db, clock, verifier: verifier);
      final updatedCount = await repo.backfillUserId('user-new');
      expect(updatedCount, 1); // one completion row backfilled

      final reloadedCompletion = await (db.select(db.completions)
            ..where((c) => c.id.equals(blankCompletion.id)))
          .getSingle();
      expect(reloadedCompletion.userId, 'user-new');

      final attempts = await db.select(db.verificationAttempts).get();
      final existingAttempt =
          attempts.singleWhere((a) => a.id == 'attempt-existing');
      final blankAttempt =
          attempts.singleWhere((a) => a.id == 'attempt-blank');
      expect(existingAttempt.userId, 'user-existing'); // untouched
      expect(blankAttempt.userId, 'user-new'); // backfilled

      // Idempotent: a second call matches nothing further.
      final second = await repo.backfillUserId('user-new');
      expect(second, 0);
    });
  });
}
