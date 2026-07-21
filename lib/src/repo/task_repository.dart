import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../clock.dart';
import '../db/database.dart';
import '../models/local_date.dart';

/// Matches 24-hour "HH:mm", e.g. "08:00", "20:00".
final RegExp _hhMmPattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

/// Valid values for `month_nth`: 1st..4th, or -1 for "Last".
const List<int> _validMonthNths = [1, 2, 3, 4, -1];

/// Creates, edits, archives, and tombstones tasks. All task writes go
/// through here so `updated_at`/`deleted_at` stay correct for sync, and so
/// invalid recurrence data can never be persisted (e.g. a monthDay of 0 would
/// silently generate an invalid occurrence date like "2026-07-00" downstream
/// in the occurrence generator if it weren't rejected here).
class TaskRepository {
  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;
  final String? Function() _currentUserId;

  /// [currentUserId] is read at every insert to stamp `user_id` (WO-4:
  /// Phase 2b anonymous auth). Defaults to a getter that always returns
  /// null, so tests and any caller that hasn't wired auth yet keep writing
  /// rows with `user_id = NULL`, exactly as before this parameter existed.
  TaskRepository(
    this._db,
    this._clock, {
    Uuid? uuid,
    String? Function() currentUserId = _noCurrentUserId,
  })  : _uuid = uuid ?? const Uuid(),
        _currentUserId = currentUserId;

  static String? _noCurrentUserId() => null;

  Future<Task> createTask({
    required String title,
    String? description,
    required RecurrenceType recurrenceType,
    List<int>? weeklyDays,
    MonthlyMode? monthlyMode,
    int? monthDay,
    int? monthNth,
    int? monthWeekday,
    LocalDate? dueDate,
    List<String> dueTimes = const [],
    required LocalDate startDate,
    LocalDate? endDate,
    String? userId,
  }) async {
    _validate(
      recurrenceType: recurrenceType,
      weeklyDays: weeklyDays,
      monthlyMode: monthlyMode,
      monthDay: monthDay,
      monthNth: monthNth,
      monthWeekday: monthWeekday,
      dueDate: dueDate,
      dueTimes: dueTimes,
      startDate: startDate,
      endDate: endDate,
    );

    final now = _clock.nowEpochMillis();
    final task = TasksCompanion.insert(
      id: _uuid.v7(),
      title: title,
      description: Value(description),
      recurrenceType: recurrenceType,
      weeklyDays: Value(weeklyDays),
      monthlyMode: Value(monthlyMode),
      monthDay: Value(monthDay),
      monthNth: Value(monthNth),
      monthWeekday: Value(monthWeekday),
      dueDate: Value(dueDate),
      dueTimes: Value(dueTimes),
      startDate: startDate,
      endDate: Value(endDate),
      userId: Value(userId ?? _currentUserId()),
      createdAt: now,
      updatedAt: now,
      dirty: const Value(true),
    );
    await _db.into(_db.tasks).insert(task);
    return (_db.select(_db.tasks)..where((t) => t.id.equals(task.id.value)))
        .getSingle();
  }

