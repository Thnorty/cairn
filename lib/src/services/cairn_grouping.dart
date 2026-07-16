import '../db/database.dart';
import '../models/local_date.dart';
import '../models/occurrence.dart';
import 'occurrence_generator.dart';
import 'points_service.dart';

/// Whether a per-task cairn is capped (full, `cairnCapStones` stones and
/// done), broken (a partial stack whose run ended in a missed scheduled
/// date), or growing (the current, still-being-built stack).
enum CairnStatus { capped, broken, growing }

/// One cairn in a task's history: a stack of up to
/// [PointsService.cairnCapStones] stones.
class TaskCairn {
  /// 1-based position across the whole returned list, oldest first.
  final int index;
  final int stoneCount;
  final CairnStatus status;

  /// True only for the very first cairn (index 1) in the task's history.
  final bool isTrailhead;

  /// Null only for a 0-stone growing cairn (the just-started next stack).
  final LocalDate? firstStoneDate;
  final LocalDate? lastStoneDate;

  const TaskCairn({
    required this.index,
    required this.stoneCount,
    required this.status,
    required this.isTrailhead,
    this.firstStoneDate,
    this.lastStoneDate,
  });

  @override
  String toString() =>
      'TaskCairn(#$index, $stoneCount stones, $status, trailhead: $isTrailhead)';
}

/// Groups a task's live completions into per-task "cairns": consecutive runs
/// of stones are chunked into stacks of [PointsService.cairnCapStones]; a
/// full stack is `capped`, an in-progress trailing stack on the still-alive
/// streak is `growing`, and a trailing partial stack whose run was cut short
/// by a missed scheduled date is `broken`.
///
/// Pure and database-free, in the style of [StreakService]: takes an
/// injected [OccurrenceGenerator] with a `const` default, so it is fully
/// unit-testable without a database.
class CairnGrouping {
  final OccurrenceGenerator _generator;

  const CairnGrouping([this._generator = const OccurrenceGenerator()]);

  /// Builds the ordered list of a task's cairns, oldest first (index 1 is
  /// the trailhead).
  ///
  /// Precondition: [liveCompletions] is already filtered to *this* task and
  /// to non-tombstoned rows (`deletedAt IS NULL`), verified and pending
  /// alike. This method does no such filtering itself.
  List<TaskCairn> cairnsFor({
    required Task task,
    required LocalDate today,
    required List<Completion> liveCompletions,
    int capStones = PointsService.cairnCapStones,
  }) {
    if (liveCompletions.isEmpty) return const [];

    final scheduled = _scheduledDatesUpTo(task, today);

    final doneSlots = <(LocalDate, int)>{
      for (final c in liveCompletions) (c.occurrenceDate, c.slot),
    };
    final slots = slotCountOf(task);
    bool isDateComplete(LocalDate date) {
      for (var slot = 0; slot < slots; slot++) {
        if (!doneSlots.contains((date, slot))) return false;
      }
      return true;
    }

    // A scheduled date is a break iff it's fully elapsed (strictly before
    // today - today-pending never breaks, exactly like streaks) and
    // incomplete. `scheduled` only contains genuinely scheduled dates, so
    // non-scheduled dates in between never register as breaks.
    final breakDates = <LocalDate>[
      for (final date in scheduled)
        if (date.isBefore(today) && !isDateComplete(date)) date,
    ];

    final stones = [...liveCompletions]..sort((a, b) {
        final byDate = a.occurrenceDate.compareTo(b.occurrenceDate);
        return byDate != 0 ? byDate : a.slot.compareTo(b.slot);
      });

    // Each stone's run index is the count of break dates strictly before its
    // occurrence date. A stone dated ON a break date is not yet past it, so
    // it stays in the run the break terminates; the next run starts at the
    // first stone dated after the break.
    int runIndexFor(LocalDate date) {
      var count = 0;
      for (final b in breakDates) {
        if (b.isBefore(date)) count++;
      }
      return count;
    }

    final runs = <int, List<Completion>>{};
    for (final stone in stones) {
      runs.putIfAbsent(runIndexFor(stone.occurrenceDate), () => []).add(stone);
    }
    final runKeys = runs.keys.toList()..sort();

    // The streak is alive iff no break date falls after the most recent
    // stone: nothing has broken it since the last thing that happened.
    final lastStoneDate = stones.last.occurrenceDate;
    final streakAlive = !breakDates.any((b) => b.isAfter(lastStoneDate));

    final unnumbered = <TaskCairn>[];
    for (var i = 0; i < runKeys.length; i++) {
      final isLastRun = i == runKeys.length - 1;
      final runStones = runs[runKeys[i]]!;
      final fullGroups = runStones.length ~/ capStones;
      final remainder = runStones.length % capStones;

      for (var g = 0; g < fullGroups; g++) {
        final group = runStones.sublist(g * capStones, (g + 1) * capStones);
        unnumbered.add(TaskCairn(
          index: 0,
          stoneCount: capStones,
          status: CairnStatus.capped,
          isTrailhead: false,
          firstStoneDate: group.first.occurrenceDate,
          lastStoneDate: group.last.occurrenceDate,
        ));
      }

      if (remainder > 0) {
        final group = runStones.sublist(fullGroups * capStones);
        final status = (isLastRun && streakAlive)
            ? CairnStatus.growing
            : CairnStatus.broken;
        unnumbered.add(TaskCairn(
          index: 0,
          stoneCount: remainder,
          status: status,
          isTrailhead: false,
          firstStoneDate: group.first.occurrenceDate,
          lastStoneDate: group.last.occurrenceDate,
        ));
      } else if (isLastRun && streakAlive) {
        // The run divided evenly: the just-started next cairn, with no
        // stones in it yet.
        unnumbered.add(const TaskCairn(
          index: 0,
          stoneCount: 0,
          status: CairnStatus.growing,
          isTrailhead: false,
          firstStoneDate: null,
          lastStoneDate: null,
        ));
      }
    }

    return [
      for (var i = 0; i < unnumbered.length; i++)
        TaskCairn(
          index: i + 1,
          stoneCount: unnumbered[i].stoneCount,
          status: unnumbered[i].status,
          isTrailhead: i == 0,
          firstStoneDate: unnumbered[i].firstStoneDate,
          lastStoneDate: unnumbered[i].lastStoneDate,
        ),
    ];
  }

