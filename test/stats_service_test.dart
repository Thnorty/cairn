import 'dart:typed_data';

import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/proof_verdict.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/occurrence_generator.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/services/stats_service.dart';
import 'package:cairn/src/services/streak_service.dart';
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

  StatsService buildService(Clock clock, {ProofPolicy policy = const ProofPolicy()}) {
    return StatsService(
      db,
      TaskRepository(db, clock),
      CompletionRepository(db, clock, verifier: FakeProofVerifier(), policy: policy),
      const OccurrenceGenerator(),
      const StreakService(),
      clock,
      policy: policy,
    );
  }

  group('all-empty case', () {
    test('a fresh database reports zero/empty everything', () async {
      final service = buildService(FixedClock(d(2026, 7, 20)));

      final snapshot = await service.buildSnapshot();

      expect(snapshot.stonesPlaced, 0);
      expect(snapshot.cairnsBuilt, 0);
      expect(snapshot.proofsUsedToday, 0);
      expect(snapshot.dailyCap, const ProofPolicy().dailyCap);
      expect(snapshot.week, hasLength(7));
      expect(snapshot.weekDone, 0);
      expect(snapshot.weekTotal, 0);
      expect(snapshot.streaks, isEmpty);
    });
  });

  group('stonesPlaced', () {
    test(
        'counts live completions across tasks (verified and pending alike) '
        'and excludes tombstoned ones', () async {
      final clock = FixedClock(d(2026, 7, 20));
      final taskRepo = TaskRepository(db, clock);
      final offlineVerifier = FakeProofVerifier((_) => const VerifierUnavailable('offline'));
      final taskA = await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        dueTimes: const ['08:00', '20:00'],
        startDate: d(2026, 7, 1),
      );
      final taskB = await taskRepo.createTask(
        title: 'B',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      // Two verified completions on task A's two slots today.
      final verifiedRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());
      final firstResult = await verifiedRepo.completeOccurrence(
        taskId: taskA.id,
        occurrenceDate: d(2026, 7, 20),
        slot: 0,
      );
      await verifiedRepo.completeOccurrence(
        taskId: taskA.id,
        occurrenceDate: d(2026, 7, 20),
        slot: 1,
      );

      // One pending completion on task B today (offline verifier).
      final pendingRepo = CompletionRepository(db, clock, verifier: offlineVerifier);
      await pendingRepo.completeWithProof(
        taskId: taskB.id,
        occurrenceDate: d(2026, 7, 20),
        proof: ProofData(imageBytes: Uint8List.fromList([1, 2, 3])),
      );

      final service = buildService(clock);
      expect((await service.buildSnapshot()).stonesPlaced, 3);

      // Tombstoning one completion drops the total.
      final firstCompletion = (firstResult as CompletionRecorded).completion;
      await verifiedRepo.tombstoneDelete(firstCompletion.id);
      expect((await service.buildSnapshot()).stonesPlaced, 2);
    });
  });

  group('cairnsBuilt', () {
    test(
        'counts only capped cairns, not growing or broken ones', () async {
      final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
      final cappedTask = await taskRepo.createTask(
        title: 'Capped task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final growingTask = await taskRepo.createTask(
        title: 'Growing task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      // 10 consecutive days caps the first cairn (PointsService.cairnCapStones).
      for (var day = 1; day <= 10; day++) {
        await CompletionRepository(db, FixedClock(d(2026, 7, day)), verifier: FakeProofVerifier())
            .completeOccurrence(taskId: cappedTask.id, occurrenceDate: d(2026, 7, day));
      }
      // Only 5 days: this task's single cairn is still growing, never capped.
      for (var day = 1; day <= 5; day++) {
        await CompletionRepository(db, FixedClock(d(2026, 7, day)), verifier: FakeProofVerifier())
            .completeOccurrence(taskId: growingTask.id, occurrenceDate: d(2026, 7, day));
      }

      final service = buildService(FixedClock(d(2026, 7, 20)));
      final snapshot = await service.buildSnapshot();

      expect(snapshot.cairnsBuilt, 1);
    });

    test(
        'includes an ARCHIVED task\'s capped cairn - same population as '
        'stonesPlaced, so an archived task\'s already-placed stones never '
        'vanish from either count', () async {
      final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
      final archivedTask = await taskRepo.createTask(
        title: 'Archived task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      // 10 consecutive days caps the first cairn, then archive the task.
      for (var day = 1; day <= 10; day++) {
        await CompletionRepository(db, FixedClock(d(2026, 7, day)), verifier: FakeProofVerifier())
            .completeOccurrence(taskId: archivedTask.id, occurrenceDate: d(2026, 7, day));
      }
      await taskRepo.archiveTask(archivedTask.id);

      final service = buildService(FixedClock(d(2026, 7, 20)));
      final snapshot = await service.buildSnapshot();

      expect(snapshot.cairnsBuilt, 1);
      expect(snapshot.stonesPlaced, 10);
    });
  });

  group('proofsUsedToday / dailyCap', () {
    test('matches the repository\'s own daily counter and the policy\'s cap',
        () async {
      final clock = FixedClock(d(2026, 7, 20));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());
      final task = await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        dueTimes: const ['08:00', '20:00'],
        startDate: d(2026, 7, 1),
      );
      await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 20),
        slot: 0,
      );

      const customPolicy = ProofPolicy(dailyCap: 3);
      final service = buildService(clock, policy: customPolicy);
      final snapshot = await service.buildSnapshot();

      expect(snapshot.proofsUsedToday, await completionRepo.successfulProofsToday());
      expect(snapshot.proofsUsedToday, 1);
      expect(snapshot.dailyCap, 3);
    });
  });

  group('week bars', () {
    test(
        'scheduled/done/isFuture per weekday and the week totals reflect a '
        'real Monday..Sunday week', () async {
      final baseClock = FixedClock(d(2026, 7, 20));
      final weekStart = d(2026, 7, 20).addDays(-(d(2026, 7, 20).weekday - 1));
      final today = weekStart.addDays(3);

      final taskRepo = TaskRepository(db, baseClock);
      final task = await taskRepo.createTask(
        title: 'Daily habit',
        recurrenceType: RecurrenceType.daily,
        startDate: weekStart,
      );

      // Completed on day offsets 0, 1 and 3 (today); day 2 is left
      // deliberately incomplete, days 4-6 are still in the future.
      for (final offset in [0, 1, 3]) {
        final date = weekStart.addDays(offset);
        await CompletionRepository(db, FixedClock(date), verifier: FakeProofVerifier())
            .completeOccurrence(taskId: task.id, occurrenceDate: date);
      }

      final service = buildService(FixedClock(today));
      final snapshot = await service.buildSnapshot();

      expect(snapshot.week, hasLength(7));
      expect(snapshot.week.first.date, weekStart);
      expect(snapshot.week.last.date, weekStart.addDays(6));

      final expectedDone = [true, true, false, true, false, false, false];
      for (var i = 0; i < 7; i++) {
        final bar = snapshot.week[i];
        expect(bar.date, weekStart.addDays(i), reason: 'day $i date');
        expect(bar.scheduled, 1, reason: 'day $i scheduled');
        expect(bar.done, expectedDone[i] ? 1 : 0, reason: 'day $i done');
        expect(bar.isFuture, i > 3, reason: 'day $i isFuture');
      }

      expect(snapshot.weekTotal, 7);
      expect(snapshot.weekDone, 3);
    });
  });

  group('streaks', () {
    test(
        'only active tasks with a live streak of at least one day are '
        'included, ordered by cairn number (creation order)', () async {
      final clock = FixedClock(d(2026, 7, 20));

      final taskRepo = TaskRepository(db, clock);
      final taskA = await taskRepo.createTask(
        title: 'A (short streak)',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final laterRepo1 = TaskRepository(
        db,
        FixedClock(d(2026, 7, 20), nowMillis: clock.nowEpochMillis() + 1000),
      );
      final taskB = await laterRepo1.createTask(
        title: 'B (no streak)',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final laterRepo2 = TaskRepository(
        db,
        FixedClock(d(2026, 7, 20), nowMillis: clock.nowEpochMillis() + 2000),
      );
      final taskC = await laterRepo2.createTask(
        title: 'C (longer streak)',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      // Task A: completed only today - a streak of 1.
      await CompletionRepository(db, clock, verifier: FakeProofVerifier())
          .completeOccurrence(taskId: taskA.id, occurrenceDate: d(2026, 7, 20));

      // Task B: no completions at all - no streak.

      // Task C: completed for 4 consecutive days ending today.
      for (var day = 17; day <= 20; day++) {
        await CompletionRepository(db, FixedClock(d(2026, 7, day)), verifier: FakeProofVerifier())
            .completeOccurrence(taskId: taskC.id, occurrenceDate: d(2026, 7, day));
      }

      final service = buildService(clock);
      final snapshot = await service.buildSnapshot();

      expect(snapshot.streaks, hasLength(2));
      expect(snapshot.streaks[0].taskTitle, 'A (short streak)');
      expect(snapshot.streaks[0].days, 1);
      expect(snapshot.streaks[1].taskTitle, 'C (longer streak)');
      expect(snapshot.streaks[1].days, 4);
      expect(
        snapshot.streaks.any((s) => s.taskTitle.contains('B')),
        isFalse,
      );
      // Sanity: taskB is unused beyond seeding the "no streak" case.
      expect(taskB.title, 'B (no streak)');
    });
  });

  group('watchStats', () {
    test('emits an updated snapshot when a completion is recorded elsewhere',
        () async {
      final clock = FixedClock(d(2026, 7, 20));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final service = buildService(clock);
      final snapshots = <StatsSnapshot>[];
      final subscription = service.watchStats().listen(snapshots.add);
      addTearDown(subscription.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(snapshots, isNotEmpty);
      expect(snapshots.last.stonesPlaced, 0);

      await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 20),
      );
      await Future<void>.delayed(Duration.zero);

      expect(snapshots.last.stonesPlaced, 1);
    });
  });
}
