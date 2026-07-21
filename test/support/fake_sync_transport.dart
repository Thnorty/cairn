import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/sync/sync_transport.dart';

/// In-memory stand-in for the Phase 4b remote store: a per-table map keyed
/// by id, each row tracked by its own `updatedAt` for last-write-wins - just
/// enough to unit test [SyncService] (`package:cairn/src/sync/sync_service.dart`)
/// against a shared "server" without a real Supabase project. Not
/// thread-safe (tests are single-isolate); state lives only for the life of
/// the fake.
///
/// Sharing one instance across two [SyncService]s (each backed by its own
/// local `AppDatabase`) simulates two devices syncing through one server,
/// which is how the two-client convergence tests drive this.
class FakeSyncTransport implements SyncTransport {
  final Map<String, Task> _tasks = {};
  final Map<String, Completion> _completions = {};
  final Map<String, VerificationAttempt> _verificationAttempts = {};

  /// When true, the next [pull] call throws instead of returning (simulating
  /// a transport/offline failure) and then resets itself to false, so a test
  /// can flip connectivity back on for the call after.
  bool failNextPull = false;

  /// Same idea as [failNextPull], for [push].
  bool failNextPush = false;

  int pullCallCount = 0;
  int pushCallCount = 0;

  Task? taskById(String id) => _tasks[id];
  Completion? completionById(String id) => _completions[id];
  VerificationAttempt? verificationAttemptById(String id) =>
      _verificationAttempts[id];

  @override
  Future<SyncPullResult> pull({required int cursor}) async {
    pullCallCount++;
    if (failNextPull) {
      failNextPull = false;
      throw StateError('FakeSyncTransport: simulated pull failure');
    }

    final tasks = _tasks.values.where((t) => t.updatedAt > cursor).toList();
    final completions =
        _completions.values.where((c) => c.updatedAt > cursor).toList();
    final attempts = _verificationAttempts.values
        .where((a) => a.updatedAt > cursor)
        .toList();

    var newCursor = cursor;
    for (final t in tasks) {
      if (t.updatedAt > newCursor) newCursor = t.updatedAt;
    }
    for (final c in completions) {
      if (c.updatedAt > newCursor) newCursor = c.updatedAt;
    }
    for (final a in attempts) {
      if (a.updatedAt > newCursor) newCursor = a.updatedAt;
    }

    return SyncPullResult(
      tasks: tasks,
      completions: completions,
      verificationAttempts: attempts,
      newCursor: newCursor,
    );
  }

  @override
  Future<void> push(SyncPushBatch batch) async {
    pushCallCount++;
    if (failNextPush) {
      failNextPush = false;
      throw StateError('FakeSyncTransport: simulated push failure');
    }

    for (final t in batch.tasks) {
      final existing = _tasks[t.id];
      if (existing == null || t.updatedAt >= existing.updatedAt) {
        _tasks[t.id] = t;
      }
    }
    for (final c in batch.completions) {
      final existing = _completions[c.id];
      if (existing == null || c.updatedAt >= existing.updatedAt) {
        _completions[c.id] = c;
      }
    }
    for (final a in batch.verificationAttempts) {
      final existing = _verificationAttempts[a.id];
      if (existing == null || a.updatedAt >= existing.updatedAt) {
        _verificationAttempts[a.id] = a;
      }
    }
  }
}
