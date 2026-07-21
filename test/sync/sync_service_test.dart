import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/local_date.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/sync/sync_service.dart';
import 'package:cairn/src/sync/sync_transport.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fake_sync_transport.dart';

const _cursorKey = 'sync_pull_cursor';

/// Mutable clock for driving exact `updatedAt`/`today()` values across a
/// multi-client sync scenario: [FixedClock] pins a single instant for its
/// whole lifetime, which isn't enough control here (these tests need to
/// advance "now" between repository calls on the same client, and pin
/// precise, independently-controlled instants across two clients sharing one
/// [FakeSyncTransport] "server").
class _TestClock implements Clock {
  final LocalDate _date;
  int _millis;

  _TestClock(this._date, this._millis);

  @override
  LocalDate today() => _date;

  @override
  int nowEpochMillis() => _millis;

  void setMillis(int millis) => _millis = millis;
}

/// Directly-constructed Task row for tests that need exact control over
/// `id`/`updatedAt`/`dirty`/`deletedAt` (bypassing the repository, the same
/// direct-row-construction style `test/cairn_grouping_test.dart`'s `stone()`
/// helper uses) - needed to set up LWW/collision scenarios where the
/// timestamp relationship between two rows is the whole point of the test.
Task _task({
  required String id,
  String title = 'Task',
  required int updatedAt,
  bool dirty = true,
  int? deletedAt,
}) {
  return Task(
    id: id,
    title: title,
    recurrenceType: RecurrenceType.daily,
    dueTimes: const [],
    startDate: d(2026, 7, 1),
    archived: false,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
    dirty: dirty,
  );
}

