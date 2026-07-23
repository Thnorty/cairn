import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fake_sync_transport.dart';

const _cursorKey = 'sync_pull_cursor';

void main() {
  group('replaceLocalWithCloud', () {
    test('hard-deletes local-only data (never pushing it) and adopts the '
        "account's cloud data, resetting the cursor to match it", () async {
      final transport = FakeSyncTransport();

      // The account's existing cloud data, as if pushed earlier from another
      // device.
      final dbCloud = inMemoryDatabase();
      final cloudClock = FixedClock(d(2026, 7, 10), nowMillis: 1000);
      final taskRepoCloud = TaskRepository(dbCloud, cloudClock);
      final completionRepoCloud =
          CompletionRepository(dbCloud, cloudClock, verifier: FakeProofVerifier());
      final taskX = await taskRepoCloud.createTask(
        title: 'Cloud task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await completionRepoCloud.completeOccurrence(
        taskId: taskX.id,
        occurrenceDate: d(2026, 7, 10),
      );
      await SyncService(dbCloud, transport).syncOnce();

      // This device's own local, never-synced (anonymous, pre-upgrade) data.
      final dbA = inMemoryDatabase();
      final deviceClock = FixedClock(d(2026, 7, 10), nowMillis: 1500);
      final taskRepoA = TaskRepository(dbA, deviceClock);
      final completionRepoA =
          CompletionRepository(dbA, deviceClock, verifier: FakeProofVerifier());
      final taskY = await taskRepoA.createTask(
        title: 'Local-only task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await completionRepoA.completeOccurrence(
        taskId: taskY.id,
        occurrenceDate: d(2026, 7, 10),
      );

      final syncA = SyncService(dbA, transport);
      final result = await syncA.replaceLocalWithCloud();
      expect(result.isFullSuccess, isTrue);

      final tasksAfter = await dbA.select(dbA.tasks).get();
      expect(tasksAfter.map((t) => t.id).toSet(), {taskX.id});

      final completionsAfter = await dbA.select(dbA.completions).get();
      expect(completionsAfter.map((c) => c.taskId).toSet(), {taskX.id});

      // The local-only task/completion were hard-deleted before any push, so
      // the account's cloud data must never have seen them at all.
      expect(transport.taskById(taskY.id), isNull);

      final cursorRow = await (dbA.select(dbA.appSettings)
            ..where((s) => s.key.equals(_cursorKey)))
          .getSingleOrNull();
      expect(cursorRow, isNotNull);
      expect(int.parse(cursorRow!.value), greaterThanOrEqualTo(1000));

      await dbCloud.close();
      await dbA.close();
    });

    test('an empty cloud leaves local empty too', () async {
      final transport = FakeSyncTransport();
      final dbA = inMemoryDatabase();
      final deviceClock = FixedClock(d(2026, 7, 10), nowMillis: 1000);
      final taskRepoA = TaskRepository(dbA, deviceClock);
      await taskRepoA.createTask(
        title: 'Local-only task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final result = await SyncService(dbA, transport).replaceLocalWithCloud();
      expect(result.isFullSuccess, isTrue);

      final tasksAfter = await dbA.select(dbA.tasks).get();
      expect(tasksAfter, isEmpty);

      await dbA.close();
    });
  });

  group('replaceCloudWithLocal', () {
    test(
        'a non-empty cloud: its prior rows are tombstoned, this device\'s '
        'rows are pushed, and the final live sets match', () async {
      final transport = FakeSyncTransport();

      // The account's existing cloud data (from another device, already
      // synced).
      final dbOther = inMemoryDatabase();
      final cloudClock = FixedClock(d(2026, 7, 10), nowMillis: 1000);
      final taskRepoOther = TaskRepository(dbOther, cloudClock);
      final completionRepoOther = CompletionRepository(
        dbOther,
        cloudClock,
        verifier: FakeProofVerifier(),
      );
      final taskX = await taskRepoOther.createTask(
        title: 'Cloud task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await completionRepoOther.completeOccurrence(
        taskId: taskX.id,
        occurrenceDate: d(2026, 7, 10),
      );
      await SyncService(dbOther, transport).syncOnce();

      // This device's own local data, not yet synced.
      final dbA = inMemoryDatabase();
      final deviceClock = FixedClock(d(2026, 7, 10), nowMillis: 1500);
      final taskRepoA = TaskRepository(dbA, deviceClock);
      final completionRepoA =
          CompletionRepository(dbA, deviceClock, verifier: FakeProofVerifier());
      final taskY = await taskRepoA.createTask(
        title: 'This device\'s task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await completionRepoA.completeOccurrence(
        taskId: taskY.id,
        occurrenceDate: d(2026, 7, 10),
      );

      final opClock = FixedClock(d(2026, 7, 10), nowMillis: 9000);
      final syncA = SyncService(dbA, transport, clock: opClock);
      final result = await syncA.replaceCloudWithLocal();
      expect(result.isFullSuccess, isTrue);

      // Locally: taskX now exists, tombstoned, freshly stamped and already
      // pushed (dirty cleared); taskY stays live, dirty cleared too.
      final localTaskX = await (dbA.select(dbA.tasks)
            ..where((t) => t.id.equals(taskX.id)))
          .getSingle();
      expect(localTaskX.deletedAt, 9000);
      expect(localTaskX.dirty, isFalse);

      final localTaskY = await (dbA.select(dbA.tasks)
            ..where((t) => t.id.equals(taskY.id)))
          .getSingle();
      expect(localTaskY.deletedAt, isNull);
      expect(localTaskY.dirty, isFalse);
      expect(localTaskY.updatedAt, 9000);

      // Cloud: taskX tombstoned, taskY live.
      expect(transport.taskById(taskX.id)!.deletedAt, isNotNull);
      expect(transport.taskById(taskY.id)!.deletedAt, isNull);

      final localCompletionForX = await (dbA.select(dbA.completions)
            ..where((c) => c.taskId.equals(taskX.id)))
          .getSingle();
      expect(localCompletionForX.deletedAt, isNotNull);
      expect(
        transport.completionById(localCompletionForX.id)!.deletedAt,
        isNotNull,
      );

      final localCompletionForY = await (dbA.select(dbA.completions)
            ..where((c) => c.taskId.equals(taskY.id)))
          .getSingle();
      expect(localCompletionForY.deletedAt, isNull);
      expect(
        transport.completionById(localCompletionForY.id)!.deletedAt,
        isNull,
      );

      // Final postcondition: live cloud task set == live local task set.
      final finalPull = await transport.pull(cursor: 0);
      final cloudLiveTaskIds = finalPull.tasks
          .where((t) => t.deletedAt == null)
          .map((t) => t.id)
          .toSet();
      final localLiveTaskIds = (await (dbA.select(dbA.tasks)
                ..where((t) => t.deletedAt.isNull()))
              .get())
          .map((t) => t.id)
          .toSet();
      expect(cloudLiveTaskIds, localLiveTaskIds);
      expect(cloudLiveTaskIds, {taskY.id});

      await dbOther.close();
      await dbA.close();
    });

    test('an empty cloud: nothing is tombstoned, only local rows are pushed',
        () async {
      final transport = FakeSyncTransport();

      final dbA = inMemoryDatabase();
      final deviceClock = FixedClock(d(2026, 7, 10), nowMillis: 1000);
      final taskRepoA = TaskRepository(dbA, deviceClock);
      final completionRepoA =
          CompletionRepository(dbA, deviceClock, verifier: FakeProofVerifier());
      final taskY = await taskRepoA.createTask(
        title: 'This device\'s task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await completionRepoA.completeOccurrence(
        taskId: taskY.id,
        occurrenceDate: d(2026, 7, 10),
      );

      final opClock = FixedClock(d(2026, 7, 10), nowMillis: 5000);
      final result =
          await SyncService(dbA, transport, clock: opClock).replaceCloudWithLocal();
      expect(result.isFullSuccess, isTrue);

      expect(transport.taskById(taskY.id), isNotNull);
      expect(transport.taskById(taskY.id)!.deletedAt, isNull);

      final localTaskY = await (dbA.select(dbA.tasks)
            ..where((t) => t.id.equals(taskY.id)))
          .getSingle();
      expect(localTaskY.dirty, isFalse);

      final finalPull = await transport.pull(cursor: 0);
      expect(finalPull.tasks.where((t) => t.deletedAt != null), isEmpty);

      await dbA.close();
    });
  });

  group('remoteTrailSummary', () {
    test('reduces the account\'s live completions, ignoring tombstoned ones',
        () async {
      final transport = FakeSyncTransport();
      final dbCloud = inMemoryDatabase();
      final clock = FixedClock(d(2026, 7, 10), nowMillis: 1000);
      final taskRepo = TaskRepository(dbCloud, clock);
      final completionRepo =
          CompletionRepository(dbCloud, clock, verifier: FakeProofVerifier());

      final task = await taskRepo.createTask(
        title: 'Task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      await SyncService(dbCloud, transport).syncOnce();

      final summary = await SyncService(dbCloud, transport).remoteTrailSummary();
      expect(summary.stones, 1);
      expect(
        summary.lastClimbAt,
        DateTime.fromMillisecondsSinceEpoch(1000),
      );

      await dbCloud.close();
    });

    test('an empty account has zero stones and a null lastClimb', () async {
      final transport = FakeSyncTransport();
      final db = inMemoryDatabase();

      final summary = await SyncService(db, transport).remoteTrailSummary();
      expect(summary.stones, 0);
      expect(summary.lastClimbAt, isNull);

      await db.close();
    });
  });
}
