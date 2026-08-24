import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../clock.dart';
import '../models/local_date.dart';
import '../providers.dart';
import '../repo/completion_repository.dart';
import '../repo/task_repository.dart';
import '../services/home_service.dart';
import '../services/streak_service.dart';

/// Listens to database updates via [HomeService] and pushes refreshed
/// [WidgetSnapshot]s to native home screen widgets via [WidgetUpdater].
class WidgetTrigger {
  final WidgetUpdater _updater;
  final HomeService _homeService;
  final CompletionRepository _completionRepo;
  final StreakService _streakService;
  final TaskRepository _taskRepo;
  final Clock _clock;

  StreamSubscription<HomeSnapshot>? _sub;

  WidgetTrigger({
    required WidgetUpdater updater,
    required HomeService homeService,
    required CompletionRepository completionRepo,
    required StreakService streakService,
    required TaskRepository taskRepo,
    required Clock clock,
  })  : _updater = updater,
        _homeService = homeService,
        _completionRepo = completionRepo,
        _streakService = streakService,
        _taskRepo = taskRepo,
        _clock = clock;

  /// Starts listening to today's occurrences stream to keep widgets fresh.
  void start() {
    _sub ??= _homeService.watchToday().listen((homeSnapshot) {
      unawaited(_updateFromHomeSnapshot(homeSnapshot));
    });
  }

  /// Manually builds and pushes the latest snapshot (e.g. on app resume).
  Future<void> updateNow() async {
    final homeSnapshot = await _homeService.buildSnapshot();
    await _updateFromHomeSnapshot(homeSnapshot);
  }

  Future<void> _updateFromHomeSnapshot(HomeSnapshot home) async {
    final altitude = await _completionRepo.totalAltitude();
    final today = _clock.today();

    // Determine the highest active streak across active tasks
    final tasks = await _taskRepo.activeTasks();
    final liveCompletions =
        await _completionRepo.liveCompletionsGroupedByTask();

    var maxStreak = 0;
    for (final task in tasks) {
      final taskCompletions = liveCompletions[task.id] ?? const [];
      final done = <(LocalDate, int)>{
        for (final c in taskCompletions) (c.occurrenceDate, c.slot),
      };
      final s = _streakService.currentStreak(
        task,
        today,
        (d, slot) => done.contains((d, slot)),
      );
      if (s > maxStreak) maxStreak = s;
    }

    final remainingCount = home.totalCount - home.doneCount;
    final isAllCompleted = home.totalCount > 0 && remainingCount <= 0;

    // Next uncompleted occurrence
    HomeOccurrenceCard? nextCard;
    for (final card in home.cards) {
      if (card.status == HomeCardStatus.due ||
          card.status == HomeCardStatus.scheduled) {
        nextCard = card;
        break;
      }
    }

    final snapshot = WidgetSnapshot(
      remainingCount: remainingCount < 0 ? 0 : remainingCount,
      totalCount: home.totalCount,
      activeStreak: maxStreak,
      altitude: altitude,
      nextTaskId: nextCard?.taskId,
      nextTaskTitle: nextCard?.taskTitle,
      nextTaskSlot: nextCard?.slot ?? 0,
      nextTaskDueTime: nextCard?.dueTime,
      nextTaskCairnLabel: nextCard != null
          ? 'Cairn ${nextCard.currentCairnIndex} · ${nextCard.stoneCount} stones'
          : null,
      isAllCompleted: isAllCompleted,
    );

    await _updater.updateSnapshot(snapshot);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

/// Provider for [WidgetTrigger].
final widgetTriggerProvider = Provider<WidgetTrigger>((ref) {
  final trigger = WidgetTrigger(
    updater: ref.watch(widgetUpdaterProvider),
    homeService: ref.watch(homeServiceProvider),
    completionRepo: ref.watch(completionRepositoryProvider),
    streakService: ref.watch(streakServiceProvider),
    taskRepo: ref.watch(taskRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
  trigger.start();
  ref.onDispose(trigger.dispose);
  return trigger;
});