void main() {
  group('dirty lifecycle and push/pull', () {
    test(
        'a locally-created task is dirty, pushes on sync, and a second '
        'client pulls it', () async {
      final transport = FakeSyncTransport();

      final dbA = inMemoryDatabase();
      final clockA = _TestClock(d(2026, 7, 10), 1000);
      final taskRepoA = TaskRepository(dbA, clockA);
      final syncA = SyncService(dbA, transport);

      final task = await taskRepoA.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      expect(task.dirty, isTrue);

      final resultA = await syncA.syncOnce();
      expect(resultA.isFullSuccess, isTrue);

      final afterPush = await (dbA.select(dbA.tasks)
            ..where((t) => t.id.equals(task.id)))
          .getSingle();
      expect(afterPush.dirty, isFalse);
      expect(transport.taskById(task.id), isNotNull);

      final dbB = inMemoryDatabase();
      final syncB = SyncService(dbB, transport);

      final resultB = await syncB.syncOnce();
      expect(resultB.isFullSuccess, isTrue);

      final pulled = await (dbB.select(dbB.tasks)
            ..where((t) => t.id.equals(task.id)))
          .getSingleOrNull();
      expect(pulled, isNotNull);
      expect(pulled!.title, 'Push-ups');
      expect(pulled.dirty, isFalse);

      await dbA.close();
      await dbB.close();
    });

    test('a row edited after a push stays dirty and is re-pushed next sync',
        () async {
      final transport = FakeSyncTransport();
      final db = inMemoryDatabase();
      final clock = _TestClock(d(2026, 7, 10), 1000);
      final taskRepo = TaskRepository(db, clock);
      final sync = SyncService(db, transport);

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await sync.syncOnce();
      var row = await (db.select(db.tasks)..where((t) => t.id.equals(task.id)))
          .getSingle();
      expect(row.dirty, isFalse);

      clock.setMillis(1500);
      await taskRepo.editTask(
        task.id,
        const TasksCompanion(title: Value('Sit-ups')),
      );
      row = await (db.select(db.tasks)..where((t) => t.id.equals(task.id)))
          .getSingle();
      expect(row.dirty, isTrue);
      expect(transport.taskById(task.id)!.title, 'Push-ups'); // not pushed yet

      await sync.syncOnce();
      row = await (db.select(db.tasks)..where((t) => t.id.equals(task.id)))
          .getSingle();
      expect(row.dirty, isFalse);
      expect(transport.taskById(task.id)!.title, 'Sit-ups');
      expect(transport.taskById(task.id)!.updatedAt, 1500);

      await db.close();
    });

    test('cursor advances and an immediate re-sync pulls nothing new',
        () async {
      final transport = FakeSyncTransport();

      final dbA = inMemoryDatabase();
      final clockA = _TestClock(d(2026, 7, 10), 1000);
      final taskRepoA = TaskRepository(dbA, clockA);
      final syncA = SyncService(dbA, transport);
      await taskRepoA.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await syncA.syncOnce();

      final dbB = inMemoryDatabase();
      final syncB = SyncService(dbB, transport);
      await syncB.syncOnce(); // pulls the one task, cursor -> 1000

      final pushCallsAfterFirst = transport.pushCallCount;
      final resultSecond = await syncB.syncOnce();
      expect(resultSecond.isFullSuccess, isTrue);
      // Nothing dirty locally, so the empty-batch short-circuit means no
      // push call was made at all.
      expect(transport.pushCallCount, pushCallsAfterFirst);

      final rows = await dbB.select(dbB.tasks).get();
      expect(rows, hasLength(1));

      final cursorRow = await (dbB.select(dbB.appSettings)
            ..where((s) => s.key.equals(_cursorKey)))
          .getSingleOrNull();
      expect(cursorRow, isNotNull);
      expect(int.parse(cursorRow!.value), 1000);

      await dbA.close();
      await dbB.close();
    });
  });

  group('last-write-wins', () {
    test('remote row with a newer updatedAt wins over an older local row',
        () async {
      final transport = FakeSyncTransport();

      final dbA = inMemoryDatabase();
      final clockA = _TestClock(d(2026, 7, 10), 1000);
      final taskRepoA = TaskRepository(dbA, clockA);
      final syncA = SyncService(dbA, transport);
      final task = await taskRepoA.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await syncA.syncOnce(); // push @1000

      final dbB = inMemoryDatabase();
      final syncB = SyncService(dbB, transport);
      await syncB.syncOnce(); // pull @1000

      clockA.setMillis(2000);
      await taskRepoA.editTask(
        task.id,
        const TasksCompanion(title: Value('Sit-ups')),
      );
      await syncA.syncOnce(); // push edit @2000

      final resultB = await syncB.syncOnce(); // pull the newer edit
      expect(resultB.isFullSuccess, isTrue);

      final bTask = await (dbB.select(dbB.tasks)
            ..where((t) => t.id.equals(task.id)))
          .getSingle();
      expect(bTask.title, 'Sit-ups');
      expect(bTask.dirty, isFalse);

      await dbA.close();
      await dbB.close();
    });

    test(
        'a local row with a newer updatedAt is not overwritten by an older '
        'remote row on pull, and stays dirty', () async {
      final transport = FakeSyncTransport();
      final db = inMemoryDatabase();
      final sync = SyncService(db, transport);
      const taskId = 'shared-task';

      await transport.push(SyncPushBatch(
        tasks: [_task(id: taskId, title: 'Remote title', updatedAt: 1000)],
      ));
      await db.into(db.tasks).insert(
            _task(id: taskId, title: 'Local title', updatedAt: 2000),
          );

      // Isolate the pull-apply step's effect on `dirty` from the push
      // phase's own dirty-clearing (which would otherwise also clear dirty
      // later in the same syncOnce call, muddying what this test is
      // actually proving).
      transport.failNextPush = true;
      final result = await sync.syncOnce();
      expect(result.pulled, isTrue);
      expect(result.pushed, isFalse);

      final local = await (db.select(db.tasks)..where((t) => t.id.equals(taskId)))
          .getSingle();
      expect(local.title, 'Local title');
      expect(local.dirty, isTrue);

      await db.close();
    });
  });

  group('tombstone propagation', () {
    test('deleting on one client syncs the tombstone to the other', () async {
      final transport = FakeSyncTransport();

      final dbA = inMemoryDatabase();
      final clockA = _TestClock(d(2026, 7, 10), 1000);
      final taskRepoA = TaskRepository(dbA, clockA);
      final syncA = SyncService(dbA, transport);
      final task = await taskRepoA.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await syncA.syncOnce();

      final dbB = inMemoryDatabase();
      final syncB = SyncService(dbB, transport);
      await syncB.syncOnce();

      var bTask = await (dbB.select(dbB.tasks)
            ..where((t) => t.id.equals(task.id)))
          .getSingleOrNull();
      expect(bTask, isNotNull);
      expect(bTask!.deletedAt, isNull);

      clockA.setMillis(2000);
      await taskRepoA.tombstoneDelete(task.id);
      await syncA.syncOnce();

      await syncB.syncOnce();
      bTask = await (dbB.select(dbB.tasks)..where((t) => t.id.equals(task.id)))
          .getSingle();
      expect(bTask.deletedAt, isNotNull);
      expect(bTask.dirty, isFalse);

      await dbA.close();
      await dbB.close();
    });
  });

  group('offline / transport failure', () {
    test('a push failure leaves dirty untouched, and a later sync succeeds',
        () async {
      final transport = FakeSyncTransport();
      final db = inMemoryDatabase();
      final clock = _TestClock(d(2026, 7, 10), 1000);
      final taskRepo = TaskRepository(db, clock);
      final sync = SyncService(db, transport);

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      transport.failNextPush = true;
      final failed = await sync.syncOnce();
      expect(failed.pulled, isTrue);
      expect(failed.pushed, isFalse);
      expect(failed.error, isNotNull);

      var row = await (db.select(db.tasks)..where((t) => t.id.equals(task.id)))
          .getSingle();
      expect(row.dirty, isTrue);
      expect(transport.taskById(task.id), isNull);

      final ok = await sync.syncOnce();
      expect(ok.isFullSuccess, isTrue);
      row = await (db.select(db.tasks)..where((t) => t.id.equals(task.id)))
          .getSingle();
      expect(row.dirty, isFalse);
      expect(transport.taskById(task.id), isNotNull);

      await db.close();
    });

    test(
        'a pull failure leaves the cursor and every row untouched, and a '
        'later sync succeeds', () async {
      final transport = FakeSyncTransport();

      final dbA = inMemoryDatabase();
      final clockA = _TestClock(d(2026, 7, 10), 1000);
      final taskRepoA = TaskRepository(dbA, clockA);
      final syncA = SyncService(dbA, transport);
      await taskRepoA.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await syncA.syncOnce(); // seed the transport

      final dbB = inMemoryDatabase();
      final syncB = SyncService(dbB, transport);

      transport.failNextPull = true;
      final failed = await syncB.syncOnce();
      expect(failed.pulled, isFalse);
      expect(failed.pushed, isFalse);
      expect(failed.error, isNotNull);

      final rows = await dbB.select(dbB.tasks).get();
      expect(rows, isEmpty);
      final cursorRow = await (dbB.select(dbB.appSettings)
            ..where((s) => s.key.equals(_cursorKey)))
          .getSingleOrNull();
      expect(cursorRow, isNull);

      final ok = await syncB.syncOnce();
      expect(ok.isFullSuccess, isTrue);
      final rowsAfter = await dbB.select(dbB.tasks).get();
      expect(rowsAfter, hasLength(1));

      await dbA.close();
      await dbB.close();
    });
  });

  group('same-occurrence, different-id collision', () {
    test(
        'a newer incoming remote completion wins: the older local row is '
        'tombstoned in place (dirty) and the remote becomes the live row',
        () async {
      final transport = FakeSyncTransport();

      final dbA = inMemoryDatabase();
      final clockA = _TestClock(d(2026, 7, 10), 1000);
      final taskRepoA = TaskRepository(dbA, clockA);
      final completionRepoA =
          CompletionRepository(dbA, clockA, verifier: FakeProofVerifier());
      final syncA = SyncService(dbA, transport);

      final task = await taskRepoA.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await syncA.syncOnce(); // both clients will share this task id

      final dbB = inMemoryDatabase();
      final clockB = _TestClock(d(2026, 7, 10), 1500);
      final completionRepoB =
          CompletionRepository(dbB, clockB, verifier: FakeProofVerifier());
      final syncB = SyncService(dbB, transport);
      await syncB.syncOnce(); // B learns about the task

      // B completes the occurrence first (older updatedAt), while offline.
      final bResult = await completionRepoB.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      final bCompletion = (bResult as CompletionRecorded).completion;
      expect(bCompletion.updatedAt, 1500);

      // A completes the same occurrence later (newer updatedAt), then syncs
      // first so its completion reaches the transport before B syncs again.
      clockA.setMillis(2500);
      final aResult = await completionRepoA.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      final aCompletion = (aResult as CompletionRecorded).completion;
      expect(aCompletion.updatedAt, 2500);
      await syncA.syncOnce();

      // B pulls: sees a brand-new completion id (A's) colliding with its own
      // still-live completion for the same (task, date, slot). A's is newer,
      // so it wins.
      await syncB.syncOnce();

      final bRows = await (dbB.select(dbB.completions)
            ..where((c) => c.taskId.equals(task.id)))
          .get();
      final live = bRows.where((c) => c.deletedAt == null).toList();
      expect(live, hasLength(1));
      expect(live.single.id, aCompletion.id);

      final tombstoned = bRows.where((c) => c.id == bCompletion.id).single;
      expect(tombstoned.deletedAt, isNotNull);
      // Pull-apply marks the tombstoned loser dirty so the tombstone itself
      // propagates back; here it's already false again because B's own
      // syncOnce pushed it successfully in the same call (see the
      // transport assertion right below), which is the intended full
      // lifecycle, not a separate step to catch mid-flight.
      expect(tombstoned.dirty, isFalse);

      // The tombstone must have already been pushed back to the transport by
      // B's own syncOnce (pull then push in the same call).
      expect(transport.completionById(bCompletion.id)!.deletedAt, isNotNull);

      await dbA.close();
      await dbB.close();
    });

    test(
        'an older incoming remote completion loses: it is dropped, the '
        'newer local row is kept live, and the cursor still advances past it',
        () async {
      final transport = FakeSyncTransport();

      final dbA = inMemoryDatabase();
      final clockA = _TestClock(d(2026, 7, 10), 1000);
      final taskRepoA = TaskRepository(dbA, clockA);
      final completionRepoA =
          CompletionRepository(dbA, clockA, verifier: FakeProofVerifier());
      final syncA = SyncService(dbA, transport);

      final task = await taskRepoA.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await syncA.syncOnce();

      final dbB = inMemoryDatabase();
      final clockB = _TestClock(d(2026, 7, 10), 2500);
      final completionRepoB =
          CompletionRepository(dbB, clockB, verifier: FakeProofVerifier());
      final syncB = SyncService(dbB, transport);
      await syncB.syncOnce();

      // A completes second (but still strictly after B's stored cursor of
      // 1000 from the task pull above, so its completion is actually
      // returned by the next pull) and syncs immediately.
      clockA.setMillis(1800);
      final aResult = await completionRepoA.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      final aCompletion = (aResult as CompletionRecorded).completion;
      expect(aCompletion.updatedAt, 1800);
      await syncA.syncOnce();

      // B independently completes the same occurrence with a newer
      // updatedAt still, before ever pulling A's completion.
      final bResult = await completionRepoB.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      final bCompletion = (bResult as CompletionRecorded).completion;
      expect(bCompletion.updatedAt, 2500);

      final beforeCursor = await (dbB.select(dbB.appSettings)
            ..where((s) => s.key.equals(_cursorKey)))
          .getSingleOrNull();
      expect(int.parse(beforeCursor!.value), 1000); // from the earlier task pull

      // B pulls: A's completion is a brand-new id colliding with B's own
      // still-live, newer completion. B's wins; A's is dropped.
      await syncB.syncOnce();

      final bRows = await (dbB.select(dbB.completions)
            ..where((c) => c.taskId.equals(task.id)))
          .get();
      expect(bRows, hasLength(1)); // A's row was never inserted at all
      expect(bRows.single.id, bCompletion.id);
      expect(bRows.single.deletedAt, isNull);

      final afterCursor = await (dbB.select(dbB.appSettings)
            ..where((s) => s.key.equals(_cursorKey)))
          .getSingleOrNull();
      // The cursor moves past the dropped row (A's completion @1800) even
      // though its content was discarded, so it is never re-fetched.
      expect(int.parse(afterCursor!.value), 1800);

      await dbA.close();
      await dbB.close();
    });
  });

  group('two-client convergence', () {
    test('after both clients sync, their non-tombstoned state matches',
        () async {
      final transport = FakeSyncTransport();

      final dbA = inMemoryDatabase();
      final clockA = _TestClock(d(2026, 7, 10), 1000);
      final taskRepoA = TaskRepository(dbA, clockA);
      final completionRepoA =
          CompletionRepository(dbA, clockA, verifier: FakeProofVerifier());
      final syncA = SyncService(dbA, transport);

      final taskX = await taskRepoA.createTask(
        title: 'Task X',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await syncA.syncOnce();

      final dbB = inMemoryDatabase();
      final clockB = _TestClock(d(2026, 7, 10), 1500);
      final taskRepoB = TaskRepository(dbB, clockB);
      final completionRepoB =
          CompletionRepository(dbB, clockB, verifier: FakeProofVerifier());
      final syncB = SyncService(dbB, transport);
      await syncB.syncOnce(); // B learns about Task X, cursor -> 1000

      // Advance A's clock past B's stored cursor (1000, from the task pull
      // above) so this completion is actually newer than what B has already
      // seen and gets returned by B's next pull.
      clockA.setMillis(1500);
      await completionRepoA.completeOccurrence(
        taskId: taskX.id,
        occurrenceDate: d(2026, 7, 10),
      );
      await syncA.syncOnce();

      final taskY = await taskRepoB.createTask(
        title: 'Task Y',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await completionRepoB.completeOccurrence(
        taskId: taskY.id,
        occurrenceDate: d(2026, 7, 10),
      );
      await syncB.syncOnce(); // pulls A's completion; pushes Task Y + its own

      await syncA.syncOnce(); // A catches up on Task Y

      final aTasks = await (dbA.select(dbA.tasks)
            ..where((t) => t.deletedAt.isNull()))
          .get();
      final bTasks = await (dbB.select(dbB.tasks)
            ..where((t) => t.deletedAt.isNull()))
          .get();
      expect(aTasks.map((t) => t.id).toSet(), bTasks.map((t) => t.id).toSet());

      final aCompletions = await (dbA.select(dbA.completions)
            ..where((c) => c.deletedAt.isNull()))
          .get();
      final bCompletions = await (dbB.select(dbB.completions)
            ..where((c) => c.deletedAt.isNull()))
          .get();
      expect(aCompletions.map((c) => c.id).toSet(),
          bCompletions.map((c) => c.id).toSet());

      await dbA.close();
      await dbB.close();
    });
  });
}
