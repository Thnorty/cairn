/// Data snapshot of today's habit status and user progress passed to native
/// home-screen widgets (Cairn Glance 2x2 and Next Habit 4x2).
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.remainingCount,
    required this.totalCount,
    required this.doneCount,
    required this.stonesThisWeek,
    required this.activeStreak,
    required this.altitude,
    required this.rankName,
    this.nextTaskId,
    this.nextTaskTitle,
    this.nextTaskSlot = 0,
    this.nextTaskDueTime,
    this.nextTaskCairnLabel,
    this.isAllCompleted = false,
  });

  /// The number of scheduled occurrences remaining to be proven today.
  final int remainingCount;

  /// Total number of scheduled occurrences for today.
  final int totalCount;

  /// Number of occurrences completed today.
  final int doneCount;

  /// Total completions across all habits in the current week.
  final int stonesThisWeek;

  /// The user's highest active streak count in days across live habits.
  final int activeStreak;

  /// Total cumulative metres climbed (verified altitude).
  final int altitude;

  /// The title of the user's current rank tier (e.g. "Pebble", "Ridge", "Summit").
  final String rankName;

  /// Task ID of the next uncompleted occurrence, if any.
  final String? nextTaskId;

  /// Title of the next uncompleted occurrence, if any.
  final String? nextTaskTitle;

  /// Slot index of the next uncompleted occurrence.
  final int nextTaskSlot;

  /// Formatted due time string (e.g. "09:00"), if configured.
  final String? nextTaskDueTime;

  /// Cairn progress label (e.g. "Cairn 2 · 4 stones"), if available.
  final String? nextTaskCairnLabel;

  /// Whether all scheduled habits for today have been completed.
  final bool isAllCompleted;

  /// Converts snapshot fields to a Key-Value map for `HomeWidget.saveWidgetData`.
  Map<String, Object> toWidgetData() {
    return {
      'remaining_count': remainingCount,
      'total_count': totalCount,
      'done_count': doneCount,
      'stones_this_week': stonesThisWeek,
      'active_streak': activeStreak,
      'altitude': altitude,
      'rank_name': rankName,
      'next_task_id': nextTaskId ?? '',
      'next_task_title': nextTaskTitle ?? '',
      'next_task_slot': nextTaskSlot,
      'next_task_due_time': nextTaskDueTime ?? '',
      'next_task_cairn_label': nextTaskCairnLabel ?? '',
      'is_all_completed': isAllCompleted,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WidgetSnapshot &&
          runtimeType == other.runtimeType &&
          remainingCount == other.remainingCount &&
          totalCount == other.totalCount &&
          doneCount == other.doneCount &&
          stonesThisWeek == other.stonesThisWeek &&
          activeStreak == other.activeStreak &&
          altitude == other.altitude &&
          rankName == other.rankName &&
          nextTaskId == other.nextTaskId &&
          nextTaskTitle == other.nextTaskTitle &&
          nextTaskSlot == other.nextTaskSlot &&
          nextTaskDueTime == other.nextTaskDueTime &&
          nextTaskCairnLabel == other.nextTaskCairnLabel &&
          isAllCompleted == other.isAllCompleted;

  @override
  int get hashCode => Object.hash(
        remainingCount,
        totalCount,
        doneCount,
        stonesThisWeek,
        activeStreak,
        altitude,
        rankName,
        nextTaskId,
        nextTaskTitle,
        nextTaskSlot,
        nextTaskDueTime,
        nextTaskCairnLabel,
        isAllCompleted,
      );
}
