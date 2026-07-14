import 'dart:typed_data';

import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/proof_verdict.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

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

  group('no back-fill', () {
    test('rejects a completion for yesterday', () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final result = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 9), // yesterday
      );

      expect(result, isA<CompletionRejectedBackfill>());
      final rows = await db.select(db.completions).get();
      expect(rows, isEmpty);
    });

    test('accepts a completion for today', () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final result = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );

      expect(result, isA<CompletionRecorded>());
    });
  });

  group('unique constraint', () {
    test('double-completing the same (task, date, slot) fails gracefully',
        () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final first = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      expect(first, isA<CompletionRecorded>());

      final second = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      expect(second, isA<CompletionRejectedAlreadyCompleted>());

      final rows = await db.select(db.completions).get();
      expect(rows, hasLength(1));
    });

    test(
        'tombstoning a completion frees its slot for a new completion the '
        'same day', () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final first = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      final firstCompletion = (first as CompletionRecorded).completion;

      await completionRepo.tombstoneDelete(firstCompletion.id);

      final second = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );

      expect(second, isA<CompletionRecorded>());
      final secondCompletion = (second as CompletionRecorded).completion;
      expect(secondCompletion.id, isNot(firstCompletion.id));

      // The tombstoned row must not count toward total altitude, only the
      // new live row should.
      expect(
        await completionRepo.totalAltitude(),
        secondCompletion.pointsAwarded,
      );

      final rows = await db.select(db.completions).get();
      expect(rows, hasLength(2));
    });

    test('different slots of the same day both succeed', () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());

      final task = await taskRepo.createTask(
        title: 'Meds',
        recurrenceType: RecurrenceType.daily,
        dueTimes: ['08:00', '20:00'],
        startDate: d(2026, 7, 1),
      );

      final slot0 = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        slot: 0,
      );
      final slot1 = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        slot: 1,
      );

      expect(slot0, isA<CompletionRecorded>());
      expect(slot1, isA<CompletionRecorded>());
    });
  });

  group('not scheduled', () {
    test('rejects a slot that is not part of the task today', () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());

      final task = await taskRepo.createTask(
        title: 'Meds',
        recurrenceType: RecurrenceType.daily,
        dueTimes: ['08:00'], // only slot 0 exists
        startDate: d(2026, 7, 1),
      );

      final result = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        slot: 1,
      );

      expect(result, isA<CompletionRejectedNotScheduled>());
    });

    test('rejects a weekly task on a non-scheduled day', () async {
      final clock = FixedClock(d(2026, 7, 8)); // a Wednesday
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());

      final task = await taskRepo.createTask(
        title: 'Gym',
        recurrenceType: RecurrenceType.weekly,
        weeklyDays: [1], // Mondays only
        startDate: d(2026, 7, 1),
      );

      final result = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 8),
      );

      expect(result, isA<CompletionRejectedNotScheduled>());
    });
  });

  group('points computed at insert time', () {
    test('base + streak on the first-ever completion of a lone task', () async {
      final clock = FixedClock(d(2026, 7, 1));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final result = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 1),
      );

      final recorded = result as CompletionRecorded;
      // With only one task scheduled today, completing it is inherently the
      // day's final occurrence: base 10 + streak 1 + perfect-day 15.
      expect(recorded.completion.pointsAwarded, 26);
    });

    test('streak bonus grows day over day and caps at +10', () async {
      final taskRepo = TaskRepository(
        db,
        FixedClock(d(2026, 7, 1)),
      );
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      // Simulate completing 12 consecutive days; streak bonus should cap.
      // This is the only task scheduled, so every day is also a perfect day.
      for (var day = 1; day <= 12; day++) {
        final clock = FixedClock(d(2026, 7, day));
        final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());
        final result = await completionRepo.completeOccurrence(
          taskId: task.id,
          occurrenceDate: d(2026, 7, day),
        );
        final points = (result as CompletionRecorded).completion.pointsAwarded;
        final expectedStreakBonus = day.clamp(0, 10);
        expect(points, 10 + expectedStreakBonus + 15, reason: 'day $day');
      }
    });

    test('perfect-day bonus attaches to the final occurrence of the day',
        () async {
      final clock = FixedClock(d(2026, 7, 1));
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

      final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());

      final firstResult = await completionRepo.completeOccurrence(
        taskId: taskA.id,
        occurrenceDate: d(2026, 7, 1),
      );
      final first = (firstResult as CompletionRecorded).completion;
      expect(first.pointsAwarded, 11); // base 10 + streak 1, no bonus yet

      final secondResult = await completionRepo.completeOccurrence(
        taskId: taskB.id,
        occurrenceDate: d(2026, 7, 1),
      );
      final second = (secondResult as CompletionRecorded).completion;
      // Last remaining occurrence of the day: base 10 + streak 1 + perfect 15.
      expect(second.pointsAwarded, 26);
    });

    test('no perfect-day bonus when another task is still incomplete',
        () async {
      final clock = FixedClock(d(2026, 7, 1));
      final taskRepo = TaskRepository(db, clock);

      final taskA = await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await taskRepo.createTask(
        title: 'B',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());
      final result = await completionRepo.completeOccurrence(
        taskId: taskA.id,
        occurrenceDate: d(2026, 7, 1),
      );
      final completion = (result as CompletionRecorded).completion;
      expect(completion.pointsAwarded, 11); // no perfect-day bonus
    });
  });

  group('totalAltitude', () {
    test('sums points across non-tombstoned completions', () async {
      final clock = FixedClock(d(2026, 7, 1));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final result = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 1),
      );
      final completion = (result as CompletionRecorded).completion;

      expect(await completionRepo.totalAltitude(), completion.pointsAwarded);

      await completionRepo.tombstoneDelete(completion.id);
      expect(await completionRepo.totalAltitude(), 0);
    });
  });

  group('liveCompletionCountsByTask', () {
    test('counts each task\'s live completions, tasks with none absent',
        () async {
      final clock = FixedClock(d(2026, 7, 1));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo =
          CompletionRepository(db, clock, verifier: FakeProofVerifier());

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
      // taskC is created but never completed.
      await taskRepo.createTask(
        title: 'C',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      await completionRepo.completeOccurrence(
          taskId: taskA.id, occurrenceDate: d(2026, 7, 1));

      final counts = await completionRepo.liveCompletionCountsByTask();
      expect(counts[taskA.id], 1);
      expect(counts.containsKey(taskB.id), isFalse);
      expect(counts.containsKey('nonexistent'), isFalse);
    });

    test('tombstoned completions are excluded from the count', () async {
      final clock = FixedClock(d(2026, 7, 1));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo =
          CompletionRepository(db, clock, verifier: FakeProofVerifier());

      final task = await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final result = await completionRepo.completeOccurrence(
          taskId: task.id, occurrenceDate: d(2026, 7, 1));
      final completion = (result as CompletionRecorded).completion;
      await completionRepo.tombstoneDelete(completion.id);

      final counts = await completionRepo.liveCompletionCountsByTask();
      expect(counts.containsKey(task.id), isFalse);
    });

    test('a pending completion still counts (its stone is placed)',
        () async {
      final clock = FixedClock(d(2026, 7, 1));
      final taskRepo = TaskRepository(db, clock);
      final verifier =
          FakeProofVerifier((_) => const VerifierUnavailable('offline'));
      final completionRepo =
          CompletionRepository(db, clock, verifier: verifier);

      final task = await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final result = await completionRepo.completeWithProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 1),
        proof: _proof(),
      );
      expect(result, isA<CompletionPendingVerification>());

      final counts = await completionRepo.liveCompletionCountsByTask();
      expect(counts[task.id], 1);
    });
  });

  group('liveCompletionsForDate', () {
    test('returns only completions for the given local date', () async {
      final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
      final task = await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final repoDay1 =
          CompletionRepository(db, FixedClock(d(2026, 7, 1)), verifier: FakeProofVerifier());
      await repoDay1.completeOccurrence(
          taskId: task.id, occurrenceDate: d(2026, 7, 1));

      final repoDay2 =
          CompletionRepository(db, FixedClock(d(2026, 7, 2)), verifier: FakeProofVerifier());
      await repoDay2.completeOccurrence(
          taskId: task.id, occurrenceDate: d(2026, 7, 2));

      final day1Completions =
          await repoDay1.liveCompletionsForDate(d(2026, 7, 1));
      expect(day1Completions, hasLength(1));
      expect(day1Completions.single.occurrenceDate, d(2026, 7, 1));

      final day3Completions =
          await repoDay1.liveCompletionsForDate(d(2026, 7, 3));
      expect(day3Completions, isEmpty);
    });

    test('excludes tombstoned rows and includes pending ones', () async {
      final clock = FixedClock(d(2026, 7, 1));
      final taskRepo = TaskRepository(db, clock);
      final task = await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        dueTimes: const ['08:00', '20:00'],
        startDate: d(2026, 7, 1),
      );

      final completionRepo =
          CompletionRepository(db, clock, verifier: FakeProofVerifier());
      final result = await completionRepo.completeOccurrence(
          taskId: task.id, occurrenceDate: d(2026, 7, 1), slot: 0);
      final completion = (result as CompletionRecorded).completion;

      final pendingVerifier =
          FakeProofVerifier((_) => const VerifierUnavailable('offline'));
      final pendingRepo =
          CompletionRepository(db, clock, verifier: pendingVerifier);
      await pendingRepo.completeWithProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 1),
        slot: 1,
        proof: _proof(),
      );

      var rows = await completionRepo.liveCompletionsForDate(d(2026, 7, 1));
      expect(rows, hasLength(2));

      await completionRepo.tombstoneDelete(completion.id);
      rows = await completionRepo.liveCompletionsForDate(d(2026, 7, 1));
      expect(rows, hasLength(1));
      expect(rows.single.verificationStatus, VerificationStatus.pending);
    });
  });

  group('completionsCountForWeekOf', () {
    // 2026-07-06 is a Monday, 2026-07-12 is the following Sunday.
    test('counts completions within the Monday..Sunday week', () async {
      final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
      final task = await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 6, 1),
      );

      for (final day in [5, 6, 8, 12, 13]) {
        final clock = FixedClock(d(2026, 7, day));
        final repo =
            CompletionRepository(db, clock, verifier: FakeProofVerifier());
        await repo.completeOccurrence(
            taskId: task.id, occurrenceDate: d(2026, 7, day));
      }

      final repo = CompletionRepository(db, FixedClock(d(2026, 7, 8)),
          verifier: FakeProofVerifier());

      // Querying from any day inside the week (a Wednesday here) must return
      // the same Monday..Sunday count regardless of which day anchors it.
      expect(await repo.completionsCountForWeekOf(d(2026, 7, 6)), 3);
      expect(await repo.completionsCountForWeekOf(d(2026, 7, 8)), 3);
      expect(await repo.completionsCountForWeekOf(d(2026, 7, 12)), 3);
    });

    test('excludes tombstoned rows and includes pending ones', () async {
      final clock = FixedClock(d(2026, 7, 8));
      final taskRepo = TaskRepository(db, clock);
      final task = await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        dueTimes: const ['08:00', '20:00'],
        startDate: d(2026, 7, 1),
      );

      final completionRepo =
          CompletionRepository(db, clock, verifier: FakeProofVerifier());
      final result = await completionRepo.completeOccurrence(
          taskId: task.id, occurrenceDate: d(2026, 7, 8), slot: 0);
      final completion = (result as CompletionRecorded).completion;

      final pendingVerifier =
          FakeProofVerifier((_) => const VerifierUnavailable('offline'));
      final pendingRepo =
          CompletionRepository(db, clock, verifier: pendingVerifier);
      await pendingRepo.completeWithProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 8),
        slot: 1,
        proof: _proof(),
      );

      expect(await completionRepo.completionsCountForWeekOf(d(2026, 7, 8)), 2);

      await completionRepo.tombstoneDelete(completion.id);
      expect(await completionRepo.completionsCountForWeekOf(d(2026, 7, 8)), 1);
    });

    test('a date just outside the week boundary is excluded', () async {
      final taskRepo = TaskRepository(db, FixedClock(d(2026, 6, 1)));
      final task = await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 6, 1),
      );

      // Saturday July 4 (previous week) and Monday July 13 (next week) must
      // both be excluded from the July 6..12 week.
      for (final day in [d(2026, 7, 4), d(2026, 7, 13)]) {
        final repo = CompletionRepository(db, FixedClock(day),
            verifier: FakeProofVerifier());
        await repo.completeOccurrence(taskId: task.id, occurrenceDate: day);
      }

      final repo = CompletionRepository(db, FixedClock(d(2026, 7, 8)),
          verifier: FakeProofVerifier());
      expect(await repo.completionsCountForWeekOf(d(2026, 7, 8)), 0);
    });
  });
}
