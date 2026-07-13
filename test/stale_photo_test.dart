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
  reason: 'no evidence',
);

ProofData _proof({int? photoTakenAt}) => ProofData(
      imageBytes: Uint8List.fromList([1, 2, 3]),
      photoTakenAt: photoTakenAt,
    );

void main() {
  late AppDatabase db;

  setUp(() {
    db = inMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  test(
      'a stale photo is rejected without reaching the verifier or writing '
      'any row, and does not burn the attempts budget', () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
    final completionRepo = CompletionRepository(db, clock, verifier: verifier);

    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    final now = clock.nowEpochMillis();
    final staleAt = now - const Duration(minutes: 16).inMilliseconds;

    final staleResult = await completionRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof(photoTakenAt: staleAt),
    );

    expect(staleResult, isA<CompletionRejectedStalePhoto>());
    expect(verifier.callCount, 0);

    final completionsAfterStale = await db.select(db.completions).get();
    expect(completionsAfterStale, isEmpty);
    final attemptsAfterStale =
        await db.select(db.verificationAttempts).get();
    expect(attemptsAfterStale, isEmpty);

    // If the stale rejection had burned any of the attempts budget, fewer
    // than 3 more rejections would be needed to exhaust it. Exactly 3 more
    // (with a recent photo, so they reach the verifier) are required, which
    // proves the stale call above cost nothing against the cap.
    for (var i = 0; i < 3; i++) {
      final r = await completionRepo.completeWithProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(photoTakenAt: now),
      );
      expect(r, isA<CompletionRejectedByVerifier>());
    }
    expect(verifier.callCount, 3);

    final fourth = await completionRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof(photoTakenAt: now),
    );
    expect(fourth, isA<CompletionRejectedAttemptsExhausted>());
    expect(verifier.callCount, 3); // unchanged: short-circuited before it
  });

  test('a photo inside the recency window passes the guard and reaches the '
      'verifier', () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
    final completionRepo = CompletionRepository(db, clock, verifier: verifier);

    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    final now = clock.nowEpochMillis();
    final result = await completionRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: _proof(photoTakenAt: now),
    );

    expect(result, isNot(isA<CompletionRejectedStalePhoto>()));
    expect(verifier.callCount, 1);
  });

  test('a null photoTakenAt passes under the default policy', () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
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

    expect(result, isNot(isA<CompletionRejectedStalePhoto>()));
    expect(verifier.callCount, 1);
  });
}
