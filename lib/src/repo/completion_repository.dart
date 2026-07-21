import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' show SqlExtendedError, SqliteException;
import 'package:uuid/uuid.dart';

import '../clock.dart';
import '../db/database.dart';
import '../models/local_date.dart';
import '../models/proof_verdict.dart';
import '../services/cairn_grouping.dart';
import '../services/occurrence_generator.dart';
import '../services/points_service.dart';
import '../services/proof_verifier.dart';
import '../services/streak_service.dart';

sealed class CompleteOccurrenceResult {
  const CompleteOccurrenceResult();
}

class CompletionRecorded extends CompleteOccurrenceResult {
  final Completion completion;
  const CompletionRecorded(this.completion);
}

/// No back-filling: occurrence_date must equal today (local).
class CompletionRejectedBackfill extends CompleteOccurrenceResult {
  const CompletionRejectedBackfill();
}

/// The (task, date, slot) triple isn't actually a scheduled occurrence.
class CompletionRejectedNotScheduled extends CompleteOccurrenceResult {
  const CompletionRejectedNotScheduled();
}

class CompletionRejectedTaskNotFound extends CompleteOccurrenceResult {
  const CompletionRejectedTaskNotFound();
}

/// UNIQUE(task_id, occurrence_date, slot) already satisfied.
class CompletionRejectedAlreadyCompleted extends CompleteOccurrenceResult {
  const CompletionRejectedAlreadyCompleted();
}

/// The per-task-per-day cap on rejected verification attempts was already
/// hit before this call; the verifier is never invoked.
class CompletionRejectedAttemptsExhausted extends CompleteOccurrenceResult {
  const CompletionRejectedAttemptsExhausted();
}

/// The daily cap on successful (verified or pending) completions was already
/// hit before this call; the verifier is never invoked.
class CompletionRejectedDailyCapReached extends CompleteOccurrenceResult {
  const CompletionRejectedDailyCapReached();
}

/// The proof photo's own capture timestamp (asset metadata) fell outside
/// [ProofPolicy.recencyWindow]. This is a cheap pre-filter checked before the
/// verifier is ever called: no network call is made, and no
/// verification_attempts row is written, so a stale photo does not burn the
/// per-task attempts budget (only a verifier rejection does that).
/// [photoAgeMillis] is null when the photo's capture time itself was unknown
/// (only possible when [ProofPolicy.allowUnknownPhotoTime] is false).
class CompletionRejectedStalePhoto extends CompleteOccurrenceResult {
  final int? photoAgeMillis;
  const CompletionRejectedStalePhoto(this.photoAgeMillis);
}

/// The verifier returned a verdict that failed [ProofPolicy.isVerified]. No
/// completion is recorded; a verification_attempts row was written instead.
class CompletionRejectedByVerifier extends CompleteOccurrenceResult {
  final ProofVerdict verdict;
  final int attemptsRemaining;
  const CompletionRejectedByVerifier(this.verdict, this.attemptsRemaining);
}

/// The verifier could not be reached; a completion was recorded with
/// verification_status = pending. It counts optimistically toward streaks,
/// altitude and the daily cap until [CompletionRepository.retryPendingVerifications]
/// resolves it.
class CompletionPendingVerification extends CompleteOccurrenceResult {
  final Completion completion;
  const CompletionPendingVerification(this.completion);
}

/// Tally of outcomes from a [CompletionRepository.retryPendingVerifications]
/// batch run.
class PendingRetryReport {
  final int verified;
  final int rejected;
  final int stillPending;
  final int skipped;

  const PendingRetryReport({
    this.verified = 0,
    this.rejected = 0,
    this.stillPending = 0,
    this.skipped = 0,
  });
}

enum _RetryOutcome { verified, rejected, stillPending, skipped }

/// Records completions with the no-back-fill guard and computes
/// `points_awarded` (base + streak bonus + perfect-day bonus) at insert
/// time. [completeOccurrence] is the Phase 1 debug path (always inserts
/// `verified`); [completeWithProof] is the real, AI-verified path, backed by
/// a [ProofVerifier] and gated by a [ProofPolicy] (daily cap, per-task
/// attempts cap).
class CompletionRepository {
  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;
  final OccurrenceGenerator _generator;
  final StreakService _streaks;
  final PointsService _points;
  final CairnGrouping _cairns;
  final ProofVerifier _verifier;
  final ProofPolicy _policy;
  final String? Function() _currentUserId;

