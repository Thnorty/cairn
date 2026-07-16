import '../clock.dart';
import '../db/database.dart';
import '../repo/completion_repository.dart';
import '../repo/task_repository.dart';
import 'cairn_grouping.dart';
import 'points_service.dart';

/// One entry in the Trail screen's habit-selector chip row.
class TrailTaskChip {
  final String taskId;
  final String title;

  const TrailTaskChip({required this.taskId, required this.title});
}

/// Everything the Trail screen shows, computed fresh from the repositories -
/// see `Cairn Trail.dc.html`. [cairns] is scoped to the selected task;
/// [altitude]/[rank] are app-wide (see their own doc comments).
class TrailSnapshot {
  /// One chip per active task, ordered the same way Home orders task cards
  /// (by [TaskRepository.cairnNumbers]).
  final List<TrailTaskChip> chips;

  /// The task this snapshot's [cairns] describes, or null when there are no
  /// active tasks at all ([chips] is then also empty).
  final String? selectedTaskId;
  final String? selectedTaskTitle;

  /// The selected task's whole cairn history, oldest first (index 1 is the
  /// trailhead) - the same ordering [CairnGrouping.cairnsFor] returns. The
  /// screen, not this service, decides display order (newest at the top).
  final List<TaskCairn> cairns;

  /// [CompletionRepository.totalAltitude]: the app-wide verified metres
  /// total, exactly the figure Profile's hero shows - not scoped to
  /// [selectedTaskId]. Switching the habit-selector chip changes [cairns]
  /// but never this: the rank pill is deliberately global (see this run's
  /// spec/report), so completing *any* task moves it, not just the one
  /// currently displayed.
  final int altitude;

  /// [PointsService.rankFor] resolved from [altitude] (global, not
  /// per-task).
  final Rank rank;

  const TrailSnapshot({
    required this.chips,
    required this.selectedTaskId,
    required this.selectedTaskTitle,
    required this.cairns,
    required this.altitude,
    required this.rank,
  });
}

/// Assembles [TrailSnapshot] from [TaskRepository]/[CompletionRepository] and
/// keeps it live: [watchTrail] re-emits a freshly-recomputed snapshot
/// whenever the tasks or completions tables change (a task added/archived, a
/// completion recorded elsewhere, or a pending proof resolving in the
/// background via `ProofRetryTrigger`), so the Trail screen never needs a
/// manual refresh - same reactivity recipe as `HomeService.watchToday` (see
/// that method's doc comment for the rationale behind watching a trigger
/// query rather than hand-combining typed streams).
class TrailService {
  final AppDatabase _db;
  final TaskRepository _taskRepo;
  final CompletionRepository _completionRepo;
  final PointsService _points;
  final Clock _clock;
  final CairnGrouping _cairns;

  const TrailService(
    this._db,
    this._taskRepo,
    this._completionRepo,
    this._points,
    this._clock, {
    CairnGrouping cairns = const CairnGrouping(),
  }) : _cairns = cairns;

  /// [selectedTaskId] names the task whose trail to show; when it no longer
  /// names an active task (null, a stale id from an archived/deleted task,
  /// or simply not yet chosen) the first task (by cairn number) is shown
  /// instead - see [_effectiveTask]'s doc comment.
  Stream<TrailSnapshot> watchTrail({String? selectedTaskId}) {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.tasks, _db.completions},
        )
        .watch()
        .asyncMap((_) => _buildSnapshot(selectedTaskId));
  }

  /// One-shot equivalent of [watchTrail], for callers that don't need
  /// reactivity (e.g. tests asserting a single snapshot).
  Future<TrailSnapshot> buildSnapshot({String? selectedTaskId}) =>
      _buildSnapshot(selectedTaskId);

  Future<TrailSnapshot> _buildSnapshot(String? selectedTaskId) async {
    final tasks = await _taskRepo.activeTasks();
    final cairnNumbers = await _taskRepo.cairnNumbers();

    final sortedTasks = [...tasks]..sort(
        (a, b) =>
            (cairnNumbers[a.id] ?? 0).compareTo(cairnNumbers[b.id] ?? 0),
      );

    final chips = [
      for (final task in sortedTasks)
        TrailTaskChip(taskId: task.id, title: task.title),
    ];

    if (sortedTasks.isEmpty) {
      return TrailSnapshot(
        chips: const [],
        selectedTaskId: null,
        selectedTaskTitle: null,
        cairns: const [],
        altitude: 0,
        rank: _points.rankFor(0),
      );
    }

    final effective = _effectiveTask(sortedTasks, selectedTaskId);

    final today = _clock.today();
    final liveCompletions =
        await _completionRepo.liveCompletionsForTask(effective.id);
    final cairns = _cairns.cairnsFor(
      task: effective,
      today: today,
      liveCompletions: liveCompletions,
    );
    // Global, not per-task (see TrailSnapshot.altitude's doc comment): the
    // rank pill is the same app-wide total Profile's hero shows, so
    // completing any task moves it, not just whichever one is selected.
    final altitude = await _completionRepo.totalAltitude();
    final rank = _points.rankFor(altitude);

    return TrailSnapshot(
      chips: chips,
      selectedTaskId: effective.id,
      selectedTaskTitle: effective.title,
      cairns: cairns,
      altitude: altitude,
      rank: rank,
    );
  }

  /// [selectedTaskId] when it still names one of [sortedTasks] (an active
  /// task), else the first task in [sortedTasks] (the same default Home's
  /// own card ordering would put first).
  Task _effectiveTask(List<Task> sortedTasks, String? selectedTaskId) {
    if (selectedTaskId != null) {
      for (final task in sortedTasks) {
        if (task.id == selectedTaskId) return task;
      }
    }
    return sortedTasks.first;
  }
}
