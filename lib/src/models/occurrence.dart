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

/// Parses one `due_times` entry (a 24-hour `"HH:mm"` string) into a throwaway
/// [DateTime] carrying only that hour and minute; the date fields are
/// arbitrary and must not be read.
///
/// Lives here, beside [slotCountOf], because `due_times` and its `"HH:mm"`
/// encoding are domain data, not presentation: the UI formats the result for
/// display (`formatTimeOfDay`), but the repositories and the notification
/// planner parse it to decide *when things happen*, which is domain logic.
/// It previously sat in `new_habit_times_editor.dart`, which meant the repo
/// and service layers had to import from `lib/src/ui/` to reach it - a
/// dependency direction nothing else in those layers has.
DateTime timeOfDayFromHHmm(String hhmm) {
  final parts = hhmm.split(':');
  return DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
}
