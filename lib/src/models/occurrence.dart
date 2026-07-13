import '../db/database.dart';
import 'local_date.dart';

/// A single completable unit: (task, local date, slot).
///
/// A task with `due_times = ["08:00","20:00"]` produces two occurrences per
/// scheduled date (slots 0 and 1); an empty `due_times` produces one untimed
/// occurrence (slot 0).
class Occurrence {
  final Task task;
  final LocalDate date;
  final int slot;

  /// The "HH:mm" due time for this slot, or null for an untimed slot.
  final String? time;

  const Occurrence({
    required this.task,
    required this.date,
    required this.slot,
    this.time,
  });

  @override
  String toString() => 'Occurrence(${task.id}, $date, slot $slot)';

  @override
  bool operator ==(Object other) =>
      other is Occurrence &&
      other.task.id == task.id &&
      other.date == date &&
      other.slot == slot;

  @override
  int get hashCode => Object.hash(task.id, date, slot);
}

/// Number of slots a task has per scheduled date (at least 1).
int slotCountOf(Task task) =>
    task.dueTimes.isEmpty ? 1 : task.dueTimes.length;