  /// [currentUserId] is read at every insert (completions and
  /// verification_attempts alike) to stamp `user_id` (WO-4: Phase 2b
  /// anonymous auth). Defaults to a getter that always returns null, so
  /// tests and any caller that hasn't wired auth yet keep writing rows with
  /// `user_id = NULL`, exactly as before this parameter existed.
  CompletionRepository(
    this._db,
    this._clock, {
    Uuid? uuid,
    OccurrenceGenerator generator = const OccurrenceGenerator(),
    StreakService streaks = const StreakService(),
    PointsService points = const PointsService(),
    CairnGrouping cairns = const CairnGrouping(),
    required ProofVerifier verifier,
    ProofPolicy policy = const ProofPolicy(),
    String? Function() currentUserId = _noCurrentUserId,
  })  : _uuid = uuid ?? const Uuid(),
        _generator = generator,
        _streaks = streaks,
        _points = points,
        _cairns = cairns,
        _verifier = verifier,
        _policy = policy,
        _currentUserId = currentUserId;

  static String? _noCurrentUserId() => null;

  Future<CompleteOccurrenceResult> completeOccurrence({
    required String taskId,
    required LocalDate occurrenceDate,
    int slot = 0,
  }) async {
    final today = _clock.today();
    if (occurrenceDate != today) {
      return const CompletionRejectedBackfill();
    }

    return _db.transaction<CompleteOccurrenceResult>(() async {
      final (task, rejection) = await _checkCommonGuards(
        taskId: taskId,
        occurrenceDate: occurrenceDate,
        today: today,
        slot: slot,
      );
      if (rejection != null) return rejection;
      final liveTask = task!;

      final streakLength =
          await _streakLengthIncludingThis(liveTask, today, slot);
      final isPerfectDay = await _isFinalOccurrenceOfDay(
        excludingTaskId: taskId,
        excludingSlot: slot,
        today: today,
      );
      final capsACairn = await _capsACairn(liveTask, today);
      final points = _points.pointsForCompletion(
        streakLengthIncludingThis: streakLength,
        isPerfectDayFinalOccurrence: isPerfectDay,
        capsACairn: capsACairn,
      );

      final now = _clock.nowEpochMillis();
      final id = _uuid.v7();
      try {
        await _db.into(_db.completions).insert(
              CompletionsCompanion.insert(
                id: id,
                taskId: taskId,
                occurrenceDate: today,
                slot: Value(slot),
                completedAt: now,
                verificationStatus:
                    const Value(VerificationStatus.verified),
                pointsAwarded: Value(points),
                userId: Value(_currentUserId()),
                updatedAt: now,
                dirty: const Value(true),
              ),
            );
      } on SqliteException catch (e) {
        // Racing insert on the same (task, date, slot) tripped the partial
        // UNIQUE index after our pre-check; surface it as a graceful result.
        // Any other SQLite error is unexpected and must not be swallowed.
        if (e.extendedResultCode == SqlExtendedError.SQLITE_CONSTRAINT_UNIQUE) {
          return const CompletionRejectedAlreadyCompleted();
        }
        rethrow;
      }

      final inserted = await (_db.select(_db.completions)
            ..where((c) => c.id.equals(id)))
          .getSingle();
      return CompletionRecorded(inserted);
    });
  }

  /// Live (non-tombstoned) completions for [taskId], verified or pending
  /// alike, as they stand *before* the stone currently being inserted. Shared
  /// by [_streakLengthIncludingThis] (streak) and [_capsACairn] (cairn cap
  /// bonus), both of which need the same "this task's history so far" read.
  Future<List<Completion>> _liveCompletionsForTask(String taskId) {
    return (_db.select(_db.completions)
          ..where((c) => c.taskId.equals(taskId) & c.deletedAt.isNull()))
        .get();
  }

