import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' show SqlExtendedError, SqliteException;
import 'package:uuid/uuid.dart';

import '../clock.dart';
import '../db/database.dart';
import '../models/local_date.dart';
import '../services/occurrence_generator.dart';
import '../services/points_service.dart';
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

/// Records completions with the no-back-fill guard and computes
/// `points_awarded` (base + streak bonus + perfect-day bonus) at insert
/// time. In Phase 1, completions are always inserted as `verified`: Gemini
/// verification arrives in a later phase.
class CompletionRepository {
  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;
  final OccurrenceGenerator _generator;
  final StreakService _streaks;
  final PointsService _points;

  CompletionRepository(
    this._db,
    this._clock, {
    Uuid? uuid,
    OccurrenceGenerator generator = const OccurrenceGenerator(),
    StreakService streaks = const StreakService(),
    PointsService points = const PointsService(),
  })  : _uuid = uuid ?? const Uuid(),
        _generator = generator,
        _streaks = streaks,
        _points = points;

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
      final task = await (_db.select(_db.tasks)
            ..where((t) => t.id.equals(taskId) & t.deletedAt.isNull()))
          .getSingleOrNull();
      if (task == null) return const CompletionRejectedTaskNotFound();

      final todaysOccurrences =
          _generator.occurrencesFor(task, DateRange(today, today));
      if (!todaysOccurrences.any((o) => o.slot == slot)) {
        return const CompletionRejectedNotScheduled();
      }

      final existing = await (_db.select(_db.completions)
            ..where((c) =>
                c.taskId.equals(taskId) &
                c.occurrenceDate.equalsValue(today) &
                c.slot.equals(slot) &
                c.deletedAt.isNull()))
          .getSingleOrNull();
      if (existing != null) return const CompletionRejectedAlreadyCompleted();

      final streakLength = await _streakLengthIncludingThis(task, today, slot);
      final isPerfectDay = await _isFinalOccurrenceOfDay(
        excludingTaskId: taskId,
        excludingSlot: slot,
        today: today,
      );
      final points = _points.pointsForCompletion(
        streakLengthIncludingThis: streakLength,
        isPerfectDayFinalOccurrence: isPerfectDay,
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
                updatedAt: now,
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

  /// The task's current streak as of today, simulating this slot (and any
  /// other slots already done today) as complete.
  Future<int> _streakLengthIncludingThis(
    Task task,
    LocalDate today,
    int slot,
  ) async {
    final taskCompletions = await (_db.select(_db.completions)
          ..where((c) => c.taskId.equals(task.id) & c.deletedAt.isNull()))
        .get();
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

  /// Sync tombstone delete: rows are never hard-deleted.
  Future<void> tombstoneDelete(String completionId) async {
    final now = _clock.nowEpochMillis();
    await (_db.update(_db.completions)
          ..where((c) => c.id.equals(completionId)))
        .write(CompletionsCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  /// Total altitude: sum of points_awarded over non-tombstoned completions.
  Future<int> totalAltitude() async {
    final rows = await (_db.select(_db.completions)
          ..where((c) => c.deletedAt.isNull()))
        .get();
    return _points.totalAltitude(rows.map((c) => c.pointsAwarded));
  }
}
