import '../db/database.dart';

/// Rows changed on the server since the caller's cursor, plus the cursor to
/// use for the next pull.
///
/// A table absent from the server's change set simply comes back as an empty
/// list; callers should not treat that as an error.
class SyncPullResult {
  final List<Task> tasks;
  final List<Completion> completions;
  final List<VerificationAttempt> verificationAttempts;

  /// The new cursor: the max `updatedAt` seen across every row returned by
  /// this pull (across all three tables), or the cursor passed in if nothing
  /// came back. Must never be smaller than the cursor the caller passed to
  /// [SyncTransport.pull], so a caller can always safely persist it.
  final int newCursor;

  const SyncPullResult({
    this.tasks = const [],
    this.completions = const [],
    this.verificationAttempts = const [],
    required this.newCursor,
  });
}

/// The locally-dirty rows a push sends, grouped by table.
class SyncPushBatch {
  final List<Task> tasks;
  final List<Completion> completions;
  final List<VerificationAttempt> verificationAttempts;

  const SyncPushBatch({
    this.tasks = const [],
    this.completions = const [],
    this.verificationAttempts = const [],
  });

  bool get isEmpty =>
      tasks.isEmpty && completions.isEmpty && verificationAttempts.isEmpty;
}

/// Seam between the hand-rolled delta-sync engine ([SyncService], Phase 4a)
/// and whatever remote store mirrors the local schema (Supabase Postgres,
/// Phase 4b). Rows are represented with the existing drift data classes
/// (`Task`/`Completion`/`VerificationAttempt`) rather than a separate wire
/// DTO, to keep the engine and [SyncService]'s tests simple; the real
/// `SupabaseSyncTransport` (Phase 4b) is responsible for mapping these
/// to/from the Postgres/JSON wire format itself.
///
/// Same pattern as `ProofVerifier`: an abstract seam, a real (stubbed for
/// now) implementation, and an in-memory fake for tests.
abstract class SyncTransport {
  /// Rows changed on the server with `updatedAt > cursor`, per table, plus
  /// the new cursor. Cursor is `updatedAt`-based, per CLAUDE.md's "cursor
  /// pull on updated_at".
  Future<SyncPullResult> pull({required int cursor});

  /// Sends the locally-dirty rows in [batch]; the server applies
  /// last-write-wins by `updatedAt`. A normal return means every row in the
  /// batch was accepted. Throwing means nothing was accepted: the caller
  /// must not clear `dirty` on any row in [batch] in that case, so the next
  /// sync retries the whole batch.
  Future<void> push(SyncPushBatch batch);
}

/// Real remote transport (Phase 4b): maps the drift row types to/from the
/// Supabase Postgres wire JSON and calls out over the network. Requires the
/// remote tables and a live project, neither of which exist yet (Phase 4a is
/// the client engine only), so every method is an explicit stub until then.
/// This placeholder exists so the sync engine and its provider wiring have a
/// real-implementation slot to point at without faking a network.
class SupabaseSyncTransport implements SyncTransport {
  const SupabaseSyncTransport();

  @override
  Future<SyncPullResult> pull({required int cursor}) {
    throw UnimplementedError('Phase 4b: needs the remote tables');
  }

  @override
  Future<void> push(SyncPushBatch batch) {
    throw UnimplementedError('Phase 4b: needs the remote tables');
  }
}