  /// The task's current streak as of today, simulating this slot (and any
  /// other slots already done today) as complete.
  Future<int> _streakLengthIncludingThis(
    Task task,
    LocalDate today,
    int slot,
  ) async {
    final taskCompletions = await _liveCompletionsForTask(task.id);
    final done = <(LocalDate, int)>{
      for (final c in taskCompletions) (c.occurrenceDate, c.slot),
    };
    done.add((today, slot));
    return _streaks.currentStreak(
      task,
      today,
      (date, s) => done.contains((date, s)),
    );
  }

  /// True iff the stone about to be inserted for [task] is the one that
  /// fills its current per-task cairn to [PointsService.cairnCapStones]
  /// stones (see [CairnGrouping]). Reads the task's live completions as they
  /// stand *before* this insert, so the just-started next stone is exactly
  /// `growingCairnStoneCount + 1`.
  Future<bool> _capsACairn(Task task, LocalDate today) async {
    final existing = await _liveCompletionsForTask(task.id);
    final growingSoFar = _cairns.growingCairnStoneCount(
      task: task,
      today: today,
      liveCompletions: existing,
    );
    return growingSoFar + 1 == PointsService.cairnCapStones;
  }

  /// True iff every occurrence scheduled today across all active tasks,
  /// other than (excludingTaskId, excludingSlot), is already complete (i.e.
  /// this completion is the day's final scheduled occurrence).
  Future<bool> _isFinalOccurrenceOfDay({
    required String excludingTaskId,
    required int excludingSlot,
    required LocalDate today,
  }) async {
    final tasks = await (_db.select(_db.tasks)
          ..where((t) => t.archived.equals(false) & t.deletedAt.isNull()))
        .get();

    final allOccurrences = <(String, int)>{
      for (final task in tasks)
        for (final occ
            in _generator.occurrencesFor(task, DateRange(today, today)))
          (task.id, occ.slot),
    };
    allOccurrences.remove((excludingTaskId, excludingSlot));
    if (allOccurrences.isEmpty) return true;

    final todaysCompletions = await (_db.select(_db.completions)
          ..where((c) =>
              c.occurrenceDate.equalsValue(today) & c.deletedAt.isNull()))
        .get();
    final doneToday = <(String, int)>{
      for (final c in todaysCompletions) (c.taskId, c.slot),
    };

    return allOccurrences.every(doneToday.contains);
  }

