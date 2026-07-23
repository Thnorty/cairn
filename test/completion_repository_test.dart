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

const _passingVerdict = ProofVerdict(
  taskShown: true,
  confidence: 0.95,
  isScreenshotOrScreen: false,
  reason: 'clear photo',
);

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
        // Day 10 is this lone task's 10th live stone, so it also caps the
        // cairn (+25), on top of base/streak/perfect-day.
        final expectedCapBonus = day == 10 ? 25 : 0;
        expect(points, 10 + expectedStreakBonus + 15 + expectedCapBonus,
            reason: 'day $day');
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

  group('cairn cap bonus', () {
    test(
        'the 10th live stone of a task earns the +25 cairn cap bonus; the '
        '9th and 11th do not', () async {
      final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final pointsByDay = <int, int>{};
      for (var day = 1; day <= 11; day++) {
        final repo = CompletionRepository(db, FixedClock(d(2026, 7, day)),
            verifier: FakeProofVerifier());
        final result = await repo.completeOccurrence(
          taskId: task.id,
          occurrenceDate: d(2026, 7, day),
        );
        pointsByDay[day] =
            (result as CompletionRecorded).completion.pointsAwarded;
      }

      // This lone task makes every day its own perfect day too: base 10 +
      // streak bonus (day, capped at 10) + perfect-day 15, plus +25 only on
      // the stone that fills the cairn to 10.
      expect(pointsByDay[9], 10 + 9 + 15); // 34, no cap bonus yet
      expect(pointsByDay[10], 10 + 10 + 15 + 25); // 60, caps the cairn
      expect(pointsByDay[11], 10 + 10 + 15); // 35, a fresh cairn just started
    });

    test(
        'a streak break resets the count: the cap bonus is earned within '
        'the current run, not by lifetime completion total', () async {
      final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      Future<int> complete(int day) async {
        final repo = CompletionRepository(db, FixedClock(d(2026, 7, day)),
            verifier: FakeProofVerifier());
        final result = await repo.completeOccurrence(
          taskId: task.id,
          occurrenceDate: d(2026, 7, day),
        );
        return (result as CompletionRecorded).completion.pointsAwarded;
      }

      // Run 1: 9 stones (days 1-9). Day 10 is left incomplete entirely (a
      // break once elapsed). Run 2 then needs its own 10 stones to cap,
      // even though its 10th stone (day 20) is only the task's 19th
      // completion ever - proving the cap is per-run, not lifetime.
      for (final day in [1, 2, 3, 4, 5, 6, 7, 8, 9]) {
        await complete(day);
      }

      int? pointsDay19;
      int? pointsDay20;
      for (final day in [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]) {
        final points = await complete(day);
        if (day == 19) pointsDay19 = points;
        if (day == 20) pointsDay20 = points;
      }

      // Day 19 is run 2's 9th stone: streak 9, no cap bonus.
      expect(pointsDay19, 10 + 9 + 15);
      // Day 20 is run 2's 10th stone: streak 10, plus the +25 cap bonus.
      expect(pointsDay20, 10 + 10 + 15 + 25);

      final rows = await (db.select(db.completions)
            ..where((c) => c.taskId.equals(task.id)))
          .get();
      // Lifetime total is 19, not a multiple of 10: the bonus could only
      // have come from counting within run 2, not the lifetime total.
      expect(rows, hasLength(19));
    });

    test(
        'a pending 10th stone stores the cap bonus but withholds it from '
        'totalAltitude until verified, then it counts', () async {
      final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      for (var day = 1; day <= 9; day++) {
        final repo = CompletionRepository(db, FixedClock(d(2026, 7, day)),
            verifier: FakeProofVerifier());
        await repo.completeOccurrence(
            taskId: task.id, occurrenceDate: d(2026, 7, day));
      }

      final baselineRepo = CompletionRepository(
          db, FixedClock(d(2026, 7, 9)),
          verifier: FakeProofVerifier());
      final baseline = await baselineRepo.totalAltitude();
      // Sum over days 1..9 of (10 base + day streak + 15 perfect-day), none
      // of which cap the cairn yet.
      expect(baseline, 270);

      final day10Clock = FixedClock(d(2026, 7, 10));
      final pendingVerifier =
          FakeProofVerifier((_) => const VerifierUnavailable('offline'));
      final pendingRepo =
          CompletionRepository(db, day10Clock, verifier: pendingVerifier);
      final result = await pendingRepo.completeWithProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );
      final pending = (result as CompletionPendingVerification).completion;

      // The 10th stone caps the cairn: base 10 + streak 10 + perfect-day 15
      // + cairn cap 25 = 60, stored on the row even while it's pending.
      expect(pending.pointsAwarded, 60);
      // But withheld from altitude until the verdict lands.
      expect(await pendingRepo.totalAltitude(), baseline);

      final passingVerifier =
          FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
      final retryRepo =
          CompletionRepository(db, day10Clock, verifier: passingVerifier);
      final report = await retryRepo.retryPendingVerifications(
        loadBytes: (completion) async => Uint8List.fromList([9]),
      );
      expect(report.verified, 1);

      // Once verified, the same stored points (including the cap bonus)
      // start counting, unrecomputed.
      expect(
        await retryRepo.totalAltitude(),
        baseline + pending.pointsAwarded,
      );
    });
  });

  group('liveCompletionsGroupedByTask', () {
    test('groups each task\'s live completions by taskId, tasks with none '
        'absent', () async {
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

      final grouped = await completionRepo.liveCompletionsGroupedByTask();
      expect(grouped[taskA.id], hasLength(1));
      expect(grouped[taskA.id]!.single.taskId, taskA.id);
      expect(grouped.containsKey(taskB.id), isFalse);
      expect(grouped.containsKey('nonexistent'), isFalse);
    });

    test('tombstoned completions are excluded from the grouping', () async {
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

      final grouped = await completionRepo.liveCompletionsGroupedByTask();
      expect(grouped.containsKey(task.id), isFalse);
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

      final grouped = await completionRepo.liveCompletionsGroupedByTask();
      expect(grouped[task.id], hasLength(1));
    });
  });

  group('currentCairnFor', () {
    test('a brand-new task with no live completions is (1, 0)', () async {
      final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
      final completionRepo = CompletionRepository(db, FixedClock(d(2026, 7, 1)),
          verifier: FakeProofVerifier());
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final cairn = await completionRepo.currentCairnFor(task.id);
      expect(cairn.index, 1);
      expect(cairn.stoneCount, 0);
    });

    test('a missing/tombstoned task id also returns (1, 0)', () async {
      final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
      final completionRepo = CompletionRepository(db, FixedClock(d(2026, 7, 1)),
          verifier: FakeProofVerifier());
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await taskRepo.tombstoneDelete(task.id);

      expect((await completionRepo.currentCairnFor('nonexistent')).index, 1);
      expect(
          (await completionRepo.currentCairnFor('nonexistent')).stoneCount, 0);
      final tombstoned = await completionRepo.currentCairnFor(task.id);
      expect(tombstoned.index, 1);
      expect(tombstoned.stoneCount, 0);
    });

    test('reflects the in-progress growing cairn mid-stack', () async {
      final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      for (var day = 1; day <= 4; day++) {
        final repo = CompletionRepository(db, FixedClock(d(2026, 7, day)),
            verifier: FakeProofVerifier());
        await repo.completeOccurrence(
            taskId: task.id, occurrenceDate: d(2026, 7, day));
      }

      final repo = CompletionRepository(db, FixedClock(d(2026, 7, 4)),
          verifier: FakeProofVerifier());
      final cairn = await repo.currentCairnFor(task.id);
      expect(cairn.index, 1);
      expect(cairn.stoneCount, 4);
    });

    test(
        'right after the 10th stone caps the cairn, returns the just-capped '
        'cairn (index, 10), not the fresh empty one', () async {
      final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      for (var day = 1; day <= 10; day++) {
        final repo = CompletionRepository(db, FixedClock(d(2026, 7, day)),
            verifier: FakeProofVerifier());
        await repo.completeOccurrence(
            taskId: task.id, occurrenceDate: d(2026, 7, day));
      }

      final repo = CompletionRepository(db, FixedClock(d(2026, 7, 10)),
          verifier: FakeProofVerifier());
      final cairn = await repo.currentCairnFor(task.id);
      expect(cairn.index, 1);
      expect(cairn.stoneCount, 10);
    });

    test('reflects a broken streak\'s last settled cairn', () async {
      final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      for (var day = 1; day <= 3; day++) {
        final repo = CompletionRepository(db, FixedClock(d(2026, 7, day)),
            verifier: FakeProofVerifier());
        await repo.completeOccurrence(
            taskId: task.id, occurrenceDate: d(2026, 7, day));
      }

      // Jul 4 elapsed and incomplete: the streak is broken as of Jul 5.
      final repo = CompletionRepository(db, FixedClock(d(2026, 7, 5)),
          verifier: FakeProofVerifier());
      final cairn = await repo.currentCairnFor(task.id);
      expect(cairn.index, 1);
      expect(cairn.stoneCount, 3);
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

  group('localTrailSummary', () {
    test('zero stones and a null lastClimb with no completions at all',
        () async {
      final clock = FixedClock(d(2026, 7, 10));
      final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());

      final summary = await completionRepo.localTrailSummary();

      expect(summary.stones, 0);
      expect(summary.lastClimbAt, isNull);
    });

    test('counts live completions (verified and pending alike) and reports '
        'the latest timestamp', () async {
      final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final clockDay8 = FixedClock(d(2026, 7, 8));
      final verifiedRepo = CompletionRepository(
        db,
        clockDay8,
        verifier: FakeProofVerifier(),
      );
      await verifiedRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 8),
      );

      final clockDay10 = FixedClock(d(2026, 7, 10));
      final pendingRepo = CompletionRepository(
        db,
        clockDay10,
        verifier: FakeProofVerifier(
          (_) => const VerifierUnavailable('offline'),
        ),
      );
      await pendingRepo.completeWithProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        proof: _proof(),
      );

      final summary = await verifiedRepo.localTrailSummary();
      expect(summary.stones, 2);
      expect(
        summary.lastClimbAt,
        DateTime.fromMillisecondsSinceEpoch(clockDay10.nowEpochMillis()),
      );
    });

    test('a tombstoned completion is excluded from both the count and the '
        'latest-date calculation', () async {
      final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final clockDay8 = FixedClock(d(2026, 7, 8));
      final repoDay8 = CompletionRepository(
        db,
        clockDay8,
        verifier: FakeProofVerifier(),
      );
      await repoDay8.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 8),
      );

      final repoDay10 = CompletionRepository(
        db,
        FixedClock(d(2026, 7, 10)),
        verifier: FakeProofVerifier(),
      );
      final result = await repoDay10.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      final day10Completion = (result as CompletionRecorded).completion;
      await repoDay10.tombstoneDelete(day10Completion.id);

      final summary = await repoDay10.localTrailSummary();
      expect(summary.stones, 1);
      expect(
        summary.lastClimbAt,
        DateTime.fromMillisecondsSinceEpoch(clockDay8.nowEpochMillis()),
      );
    });
  });
}