  /// Applies a partial edit to a task, bumping `updated_at`.
  ///
  /// Loads the existing row (throwing [ArgumentError] if it doesn't exist or
  /// is tombstoned), merges [changes] onto it (present values in [changes]
  /// win over the existing row's values), and validates the merged result
  /// before writing anything, so an edit can never leave a task with
  /// inconsistent recurrence data.
  Future<void> editTask(String taskId, TasksCompanion changes) async {
    final existing = await (_db.select(_db.tasks)
          ..where((t) => t.id.equals(taskId) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (existing == null) {
      throw ArgumentError.value(
          taskId, 'taskId', 'task does not exist or is deleted');
    }

    final recurrenceType = changes.recurrenceType.present
        ? changes.recurrenceType.value
        : existing.recurrenceType;
    final weeklyDays = changes.weeklyDays.present
        ? changes.weeklyDays.value
        : existing.weeklyDays;
    final monthlyMode = changes.monthlyMode.present
        ? changes.monthlyMode.value
        : existing.monthlyMode;
    final monthDay =
        changes.monthDay.present ? changes.monthDay.value : existing.monthDay;
    final monthNth =
        changes.monthNth.present ? changes.monthNth.value : existing.monthNth;
    final monthWeekday = changes.monthWeekday.present
        ? changes.monthWeekday.value
        : existing.monthWeekday;
    final dueDate =
        changes.dueDate.present ? changes.dueDate.value : existing.dueDate;
    final dueTimes = changes.dueTimes.present
        ? changes.dueTimes.value
        : existing.dueTimes;
    final startDate = changes.startDate.present
        ? changes.startDate.value
        : existing.startDate;
    final endDate =
        changes.endDate.present ? changes.endDate.value : existing.endDate;

    _validate(
      recurrenceType: recurrenceType,
      weeklyDays: weeklyDays,
      monthlyMode: monthlyMode,
      monthDay: monthDay,
      monthNth: monthNth,
      monthWeekday: monthWeekday,
      dueDate: dueDate,
      dueTimes: dueTimes,
      startDate: startDate,
      endDate: endDate,
    );

    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      changes.copyWith(
        updatedAt: Value(_clock.nowEpochMillis()),
        dirty: const Value(true),
      ),
    );
  }

  /// Validates only the fields the chosen [recurrenceType] actually uses;
  /// extraneous fields for other recurrence types are ignored. Throws
  /// [ArgumentError] naming the offending field on any violation.
  void _validate({
    required RecurrenceType recurrenceType,
    List<int>? weeklyDays,
    MonthlyMode? monthlyMode,
    int? monthDay,
    int? monthNth,
    int? monthWeekday,
    LocalDate? dueDate,
    required List<String> dueTimes,
    required LocalDate startDate,
    LocalDate? endDate,
  }) {
    if (endDate != null && endDate.isBefore(startDate)) {
      throw ArgumentError.value(
          endDate, 'endDate', 'must not be before startDate');
    }

    switch (recurrenceType) {
      case RecurrenceType.weekly:
        if (weeklyDays == null || weeklyDays.isEmpty) {
          throw ArgumentError.value(
              weeklyDays, 'weeklyDays', 'is required for weekly recurrence');
        }
        if (weeklyDays.any((day) => day < 1 || day > 7)) {
          throw ArgumentError.value(weeklyDays, 'weeklyDays',
              'must contain only ISO weekdays in 1..7');
        }
        if (weeklyDays.toSet().length != weeklyDays.length) {
          throw ArgumentError.value(
              weeklyDays, 'weeklyDays', 'must not contain duplicates');
        }
        break;

      case RecurrenceType.monthly:
        if (monthlyMode == null) {
          throw ArgumentError.value(monthlyMode, 'monthlyMode',
              'is required for monthly recurrence');
        }
        switch (monthlyMode) {
          case MonthlyMode.dayOfMonth:
            if (monthDay == null || monthDay < 1 || monthDay > 31) {
              throw ArgumentError.value(
                  monthDay, 'monthDay', 'must be within 1..31');
            }
            break;
          case MonthlyMode.nthWeekday:
            if (!_validMonthNths.contains(monthNth)) {
              throw ArgumentError.value(
                  monthNth, 'monthNth', 'must be one of 1, 2, 3, 4, -1');
            }
            if (monthWeekday == null || monthWeekday < 1 || monthWeekday > 7) {
              throw ArgumentError.value(
                  monthWeekday, 'monthWeekday', 'must be within 1..7');
            }
            break;
        }
        break;

      case RecurrenceType.once:
        if (dueDate == null) {
          throw ArgumentError.value(
              dueDate, 'dueDate', 'is required for once recurrence');
        }
        if (dueDate.isBefore(startDate) ||
            (endDate != null && dueDate.isAfter(endDate))) {
          throw ArgumentError.value(
              dueDate, 'dueDate', 'must be within [startDate, endDate]');
        }
        break;

      case RecurrenceType.daily:
        break;
    }

    for (final time in dueTimes) {
      if (!_hhMmPattern.hasMatch(time)) {
        throw ArgumentError.value(
            time, 'dueTimes', 'must match 24-hour HH:mm format');
      }
    }
    if (dueTimes.toSet().length != dueTimes.length) {
      throw ArgumentError.value(
          dueTimes, 'dueTimes', 'must not contain duplicates');
    }
  }

  /// User-facing archive (hidden, not deleted).
  Future<void> archiveTask(String taskId, {bool archived = true}) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        archived: Value(archived),
        updatedAt: Value(_clock.nowEpochMillis()),
        dirty: const Value(true),
      ),
    );
  }

  /// Sync tombstone delete: rows are never hard-deleted.
  Future<void> tombstoneDelete(String taskId) async {
    final now = _clock.nowEpochMillis();
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  /// Active tasks: not archived, not tombstoned.
  Future<List<Task>> activeTasks() {
    return (_db.select(_db.tasks)
          ..where((t) => t.archived.equals(false) & t.deletedAt.isNull()))
        .get();
  }

  /// Each task's stable creation-order ordinal, 1-based among every
  /// non-tombstoned task (archived tasks included, so archiving one never
  /// renumbers another task's position). This is purely a task-*ordering*
  /// key - Home/Trail's own card/chip order - and is NOT the "Cairn N"
  /// displayed anywhere in the UI: that label is each task's own *current*
  /// per-task cairn (`CairnGrouping.currentCairn`, surfaced via
  /// `CompletionRepository.currentCairnFor`/`HomeService`/`TrailService`), a
  /// value that has nothing to do with when the task was created. `id` is a
  /// tiebreaker for tasks created in the same millisecond: it is *stable*
  /// (an id never changes, so a given database always produces the same
  /// ordinals and a user never sees a task's position shift between
  /// sessions) but *not* chronological within that tie. UUID v7's timestamp
  /// prefix is identical for ids created in the same millisecond, so
  /// everything after that prefix is random bits; ordering on `id` there is
  /// an arbitrary, consistent tiebreak, not a recovery of creation order.
  Future<Map<String, int>> cairnNumbers() async {
    final rows = await (_db.select(_db.tasks)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    return {
      for (var i = 0; i < rows.length; i++) rows[i].id: i + 1,
    };
  }

  /// Tasks matching [ids], regardless of archived/deletedAt status - the
  /// same "looked up ignoring deletedAt/archived" pattern
  /// `CompletionRepository.retryPendingVerifications`/`_retrySinglePending`
  /// use so a since-archived or since-deleted task still resolves. Used by
  /// `StatsService.cairnsBuilt` so an archived task's already-placed stones
  /// keep contributing capped cairns to that count, exactly as they already
  /// do for `stonesPlaced`. Order is unspecified; callers that care about
  /// order should re-sort.
  Future<List<Task>> tasksByIds(Iterable<String> ids) {
    final idList = ids.toList();
    if (idList.isEmpty) return Future.value(const []);
    return (_db.select(_db.tasks)..where((t) => t.id.isIn(idList))).get();
  }

  /// One-time backfill for rows created before the first successful
  /// anonymous sign-in (WO-4): stamps `user_id` on every row where it is
  /// currently NULL, so Phase 4's account upgrade carries the whole
  /// pre-auth history instead of starting from a blank slate.
  ///
  /// Idempotent and safe to call on every launch without any separate
  /// "already ran" flag: it only ever touches rows matching `user_id IS
  /// NULL`, so a row that already carries a (possibly different) user_id is
  /// never overwritten, and once every row has been stamped a second call
  /// matches zero rows and changes nothing.
  Future<int> backfillUserId(String userId) {
    return (_db.update(_db.tasks)..where((t) => t.userId.isNull())).write(
      TasksCompanion(
        userId: Value(userId),
        updatedAt: Value(_clock.nowEpochMillis()),
        dirty: const Value(true),
      ),
    );
  }
}
