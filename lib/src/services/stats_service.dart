import '../clock.dart';
import '../db/database.dart';
import '../models/local_date.dart';
import '../models/proof_verdict.dart';
import '../repo/completion_repository.dart';
import '../repo/task_repository.dart';
import 'cairn_grouping.dart';
import 'occurrence_generator.dart';
import 'streak_service.dart';

/// One weekday bar in the Stats screen's "This week" chart.
class StatsWeekdayBar {
  final LocalDate date;

  /// Sum, across every active task, of that day's scheduled occurrences.
  final int scheduled;

  /// Live (non-tombstoned, verified or pending) completions recorded on
  /// [date], across all tasks.
  final int done;

  /// Whether [date] is strictly after today - the Stats screen renders this
  /// bar with a faint, low fill regardless of [scheduled]/[done] (see
  /// `stats_screen.dart`'s doc comment on the future-bar treatment).
  final bool isFuture;

  const StatsWeekdayBar({
    required this.date,
    required this.scheduled,
    required this.done,
    required this.isFuture,
  });
}

/// One row in the Stats screen's "Current streaks" list.
class StatsStreak {
  final String taskTitle;
  final int days;

  const StatsStreak({required this.taskTitle, required this.days});
}

/// Everything the Stats screen shows, computed fresh from the repositories -
/// see `Cairn Stats.dc.html`.
class StatsSnapshot {
  /// Total live (non-tombstoned) completions across every task - verified
  /// or pending alike, and regardless of whether the owning task is still
  /// active: a stone already placed keeps counting toward this lifetime
  /// total even if its task is later archived. A stone counts even while
  /// still awaiting verification.
  final int stonesPlaced;

  /// Sum, over the SAME population as [stonesPlaced] (every task with at
  /// least one live completion, active or archived or since-deleted alike),
  /// of the number of *capped* cairns in that task's history
  /// ([CairnGrouping.cairnsFor]'s `capped` status only - not `growing` or
  /// `broken`): "built" means a finished, 10-stone monument. Using the same
  /// population as [stonesPlaced] guarantees the two can never disagree on
  /// which tasks count.
  final int cairnsBuilt;

  final int proofsUsedToday;
  final int dailyCap;

  /// The current Monday..Sunday week containing today, oldest (Monday)
  /// first.
  final List<StatsWeekdayBar> week;

  /// Sum of [StatsWeekdayBar.done] across [week].
  final int weekDone;

  /// Sum of [StatsWeekdayBar.scheduled] across [week].
  final int weekTotal;

  /// One entry per active task with a live streak of at least one day,
  /// ordered by [TaskRepository.cairnNumbers] (creation order, the same
  /// ordering Home's own cards use).
  final List<StatsStreak> streaks;

  const StatsSnapshot({
    required this.stonesPlaced,
    required this.cairnsBuilt,
    required this.proofsUsedToday,
    required this.dailyCap,
    required this.week,
    required this.weekDone,
    required this.weekTotal,
    required this.streaks,
  });
}

/// Assembles [StatsSnapshot] from the repositories and keeps it live:
/// [watchStats] re-emits a freshly-recomputed snapshot whenever the tasks or
/// completions tables change - same reactivity recipe as
/// `HomeService.watchToday` (see that method's doc comment for the
/// rationale behind watching a trigger query rather than hand-combining
/// typed streams).
class StatsService {
  final AppDatabase _db;
  final TaskRepository _taskRepo;
  final CompletionRepository _completionRepo;
  final OccurrenceGenerator _generator;
  final StreakService _streaks;
  final Clock _clock;
  final CairnGrouping _cairns;
  final ProofPolicy _policy;

  const StatsService(
    this._db,
    this._taskRepo,
    this._completionRepo,
    this._generator,
    this._streaks,
    this._clock, {
    CairnGrouping cairns = const CairnGrouping(),
    ProofPolicy policy = const ProofPolicy(),
  })  : _cairns = cairns,
        _policy = policy;