  /// Shared guards a-d of the completion guard chain: no back-fill, the task
  /// must exist (and not be tombstoned), the (task, date, slot) triple must
  /// actually be a scheduled occurrence, and no live completion may already
  /// occupy that slot. Returns the live task on success, or the rejection to
  /// return immediately.
  Future<(Task?, CompleteOccurrenceResult?)> _checkCommonGuards({
    required String taskId,
    required LocalDate occurrenceDate,
    required LocalDate today,
    required int slot,
  }) async {
    if (occurrenceDate != today) {
      return (null, const CompletionRejectedBackfill());
    }

    final task = await (_db.select(_db.tasks)
          ..where((t) => t.id.equals(taskId) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (task == null) return (null, const CompletionRejectedTaskNotFound());

    final todaysOccurrences =
        _generator.occurrencesFor(task, DateRange(today, today));
    if (!todaysOccurrences.any((o) => o.slot == slot)) {
      return (null, const CompletionRejectedNotScheduled());
    }

    final existing = await (_db.select(_db.completions)
          ..where((c) =>
              c.taskId.equals(taskId) &
              c.occurrenceDate.equalsValue(today) &
              c.slot.equals(slot) &
              c.deletedAt.isNull()))
        .getSingleOrNull();
    if (existing != null) {
      return (null, const CompletionRejectedAlreadyCompleted());
    }

    return (task, null);
  }

  /// Live (non-tombstoned) verification_attempts rows for [taskId] on
  /// [today], shared across all of the task's slots.
  Future<int> _liveAttemptsCountToday(String taskId, LocalDate today) async {
    final rows = await (_db.select(_db.verificationAttempts)
          ..where((a) =>
              a.taskId.equals(taskId) &
              a.occurrenceDate.equalsValue(today) &
              a.deletedAt.isNull()))
        .get();
    return rows.length;
  }

  /// Live completions counting toward the daily cap: verified or pending,
  /// across all tasks, on [today].
  Future<int> _liveDailyCapCountToday(LocalDate today) async {
    final rows = await (_db.select(_db.completions)
          ..where((c) =>
              c.occurrenceDate.equalsValue(today) &
              c.deletedAt.isNull() &
              (c.verificationStatus.equalsValue(VerificationStatus.verified) |
                  c.verificationStatus.equalsValue(VerificationStatus.pending))))
        .get();
    return rows.length;
  }

  /// Live (non-tombstoned) verification_attempts rows recorded for [taskId]
  /// today: how many of the day's [ProofPolicy.attemptsPerTaskPerDay] this
  /// task has used. Read-only counter for the UI (the debug screen's
  /// "Attempts today: n/3" line; Phase 3's Daily Limit screen needs the same
  /// number, hence a proper public repository method rather than a
  /// debug-screen-only query).
  Future<int> attemptsUsedToday(String taskId) {
    return _liveAttemptsCountToday(taskId, _clock.today());
  }

  /// Live completions today (verified or pending, across all tasks): how
  /// many of the day's [ProofPolicy.dailyCap] have been used. Read-only
  /// counter for the UI (the debug screen's "Proofs today: n/5" line; Phase
  /// 3's Daily Limit screen needs the same number, hence a proper public
  /// repository method rather than a debug-screen-only query).
  Future<int> successfulProofsToday() {
    return _liveDailyCapCountToday(_clock.today());
  }

  /// Read-only subset of [completeWithProof]'s guard chain that a caller can
  /// run *before* capturing a photo, so a doomed attempt (already completed,
  /// not scheduled, back-filled, or over either cap) never has to open the
  /// camera/gallery picker first. Runs, in order: back-fill, task exists,
  /// scheduled, live duplicate (all via [_checkCommonGuards], shared with
  /// [completeWithProof] rather than duplicated), then the attempts cap,
  /// then the daily cap. Deliberately does NOT check recency (there is no
  /// photo yet to check) and does NOT write anything.
  ///
  /// This is a UX short-circuit, not the enforcement point: state can change
  /// between this call and the [completeWithProof] call that follows it
  /// (e.g. another attempt on a different slot lands in between), so
  /// [completeWithProof] must keep running its own full guard chain
  /// regardless of what this method returned. Do not delete either half
  /// thinking the other makes it redundant.
  ///
  /// Returns the rejection to surface to the user, or null when capture
  /// should proceed.
  Future<CompleteOccurrenceResult?> precheckProof({
    required String taskId,
    required LocalDate occurrenceDate,
    int slot = 0,
  }) async {
    final today = _clock.today();

    final (_, commonRejection) = await _checkCommonGuards(
      taskId: taskId,
      occurrenceDate: occurrenceDate,
      today: today,
      slot: slot,
    );
    if (commonRejection != null) return commonRejection;

    final attemptsSoFar = await _liveAttemptsCountToday(taskId, today);
    if (attemptsSoFar >= _policy.attemptsPerTaskPerDay) {
      return const CompletionRejectedAttemptsExhausted();
    }

    final dailyCountSoFar = await _liveDailyCapCountToday(today);
    if (dailyCountSoFar >= _policy.dailyCap) {
      return const CompletionRejectedDailyCapReached();
    }

    return null;
  }

  /// Records a completion backed by an AI-verified (or pending) proof photo.
  ///
  /// Guards a-f, then the recency pre-filter, all run read-only before the
  /// verifier is ever called, so a failed guard never costs a network call
  /// (verified by [FakeProofVerifier.callCount] in tests). A stale photo
  /// (guard fails [ProofPolicy.isRecent]) is rejected without writing a
  /// verification_attempts row, since staleness isn't a verifier rejection.
  /// Once the guards pass, the verifier is called outside any transaction
  /// (it's network I/O in the real implementation); the result is then
  /// written in a transaction.
  ///
  /// [precheckProof] runs the subset of these guards that don't need a photo
  /// and is meant to be called first, as a UX short-circuit before the photo
  /// picker even opens. It is not a substitute for this method's own guard
  /// chain, which stays the actual enforcement point (state can change
  /// between the two calls), so both must keep running independently.
  Future<CompleteOccurrenceResult> completeWithProof({
    required String taskId,
    required LocalDate occurrenceDate,
    int slot = 0,
    required ProofData proof,
  }) async {
    final today = _clock.today();

    final (task, commonRejection) = await _checkCommonGuards(
      taskId: taskId,
      occurrenceDate: occurrenceDate,
      today: today,
      slot: slot,
    );
    if (commonRejection != null) return commonRejection;
    final liveTask = task!;

    final attemptsSoFar = await _liveAttemptsCountToday(taskId, today);
    if (attemptsSoFar >= _policy.attemptsPerTaskPerDay) {
      return const CompletionRejectedAttemptsExhausted();
    }

    final dailyCountSoFar = await _liveDailyCapCountToday(today);
    if (dailyCountSoFar >= _policy.dailyCap) {
      return const CompletionRejectedDailyCapReached();
    }

    final nowForRecency = _clock.nowEpochMillis();
    if (!_policy.isRecent(proof.photoTakenAt, nowForRecency)) {
      final photoTakenAt = proof.photoTakenAt;
      final age =
          photoTakenAt == null ? null : nowForRecency - photoTakenAt;
      return CompletionRejectedStalePhoto(age);
    }

    final response = await _verifier.verify(ProofRequest(
      imageBytes: proof.imageBytes,
      taskTitle: liveTask.title,
      taskDescription: liveTask.description,
    ));

    switch (response) {
      case VerdictReceived(:final verdict):
        if (_policy.isVerified(verdict)) {
          return _db.transaction<CompleteOccurrenceResult>(
            () => _insertProofCompletion(
              task: liveTask,
              today: today,
              slot: slot,
              status: VerificationStatus.verified,
              verificationMeta: jsonEncode(verdict.toJson()),
              proof: proof,
            ),
          );
        }
        return _db.transaction<CompleteOccurrenceResult>(() async {
          final now = _clock.nowEpochMillis();
          await _db.into(_db.verificationAttempts).insert(
                VerificationAttemptsCompanion.insert(
                  id: _uuid.v7(),
                  taskId: taskId,
                  occurrenceDate: today,
                  slot: Value(slot),
                  attemptedAt: now,
                  verdictMeta: Value(jsonEncode(verdict.toJson())),
                  userId: Value(_currentUserId()),
                  updatedAt: now,
                  dirty: const Value(true),
                ),
              );
          final attemptsNow = await _liveAttemptsCountToday(taskId, today);
          final remaining = _policy.attemptsPerTaskPerDay - attemptsNow;
          return CompletionRejectedByVerifier(
            verdict,
            remaining < 0 ? 0 : remaining,
          );
        });
      case VerifierUnavailable():
        return _db.transaction<CompleteOccurrenceResult>(
          () => _insertProofCompletion(
            task: liveTask,
            today: today,
            slot: slot,
            status: VerificationStatus.pending,
            verificationMeta: null,
            proof: proof,
          ),
        );
    }
  }

  /// Computes points at insert time (base + streak bonus + perfect-day
  /// bonus, exactly as [completeOccurrence] does) and inserts a completion
  /// carrying the proof fields and the given [status] (verified or pending).
  Future<CompleteOccurrenceResult> _insertProofCompletion({
    required Task task,
    required LocalDate today,
    required int slot,
    required VerificationStatus status,
    required String? verificationMeta,
    required ProofData proof,
  }) async {
    final streakLength = await _streakLengthIncludingThis(task, today, slot);
    final isPerfectDay = await _isFinalOccurrenceOfDay(
      excludingTaskId: task.id,
      excludingSlot: slot,
      today: today,
    );
    final capsACairn = await _capsACairn(task, today);
    final points = _points.pointsForCompletion(
      streakLengthIncludingThis: streakLength,
      isPerfectDayFinalOccurrence: isPerfectDay,
      capsACairn: capsACairn,
    );

    final now = _clock.nowEpochMillis();
    final id = _uuid.v7();
    try {
      await _db.into(_db.completions).insert(
            CompletionsCompanion.insert(
              id: id,
              taskId: task.id,
              occurrenceDate: today,
              slot: Value(slot),
              completedAt: now,
              proofPhotoPath: Value(proof.photoPath),
              proofSource: Value(proof.source),
              photoTakenAt: Value(proof.photoTakenAt),
              verificationStatus: Value(status),
              verificationMeta: Value(verificationMeta),
              pointsAwarded: Value(points),
              userId: Value(_currentUserId()),
              updatedAt: now,
              dirty: const Value(true),
            ),
          );
    } on SqliteException catch (e) {
      // Racing insert on the same (task, date, slot) tripped the partial
      // UNIQUE index after our pre-check; surface it as a graceful result.
      // Any other SQLite error is unexpected and must not be swallowed.
      if (e.extendedResultCode == SqlExtendedError.SQLITE_CONSTRAINT_UNIQUE) {
        return const CompletionRejectedAlreadyCompleted();
      }
      rethrow;
    }

    final inserted = await (_db.select(_db.completions)
          ..where((c) => c.id.equals(id)))
        .getSingle();
    return status == VerificationStatus.verified
        ? CompletionRecorded(inserted)
        : CompletionPendingVerification(inserted);
  }

  /// Retries every live `pending` completion through the verifier. Never
  /// inserts a completion: a verified retry flips the existing row in place,
  /// a rejected retry tombstones it and records an attempt against its
  /// *original* occurrence_date/slot, and streaks/altitude self-heal because
  /// both are derived from live completions. This is what keeps the
  /// no-back-fill rule intact for pendings that outlive the day they were
  /// recorded on.
  Future<PendingRetryReport> retryPendingVerifications({
    required Future<Uint8List?> Function(Completion completion) loadBytes,
  }) async {
    final pendingRows = await (_db.select(_db.completions)
          ..where((c) =>
              c.verificationStatus.equalsValue(VerificationStatus.pending) &
              c.deletedAt.isNull()))
        .get();

    var verified = 0;
    var rejected = 0;
    var stillPending = 0;
    var skipped = 0;

    for (final completion in pendingRows) {
      final outcome = await _retrySinglePending(completion, loadBytes);
      switch (outcome) {
        case _RetryOutcome.verified:
          verified++;
        case _RetryOutcome.rejected:
          rejected++;
        case _RetryOutcome.stillPending:
          stillPending++;
        case _RetryOutcome.skipped:
          skipped++;
      }
    }

    return PendingRetryReport(
      verified: verified,
      rejected: rejected,
      stillPending: stillPending,
      skipped: skipped,
    );
  }

  Future<_RetryOutcome> _retrySinglePending(
    Completion completion,
    Future<Uint8List?> Function(Completion completion) loadBytes,
  ) async {
    // Looked up ignoring deletedAt/archived: a pending proof for a
    // since-deleted task must still resolve.
    final task = await (_db.select(_db.tasks)
          ..where((t) => t.id.equals(completion.taskId)))
        .getSingleOrNull();
    if (task == null) return _RetryOutcome.skipped;

    final bytes = await loadBytes(completion);
    if (bytes == null) return _RetryOutcome.skipped;

    final response = await _verifier.verify(ProofRequest(
      imageBytes: bytes,
      taskTitle: task.title,
      taskDescription: task.description,
    ));

    switch (response) {
      case VerifierUnavailable():
        return _RetryOutcome.stillPending;
      case VerdictReceived(:final verdict):
        final now = _clock.nowEpochMillis();
        if (_policy.isVerified(verdict)) {
          await (_db.update(_db.completions)
                ..where((c) => c.id.equals(completion.id)))
              .write(CompletionsCompanion(
            verificationStatus: const Value(VerificationStatus.verified),
            verificationMeta: Value(jsonEncode(verdict.toJson())),
            updatedAt: Value(now),
            dirty: const Value(true),
          ));
          return _RetryOutcome.verified;
        }
        await _db.transaction(() async {
          await (_db.update(_db.completions)
                ..where((c) => c.id.equals(completion.id)))
              .write(CompletionsCompanion(
            verificationStatus: const Value(VerificationStatus.rejected),
            verificationMeta: Value(jsonEncode(verdict.toJson())),
            deletedAt: Value(now),
            updatedAt: Value(now),
            dirty: const Value(true),
          ));
          await _db.into(_db.verificationAttempts).insert(
                VerificationAttemptsCompanion.insert(
                  id: _uuid.v7(),
                  taskId: completion.taskId,
                  occurrenceDate: completion.occurrenceDate,
                  slot: Value(completion.slot),
                  attemptedAt: now,
                  verdictMeta: Value(jsonEncode(verdict.toJson())),
                  userId: Value(_currentUserId()),
                  updatedAt: now,
                  dirty: const Value(true),
                ),
              );
        });
        return _RetryOutcome.rejected;
    }
  }

  /// Sync tombstone delete: rows are never hard-deleted.
  Future<void> tombstoneDelete(String completionId) async {
    final now = _clock.nowEpochMillis();
    await (_db.update(_db.completions)
          ..where((c) => c.id.equals(completionId)))
        .write(CompletionsCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
      dirty: const Value(true),
    ));
  }

  /// Total altitude: sum of points_awarded over live (non-tombstoned)
  /// completions that are *verified*. Altitude is a permanent cumulative
  /// score, so a pending completion (its verdict not yet in) must not
  /// inflate it and then deflate it again if the retry later rejects it:
  /// that would make the displayed rank move backwards, which must never
  /// happen. `points_awarded` is still computed and stored at insert time
  /// exactly as before; it simply doesn't count here until the row's status
  /// flips to verified. A rejected retry tombstones the row, which removes
  /// metres that were never counted toward this total in the first place, so
  /// altitude can only ever go up or stay flat, never down.
  Future<int> totalAltitude() async {
    final rows = await (_db.select(_db.completions)
          ..where((c) =>
              c.deletedAt.isNull() &
              c.verificationStatus.equalsValue(VerificationStatus.verified)))
        .get();
    return _points.totalAltitude(rows.map((c) => c.pointsAwarded));
  }

  /// Metres "not awarded yet": sum of points_awarded over live completions
  /// still awaiting a verdict (`pending`). This is the counterpart to
  /// [totalAltitude] for surfacing what a pending proof *would* add once
  /// verified, without counting it yet. Drops to zero once every pending
  /// completion resolves (either verified, where the same metres move into
  /// [totalAltitude], or rejected, where the row is tombstoned and the
  /// metres are simply gone).
  Future<int> pendingAltitude() async {
    final rows = await (_db.select(_db.completions)
          ..where((c) =>
              c.deletedAt.isNull() &
              c.verificationStatus.equalsValue(VerificationStatus.pending)))
        .get();
    return _points.totalAltitude(rows.map((c) => c.pointsAwarded));
  }

  /// Live (non-tombstoned) completions for [taskId], verified or pending
  /// alike: the same read [CairnGrouping] needs to build a task's cairn
  /// history. Public wrapper around [_liveCompletionsForTask] so callers
  /// outside this repository (the Trail screen's [TrailService]) can build a
  /// [CairnGrouping] without duplicating this query.
  Future<List<Completion>> liveCompletionsForTask(String taskId) =>
      _liveCompletionsForTask(taskId);

  /// Every task's live (non-tombstoned) completions, verified or pending
  /// alike, grouped by `taskId` in a single query - the same read
  /// [CairnGrouping.currentCairn]/[CairnGrouping.cairnsFor] need per task,
  /// fetched once rather than fanned out one query per task (Home's own
  /// snapshot build). Tasks with zero completions are simply absent from the
  /// map; callers should treat a missing key as an empty list.
  Future<Map<String, List<Completion>>> liveCompletionsGroupedByTask() async {
    final rows = await (_db.select(_db.completions)
          ..where((c) => c.deletedAt.isNull()))
        .get();
    final grouped = <String, List<Completion>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.taskId, () => []).add(row);
    }
    return grouped;
  }

  /// The task's current cairn (see [CairnGrouping.currentCairn]'s doc
  /// comment for the exact rule): the index/stone-count pair every
  /// "Cairn N · M stones" label in the app shows for this task. For the
  /// proof-outcome screens ([routeToProofOutcome] in
  /// `proof_outcome_routing.dart`), which only have a `taskId` to work
  /// from, not a loaded [Task].
  ///
  /// Returns `(index: 1, stoneCount: 0)` - the same synthetic "brand-new
  /// task" value [CairnGrouping.currentCairn] returns for an empty history -
  /// when [taskId] doesn't name a live task at all (missing or tombstoned),
  /// so a caller never has to special-case that lookup failure.
  Future<({int index, int stoneCount})> currentCairnFor(String taskId) async {
    final task = await (_db.select(_db.tasks)
          ..where((t) => t.id.equals(taskId) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (task == null) return (index: 1, stoneCount: 0);

    final liveCompletions = await _liveCompletionsForTask(taskId);
    final cairn = _cairns.currentCairn(
      task: task,
      today: _clock.today(),
      liveCompletions: liveCompletions,
    );
    return (index: cairn.index, stoneCount: cairn.stoneCount);
  }

  /// Every live (non-tombstoned) completion recorded for local date [date],
  /// across all tasks, regardless of verification status. Used to look up
  /// which of today's occurrences already have a placed stone (and whether
  /// it's verified or still pending) without a separate query per occurrence.
  Future<List<Completion>> liveCompletionsForDate(LocalDate date) {
    return (_db.select(_db.completions)
          ..where((c) =>
              c.occurrenceDate.equalsValue(date) & c.deletedAt.isNull()))
        .get();
  }

  /// Count of live completions (any task, verified or pending) whose
  /// occurrence_date falls in the Monday-Sunday ISO week containing
  /// [anyDateInWeek] - the Home screen's "N stones this week" summary.
  /// [LocalDate.weekday] is the ISO weekday (1=Monday..7=Sunday) this is
  /// anchored on, so the week always starts on Monday regardless of the
  /// locale's own first-day-of-week convention.
  Future<int> completionsCountForWeekOf(LocalDate anyDateInWeek) async {
    final weekStart = anyDateInWeek.addDays(-(anyDateInWeek.weekday - 1));
    final weekEnd = weekStart.addDays(6);
    final rows = await (_db.select(_db.completions)
          ..where((c) =>
              c.deletedAt.isNull() &
              c.occurrenceDate.isBiggerOrEqualValue(weekStart.toIso()) &
              c.occurrenceDate.isSmallerOrEqualValue(weekEnd.toIso())))
        .get();
    return rows.length;
  }

  /// One-time backfill for rows created before the first successful
  /// anonymous sign-in (WO-4), covering both tables this repository owns:
  /// completions and verification_attempts. See
  /// [TaskRepository.backfillUserId] for the full rationale (Phase 4's
  /// account upgrade carrying pre-auth history), which applies identically
  /// here, including idempotency: only rows matching `user_id IS NULL` are
  /// touched, so a second call (or a call on every launch) is a no-op once
  /// every row has been stamped.
  ///
  /// Runs both updates in one transaction so a crash mid-backfill can't
  /// leave completions stamped but attempts not (or vice versa). Returns
  /// the number of completions rows updated.
  Future<int> backfillUserId(String userId) {
    return _db.transaction<int>(() async {
      final now = _clock.nowEpochMillis();
      final completionsUpdated =
          await (_db.update(_db.completions)..where((c) => c.userId.isNull()))
              .write(CompletionsCompanion(
        userId: Value(userId),
        updatedAt: Value(now),
        dirty: const Value(true),
      ));
      await (_db.update(_db.verificationAttempts)
            ..where((a) => a.userId.isNull()))
          .write(VerificationAttemptsCompanion(
        userId: Value(userId),
        updatedAt: Value(now),
        dirty: const Value(true),
      ));
      return completionsUpdated;
    });
  }
}
