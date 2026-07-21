import 'package:drift/drift.dart';

import '../db/database.dart';
import 'sync_transport.dart';

/// Outcome of one [SyncService.syncOnce] call. `pulled`/`pushed` report
/// which phases completed; `error` (non-null iff either is false) carries
/// whatever the transport threw, purely for logging/diagnostics - callers
/// must not branch app behaviour on its text.
class SyncResult {
  final bool pulled;
  final bool pushed;
  final String? error;

  const SyncResult({required this.pulled, required this.pushed, this.error});

  bool get isFullSuccess => pulled && pushed && error == null;
}

/// The hand-rolled client delta-sync engine (Phase 4a). One [syncOnce] call
/// does a full pull-then-push cycle against a [SyncTransport]:
///
/// 1. **Pull.** Fetch every row the server has changed since the locally
///    stored cursor (`AppSettings['sync_pull_cursor']`, default 0). Apply
///    each returned row with last-write-wins by id: a row this device has
///    never seen, or one whose `updatedAt` is strictly newer than the local
///    copy, overwrites the local row *directly* (bypassing
///    `TaskRepository`/`CompletionRepository`, so none of their points/cairn
///    invariants re-run against server-truth data) and is written with
///    `dirty = false`, since a pulled row is by definition already in sync.
///    A local row whose `updatedAt` is `>=` the remote row's is left alone
///    (and stays dirty if it already was, since it hasn't been pushed yet).
///    `deletedAt` on a remote row is just another field under the same LWW
///    rule: an incoming tombstone applies exactly like any other update.
///    Once every row is applied, the new cursor is persisted.
/// 2. **Push.** Gather every row across the three tables with `dirty =
///    true`, send them in one batch, and on success clear `dirty` for
///    exactly the rows sent - but only where the row's *current* `updatedAt`
///    still equals what was pushed, so a row edited locally during the push
///    (a race, not typically possible in this single-isolate app but cheap
///    to guard) stays dirty and is retried next time.
///
/// **Offline/transport-error handling:** [syncOnce] never throws for a
/// transport failure. If `pull` throws, the whole cycle aborts before
/// touching the cursor or any row - next call retries the pull from
/// scratch. If `pull` succeeds but `push` throws, the pull's effects (rows
/// applied, cursor advanced) are kept - there is nothing to retry there -
/// but no row's `dirty` flag is cleared, so the next call's push resends
/// the same batch (plus anything newly dirtied since).
///
/// **Same-occurrence, different-id collision.** Two devices completing the
/// same `(task_id, occurrence_date, slot)` while both offline mint two
/// completions with different ids; the partial unique index
/// (`completions_slot_unique`, live rows only) means at most one of them can
/// stay live locally. When pull-apply meets a brand-new remote completion
/// id that collides with a *different*, still-live local completion for the
/// same slot: the row with the newer `updatedAt` wins and stays/becomes
/// live; the other is tombstoned in place (`deletedAt`/`updatedAt` set to
/// the winner's `updatedAt`, `dirty = true` so the tombstone itself
/// propagates back). If the incoming remote row is the loser, it is simply
/// not inserted at all - the cursor still advances past it (computed from
/// the whole pull batch), so it is never re-fetched. This is a pragmatic
/// rule, not a merge: it silently discards one side's stone. Revisit once
/// Phase 4b's server-side design exists to do something better (e.g.
/// resurrect the loser under a new slot).
class SyncService {
  final AppDatabase _db;
  final SyncTransport _transport;

  static const _cursorKey = 'sync_pull_cursor';

  SyncService(this._db, this._transport);

  Future<SyncResult> syncOnce() async {
    final cursor = await _readCursor();

    final SyncPullResult pullResult;
    try {
      pullResult = await _transport.pull(cursor: cursor);
    } catch (e) {
      return SyncResult(pulled: false, pushed: false, error: e.toString());
    }

    await _db.transaction(() async {
      await _applyPulledTasks(pullResult.tasks);
      await _applyPulledCompletions(pullResult.completions);
      await _applyPulledVerificationAttempts(pullResult.verificationAttempts);

      // Defensive: never let the stored cursor move backwards even if a
      // transport implementation misbehaves.
      final newCursor =
          pullResult.newCursor > cursor ? pullResult.newCursor : cursor;
      await _writeCursor(newCursor);
    });

    final batch = await _collectDirtyBatch();
    if (batch.isEmpty) {
      return const SyncResult(pulled: true, pushed: true);
    }

    try {
      await _transport.push(batch);
    } catch (e) {
      return SyncResult(pulled: true, pushed: false, error: e.toString());
    }

    await _clearDirtyForPushed(batch);
    return const SyncResult(pulled: true, pushed: true);
  }

  // ---- pull-apply ----------------------------------------------------

