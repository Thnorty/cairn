import '../db/database.dart';
import '../models/local_date.dart';
import '../models/occurrence.dart';
import 'occurrence_generator.dart';

/// A date is "complete" iff every slot of that date has a non-tombstoned
/// completion. Callers supply this as a lookup so the service stays free of
/// database access (pure, easy to test).
typedef IsSlotComplete = bool Function(LocalDate date, int slot);

/// Computes streaks by walking scheduled dates backward from today. Streaks
/// are never stored: always derived on read.
class StreakService {
  final OccurrenceGenerator _generator;

  const StreakService([this._generator = const OccurrenceGenerator()]);

  /// Consecutive complete scheduled dates ending at (or just before) today.
  ///
  /// Today counts as "pending" rather than a break if it isn't fully done
  /// yet: the walk simply skips it. The streak only breaks on a
  /// fully-elapsed scheduled date that's incomplete. Non-scheduled dates
  /// (e.g. Tuesday for a Mon/Wed/Fri task) are skipped, not misses.
  int currentStreak(
    Task task,
    LocalDate today,
    IsSlotComplete isSlotComplete,
  ) {
    final scheduled = _scheduledDatesUpTo(task, today);
    if (scheduled.isEmpty) return 0;

    var streak = 0;
    for (var i = scheduled.length - 1; i >= 0; i--) {
      final date = scheduled[i];
      final complete = _isDateComplete(task, date, isSlotComplete);
      if (date == today) {
        if (!complete) continue; // pending, doesn't break the streak
        streak++;
        continue;
      }
      if (!complete) break;
      streak++;
    }
    return streak;
  }

  /// Longest run of consecutive complete scheduled dates in the task's
  /// history (falls out of the same forward walk, ignoring the
  /// today-pending exception since all past dates have fully elapsed).
  int longestStreak(
    Task task,
    LocalDate today,
    IsSlotComplete isSlotComplete,
  ) {
    final scheduled = _scheduledDatesUpTo(task, today);
    var longest = 0;
    var running = 0;
    for (final date in scheduled) {
      final complete = _isDateComplete(task, date, isSlotComplete);
      if (complete) {
        running++;
        longest = running > longest ? running : longest;
      } else if (date != today) {
        running = 0;
      }
      // If today is incomplete, it's pending, not a break: leave `running`
      // as-is without resetting it.
    }
    return longest;
  }

  bool _isDateComplete(
    Task task,
    LocalDate date,
    IsSlotComplete isSlotComplete,
  ) {
    final slots = slotCountOf(task);
    for (var slot = 0; slot < slots; slot++) {
      if (!isSlotComplete(date, slot)) return false;
    }
    return true;
  }

  List<LocalDate> _scheduledDatesUpTo(Task task, LocalDate today) {
    final start = task.startDate;
    if (start.isAfter(today)) return const [];
    return _generator.scheduledDatesFor(task, DateRange(start, today));
  }
}