  Stream<StatsSnapshot> watchStats() {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.tasks, _db.completions},
        )
        .watch()
        .asyncMap((_) => _buildSnapshot());
  }

  /// One-shot equivalent of [watchStats], for callers that don't need
  /// reactivity (e.g. tests asserting a single snapshot).
  Future<StatsSnapshot> buildSnapshot() => _buildSnapshot();

  Future<StatsSnapshot> _buildSnapshot() async {
    final today = _clock.today();

    // Every task's live completions in one query, grouped by taskId (shared
    // by stonesPlaced/cairnsBuilt/streaks below) - same read HomeService's
    // own snapshot build uses to avoid one query per task.
    final completionsByTask = await _completionRepo.liveCompletionsGroupedByTask();

    final stonesPlaced = completionsByTask.values.fold<int>(
      0,
      (sum, completions) => sum + completions.length,
    );

    final activeTasks = await _taskRepo.activeTasks();
    final cairnNumbers = await _taskRepo.cairnNumbers();
    final sortedTasks = [...activeTasks]..sort(
        (a, b) =>
            (cairnNumbers[a.id] ?? 0).compareTo(cairnNumbers[b.id] ?? 0),
      );

    // cairnsBuilt runs over every task that appears in completionsByTask -
    // the same population stonesPlaced sums over - resolved ignoring
    // archived/deletedAt so an archived (or since-deleted) task's already
    // -placed stones keep contributing their capped cairns here, exactly as
    // they already do for stonesPlaced.
    final tasksWithCompletions =
        await _taskRepo.tasksByIds(completionsByTask.keys);
    var cairnsBuilt = 0;
    for (final task in tasksWithCompletions) {
      final liveCompletions = completionsByTask[task.id] ?? const [];
      final cairns = _cairns.cairnsFor(
        task: task,
        today: today,
        liveCompletions: liveCompletions,
      );
      cairnsBuilt += cairns.where((c) => c.status == CairnStatus.capped).length;
    }

    final streaks = <StatsStreak>[];
    for (final task in sortedTasks) {
      final liveCompletions = completionsByTask[task.id] ?? const [];

      final doneSlots = <(LocalDate, int)>{
        for (final c in liveCompletions) (c.occurrenceDate, c.slot),
      };
      final streakDays = _streaks.currentStreak(
        task,
        today,
        (date, slot) => doneSlots.contains((date, slot)),
      );
      if (streakDays >= 1) {
        streaks.add(StatsStreak(taskTitle: task.title, days: streakDays));
      }
    }

    final proofsUsedToday = await _completionRepo.successfulProofsToday();

    // Per-day live-completion counts for the week, bucketed in memory from
    // the `completionsByTask` already fetched above. Its rows are the same
    // live (non-tombstoned), all-task, any-verification-status set that
    // `liveCompletionsForDate` returns for a single day, so counting them by
    // occurrence_date here yields identical per-day totals with no extra
    // queries (previously one `liveCompletionsForDate` round-trip per weekday).
    final doneByDate = <LocalDate, int>{};
    for (final completions in completionsByTask.values) {
      for (final c in completions) {
        doneByDate[c.occurrenceDate] = (doneByDate[c.occurrenceDate] ?? 0) + 1;
      }
    }

    final weekStart = today.addDays(-(today.weekday - 1));
    final week = <StatsWeekdayBar>[];
    var weekDone = 0;
    var weekTotal = 0;
    for (var i = 0; i < 7; i++) {
      final date = weekStart.addDays(i);
      var scheduled = 0;
      for (final task in sortedTasks) {
        scheduled += _generator.occurrencesFor(task, DateRange(date, date)).length;
      }
      final doneCount = doneByDate[date] ?? 0;
      week.add(StatsWeekdayBar(
        date: date,
        scheduled: scheduled,
        done: doneCount,
        isFuture: date.isAfter(today),
      ));
      weekDone += doneCount;
      weekTotal += scheduled;
    }

    return StatsSnapshot(
      stonesPlaced: stonesPlaced,
      cairnsBuilt: cairnsBuilt,
      proofsUsedToday: proofsUsedToday,
      dailyCap: _policy.dailyCap,
      week: week,
      weekDone: weekDone,
      weekTotal: weekTotal,
      streaks: streaks,
    );
  }
}