  Future<void> _applyPulledTasks(List<Task> remoteRows) async {
    for (final remote in remoteRows) {
      final local = await (_db.select(_db.tasks)
            ..where((t) => t.id.equals(remote.id)))
          .getSingleOrNull();
      if (local == null || remote.updatedAt > local.updatedAt) {
        await _db.into(_db.tasks).insertOnConflictUpdate(
              remote.toCompanion(false).copyWith(dirty: const Value(false)),
            );
      }
    }
  }

  Future<void> _applyPulledVerificationAttempts(
    List<VerificationAttempt> remoteRows,
  ) async {
    for (final remote in remoteRows) {
      final local = await (_db.select(_db.verificationAttempts)
            ..where((a) => a.id.equals(remote.id)))
          .getSingleOrNull();
      if (local == null || remote.updatedAt > local.updatedAt) {
        await _db.into(_db.verificationAttempts).insertOnConflictUpdate(
              remote.toCompanion(false).copyWith(dirty: const Value(false)),
            );
      }
    }
  }

  /// See the class doc comment's "Same-occurrence, different-id collision"
  /// section for the rule this implements.
  Future<void> _applyPulledCompletions(List<Completion> remoteRows) async {
    for (final remote in remoteRows) {
      final local = await (_db.select(_db.completions)
            ..where((c) => c.id.equals(remote.id)))
          .getSingleOrNull();

      if (local != null) {
        if (remote.updatedAt > local.updatedAt) {
          await _upsertCompletion(remote);
        }
        continue;
      }

      // A completion id this device has never seen. A tombstoned incoming
      // row can never collide with the partial unique index (which only
      // covers live rows), so only a *live* incoming row needs the
      // same-slot collision check against this device's own live rows.
      if (remote.deletedAt == null) {
        final collision = await (_db.select(_db.completions)
              ..where((c) =>
                  c.taskId.equals(remote.taskId) &
                  c.occurrenceDate.equalsValue(remote.occurrenceDate) &
                  c.slot.equals(remote.slot) &
                  c.deletedAt.isNull()))
            .getSingleOrNull();

        if (collision != null) {
          if (remote.updatedAt > collision.updatedAt) {
            // The incoming row wins: retire the local loser first so the
            // partial unique index has room, then insert the winner.
            await (_db.update(_db.completions)
                  ..where((c) => c.id.equals(collision.id)))
                .write(CompletionsCompanion(
              deletedAt: Value(remote.updatedAt),
              updatedAt: Value(remote.updatedAt),
              dirty: const Value(true),
            ));
            await _upsertCompletion(remote);
          }
          // Else: the local row already holds the winning data for this
          // slot; the incoming remote row is dropped (see class doc
          // comment).
          continue;
        }
      }

      await _upsertCompletion(remote);
    }
  }

  Future<void> _upsertCompletion(Completion remote) {
    return _db.into(_db.completions).insertOnConflictUpdate(
          remote.toCompanion(false).copyWith(dirty: const Value(false)),
        );
  }

  // ---- push -----------------------------------------------------------

  Future<SyncPushBatch> _collectDirtyBatch() async {
    final tasks =
        await (_db.select(_db.tasks)..where((t) => t.dirty.equals(true)))
            .get();
    final completions = await (_db.select(_db.completions)
          ..where((c) => c.dirty.equals(true)))
        .get();
    final attempts = await (_db.select(_db.verificationAttempts)
          ..where((a) => a.dirty.equals(true)))
        .get();
    return SyncPushBatch(
      tasks: tasks,
      completions: completions,
      verificationAttempts: attempts,
    );
  }

  /// Clears `dirty` for exactly the rows in [batch], and only where the
  /// row's current `updatedAt` still matches what was pushed - see the
  /// class doc comment.
  Future<void> _clearDirtyForPushed(SyncPushBatch batch) async {
    for (final row in batch.tasks) {
      await (_db.update(_db.tasks)
            ..where((t) => t.id.equals(row.id) & t.updatedAt.equals(row.updatedAt)))
          .write(const TasksCompanion(dirty: Value(false)));
    }
    for (final row in batch.completions) {
      await (_db.update(_db.completions)
            ..where((c) =>
                c.id.equals(row.id) & c.updatedAt.equals(row.updatedAt)))
          .write(const CompletionsCompanion(dirty: Value(false)));
    }
    for (final row in batch.verificationAttempts) {
      await (_db.update(_db.verificationAttempts)
            ..where((a) =>
                a.id.equals(row.id) & a.updatedAt.equals(row.updatedAt)))
          .write(const VerificationAttemptsCompanion(dirty: Value(false)));
    }
  }

  // ---- cursor -----------------------------------------------------------

  Future<int> _readCursor() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(_cursorKey)))
        .getSingleOrNull();
    if (row == null) return 0;
    return int.tryParse(row.value) ?? 0;
  }

  Future<void> _writeCursor(int cursor) {
    return _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion(
            key: const Value(_cursorKey),
            value: Value(cursor.toString()),
          ),
        );
  }
}