  /// The stone count of the current `growing` cairn, or 0 when there isn't
  /// one (the streak is currently broken, so the next stone starts a fresh
  /// cairn). At most one `growing` cairn ever exists, and when it does, it is
  /// always the last cairn in [cairnsFor]'s result.
  int growingCairnStoneCount({
    required Task task,
    required LocalDate today,
    required List<Completion> liveCompletions,
    int capStones = PointsService.cairnCapStones,
  }) {
    final cairns = cairnsFor(
      task: task,
      today: today,
      liveCompletions: liveCompletions,
      capStones: capStones,
    );
    if (cairns.isEmpty) return 0;
    final last = cairns.last;
    return last.status == CairnStatus.growing ? last.stoneCount : 0;
  }

  /// The cairn a task is currently "on" for display: the one every
  /// "Cairn N · M stones" label in the app (Home's cards, the proof-outcome
  /// screens, Trail's own hero) should show. This is the single source of
  /// truth for that value - see CLAUDE.md's "Per-task cairns" rule.
  ///
  /// - No live completions at all: a brand-new task is "on Cairn 1 with 0
  ///   stones", even though [cairnsFor] itself returns an empty list for
  ///   this case (there is nothing to group yet).
  /// - The most recent cairn is a `growing` one with 0 stones (the
  ///   just-started next stack right after the previous one capped): return
  ///   the cairn immediately before it instead, so a task that just placed
  ///   its [capStones]th stone reads "Cairn N · 10 stones", not
  ///   "Cairn N+1 · 0 stones". [cairnsFor] guarantees a 0-stone growing
  ///   cairn is always preceded by a capped one, so the list has at least 2
  ///   entries whenever this applies; guarded defensively regardless.
  /// - Otherwise: the last cairn in [cairnsFor]'s result - the in-progress
  ///   growing cairn with at least 1 stone, or, when the streak is
  ///   currently broken, the most recent settled (`broken`) cairn.
  TaskCairn currentCairn({
    required Task task,
    required LocalDate today,
    required List<Completion> liveCompletions,
    int capStones = PointsService.cairnCapStones,
  }) {
    final cairns = cairnsFor(
      task: task,
      today: today,
      liveCompletions: liveCompletions,
      capStones: capStones,
    );

    if (cairns.isEmpty) {
      return const TaskCairn(
        index: 1,
        stoneCount: 0,
        status: CairnStatus.growing,
        isTrailhead: true,
      );
    }

    final last = cairns.last;
    if (last.status == CairnStatus.growing &&
        last.stoneCount == 0 &&
        cairns.length >= 2) {
      return cairns[cairns.length - 2];
    }
    return last;
  }

  List<LocalDate> _scheduledDatesUpTo(Task task, LocalDate today) {
    final start = task.startDate;
    if (start.isAfter(today)) return const [];
    return _generator.scheduledDatesFor(task, DateRange(start, today));
  }
}
