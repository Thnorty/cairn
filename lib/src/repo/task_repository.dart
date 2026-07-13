import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../clock.dart';
import '../db/database.dart';
import '../models/local_date.dart';

/// Creates, edits, archives, and tombstones tasks. All task writes go
/// through here so `updated_at`/`deleted_at` stay correct for sync.
class TaskRepository {
  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  TaskRepository(this._db, this._clock, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

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
      userId: Value(userId),
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.tasks).insert(task);
    return (_db.select(_db.tasks)..where((t) => t.id.equals(task.id.value)))
        .getSingle();
  }

  /// Applies a partial edit to a task, bumping `updated_at`.
  Future<void> editTask(String taskId, TasksCompanion changes) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      changes.copyWith(updatedAt: Value(_clock.nowEpochMillis())),
    );
  }

  /// User-facing archive (hidden, not deleted).
  Future<void> archiveTask(String taskId, {bool archived = true}) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        archived: Value(archived),
        updatedAt: Value(_clock.nowEpochMillis()),
      ),
    );
  }

  /// Sync tombstone delete — rows are never hard-deleted.
  Future<void> tombstoneDelete(String taskId) async {
    final now = _clock.nowEpochMillis();
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Active tasks: not archived, not tombstoned.
  Future<List<Task>> activeTasks() {
    return (_db.select(_db.tasks)
          ..where((t) => t.archived.equals(false) & t.deletedAt.isNull()))
        .get();
  }
}
