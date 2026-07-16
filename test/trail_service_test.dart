import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/cairn_grouping.dart';
import 'package:cairn/src/services/points_service.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/services/trail_service.dart';
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

  TrailService buildService(Clock clock) {
    return TrailService(
      db,
      TaskRepository(db, clock),
      CompletionRepository(db, clock, verifier: FakeProofVerifier()),
      const PointsService(),
      clock,
    );
  }

  group('no active tasks', () {
    test('chips are empty and selection/cairns/altitude are all empty/zero',
        () async {
      final service = buildService(FixedClock(d(2026, 7, 20)));

      final snapshot = await service.buildSnapshot();

      expect(snapshot.chips, isEmpty);
      expect(snapshot.selectedTaskId, isNull);
      expect(snapshot.selectedTaskTitle, isNull);
      expect(snapshot.cairns, isEmpty);
      expect(snapshot.altitude, 0);
      expect(snapshot.rank.tier, RankTier.pebble);
    });
  });

  group('chips and selection', () {
    test('chips are ordered by cairn number (task creation order)', () async {
      // Distinct createdAt per task (see this file's own FixedClock(d(...),
      // nowMillis: ...) precedent): the same FixedClock instance always
      // returns the same nowEpochMillis(), so two createTask calls on one
      // clock tie on created_at and cairnNumbers()' ordering (createdAt
      // only) falls back to whatever order the database happens to return
      // ties in - nondeterministic, not the creation order this test
      // asserts. Advancing the clock between creates removes the tie.
      final clock = FixedClock(d(2026, 7, 20));
      final taskRepo = TaskRepository(db, clock);
      final taskA = await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final laterTaskRepo = TaskRepository(
        db,
        FixedClock(d(2026, 7, 20), nowMillis: clock.nowEpochMillis() + 1000),
      );
      final taskB = await laterTaskRepo.createTask(
        title: 'B',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final service = buildService(clock);
      final snapshot = await service.buildSnapshot();

      expect(snapshot.chips, hasLength(2));
      expect(snapshot.chips[0].taskId, taskA.id);
      expect(snapshot.chips[0].title, 'A');
      expect(snapshot.chips[1].taskId, taskB.id);
      expect(snapshot.chips[1].title, 'B');
    });

    test('with no selectedTaskId, defaults to the first task by cairn number',
        () async {
      // Distinct createdAt per task - see the identical rationale in
      // 'chips are ordered by cairn number' above.
      final clock = FixedClock(d(2026, 7, 20));
      final taskRepo = TaskRepository(db, clock);
      final taskA = await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final laterTaskRepo = TaskRepository(
        db,
        FixedClock(d(2026, 7, 20), nowMillis: clock.nowEpochMillis() + 1000),
      );
      await laterTaskRepo.createTask(
        title: 'B',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final service = buildService(clock);
      final snapshot = await service.buildSnapshot();

      expect(snapshot.selectedTaskId, taskA.id);
      expect(snapshot.selectedTaskTitle, 'A');
    });

    test('an explicit selectedTaskId naming an active task wins', () async {
      final clock = FixedClock(d(2026, 7, 20));
      final taskRepo = TaskRepository(db, clock);
      await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final taskB = await taskRepo.createTask(
        title: 'B',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final service = buildService(clock);
      final snapshot = await service.buildSnapshot(selectedTaskId: taskB.id);

      expect(snapshot.selectedTaskId, taskB.id);
      expect(snapshot.selectedTaskTitle, 'B');
    });

    test(
        'a selectedTaskId that no longer names an active task falls back to '
        'the first task', () async {
      final clock = FixedClock(d(2026, 7, 20));
      final taskRepo = TaskRepository(db, clock);
      final taskA = await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final service = buildService(clock);
      final snapshot =
          await service.buildSnapshot(selectedTaskId: 'not-a-real-task-id');

      expect(snapshot.selectedTaskId, taskA.id);
    });
  });

  group('cairns for the selected task; altitude/rank are global', () {
    test(
        'a history spanning a capped cairn, a broken cairn and a growing '
        'cairn renders all three, and altitude/rank match the repository\'s '
        'app-wide total (not scoped to the selected task)', () async {
      final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
      final task = await taskRepo.createTask(
        title: 'Read 20 pages',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      // Days 1-10: fills and caps the trailhead cairn (10 stones).
      // Day 11: missed (elapsed, incomplete) -> seals cairn 1 as capped and
      // opens cairn 2.
      // Days 12-14: 3 stones into cairn 2.
      // Day 15: missed -> seals cairn 2 as broken and opens cairn 3.
      // Days 16-19: 4 stones into cairn 3, still growing as of day 20 (today
      // itself is not yet elapsed, so it never breaks the streak).
      final stoneDays = [
        for (var day = 1; day <= 10; day++) day,
        for (var day = 12; day <= 14; day++) day,
        for (var day = 16; day <= 19; day++) day,
      ];
      for (final day in stoneDays) {
        final repo = CompletionRepository(db, FixedClock(d(2026, 7, day)),
            verifier: FakeProofVerifier());
        final result = await repo.completeOccurrence(
          taskId: task.id,
          occurrenceDate: d(2026, 7, day),
        );
        expect(result, isA<CompletionRecorded>());
      }

      final today = FixedClock(d(2026, 7, 20));
      final completionRepo =
          CompletionRepository(db, today, verifier: FakeProofVerifier());
      final service = buildService(today);
      final snapshot = await service.buildSnapshot(selectedTaskId: task.id);

      expect(snapshot.cairns, hasLength(3));

      final cairn1 = snapshot.cairns[0];
      expect(cairn1.index, 1);
      expect(cairn1.isTrailhead, isTrue);
      expect(cairn1.stoneCount, 10);
      expect(cairn1.status, CairnStatus.capped);

      final cairn2 = snapshot.cairns[1];
      expect(cairn2.index, 2);
      expect(cairn2.isTrailhead, isFalse);
      expect(cairn2.stoneCount, 3);
      expect(cairn2.status, CairnStatus.broken);

      final cairn3 = snapshot.cairns[2];
      expect(cairn3.index, 3);
      expect(cairn3.isTrailhead, isFalse);
      expect(cairn3.stoneCount, 4);
      expect(cairn3.status, CairnStatus.growing);

      final expectedAltitude = await completionRepo.totalAltitude();
      expect(snapshot.altitude, expectedAltitude);
      expect(snapshot.altitude, greaterThan(0));
      expect(snapshot.rank.tier, const PointsService().rankFor(expectedAltitude).tier);
    });

    test('a task with no completions yet has empty cairns and zero altitude',
        () async {
      final clock = FixedClock(d(2026, 7, 20));
      final taskRepo = TaskRepository(db, clock);
      final task = await taskRepo.createTask(
        title: 'Brand new habit',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final service = buildService(clock);
      final snapshot = await service.buildSnapshot(selectedTaskId: task.id);

      expect(snapshot.cairns, isEmpty);
      expect(snapshot.altitude, 0);
      expect(snapshot.rank.tier, RankTier.pebble);
    });

    test(
        'altitude/rank reflect every task\'s verified metres, and do not '
        'change when a different chip is selected', () async {
      final clock = FixedClock(d(2026, 7, 20));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo =
          CompletionRepository(db, clock, verifier: FakeProofVerifier());
      final taskA = await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final laterTaskRepo = TaskRepository(
        db,
        FixedClock(d(2026, 7, 20), nowMillis: clock.nowEpochMillis() + 1000),
      );
      final taskB = await laterTaskRepo.createTask(
        title: 'B',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      // Only task A ever gets a completion; task B has none of its own.
      final result = await completionRepo.completeOccurrence(
        taskId: taskA.id,
        occurrenceDate: d(2026, 7, 20),
      );
      expect(result, isA<CompletionRecorded>());

      final service = buildService(clock);
      final snapshotOnA =
          await service.buildSnapshot(selectedTaskId: taskA.id);
      final snapshotOnB =
          await service.buildSnapshot(selectedTaskId: taskB.id);

      final expectedAltitude = await completionRepo.totalAltitude();
      expect(expectedAltitude, greaterThan(0));
      // Same altitude/rank regardless of which chip is selected: task B's
      // own history is empty, yet its snapshot still reports task A's
      // metres, because the pill is app-wide, not per-task.
      expect(snapshotOnA.altitude, expectedAltitude);
      expect(snapshotOnB.altitude, expectedAltitude);
      expect(snapshotOnB.rank.tier, snapshotOnA.rank.tier);
      // The cairn history itself does still differ per selected task.
      expect(snapshotOnA.cairns, isNotEmpty);
      expect(snapshotOnB.cairns, isEmpty);
    });
  });

  group('watchTrail', () {
    test('emits an updated snapshot when a completion is recorded elsewhere',
        () async {
      final clock = FixedClock(d(2026, 7, 20));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo =
          CompletionRepository(db, clock, verifier: FakeProofVerifier());
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final service = buildService(clock);
      final snapshots = <TrailSnapshot>[];
      final subscription = service
          .watchTrail(selectedTaskId: task.id)
          .listen(snapshots.add);
      addTearDown(subscription.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(snapshots, isNotEmpty);
      expect(snapshots.last.cairns, isEmpty);

      await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 20),
      );
      await Future<void>.delayed(Duration.zero);

      expect(snapshots.last.cairns, isNotEmpty);
      expect(snapshots.last.altitude, greaterThan(0));
    });
  });
}
