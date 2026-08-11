import '../clock.dart';
import '../models/local_date.dart';
import '../notifications/pending_notification.dart';
import '../repo/completion_repository.dart';
import '../repo/settings_repository.dart';
import '../repo/task_repository.dart';
import '../models/occurrence.dart' show timeOfDayFromHHmm;
import 'notification_strings.dart';
import 'occurrence_generator.dart';
import 'streak_service.dart';

/// Computes the set of `PendingNotification`s Cairn wants scheduled right
/// now, for a rolling window of upcoming days. Pure, deterministic given the
/// current database state and [Clock]: no plugin calls, no UI, no
/// permission handling - this is the scheduling *decision*, not the act of
/// posting anything (that's `NotificationScheduler`'s job,
/// `lib/src/notifications/notification_scheduler.dart`).
///
/// Two notification kinds only (see [NotificationKind]):
///
///  1. **Per-occurrence reminders**: for each scheduled, not-yet-completed
///     occurrence in the window, fire at that task's own `due_times` entry
///     for the slot, or [SettingsRepository.defaultReminderTime] when the
///     task has no due times (a single untimed slot 0, per AGENTS.md's
///     "an occurrence is (task, localDate, slot)" rule).
///  2. **Streak-at-risk warnings**: at most one per task per day, fired in
///     the evening ([eveningWarningHour]), only for a task whose *current*
///     streak (per [StreakService.currentStreak] - i.e. not yet counting
///     today, which is still open) is at least 1 and which still has an
///     incomplete scheduled occurrence today. If today goes unproven, that
///     streak breaks tomorrow; this is the nudge to prevent that.
///
/// Deliberately no end-of-day "you have N unproven habits" digest - see the
/// work order this shipped under for the rationale (friction without
/// nagging).
///
/// Reuses the existing [OccurrenceGenerator] and [StreakService] rather than
/// reimplementing either, per AGENTS.md. "Now"/"today" always come from the
/// injected [Clock], never `DateTime.now()`.
class NotificationPlanner {
  /// How many days ahead (inclusive of today) to plan reminders for. The app
  /// cannot schedule forever, so it re-plans on foreground and after
  /// relevant database changes (see `NotificationTrigger`,
  /// `lib/src/notifications/notification_trigger.dart`) rather than trying
  /// to schedule the task's entire future up front.
  static const int rollingWindowDays = 14;

  /// Fixed local hour (24-hour, on the hour) the streak-at-risk warning
  /// fires at, when it fires at all.
  static const int eveningWarningHour = 20;

  final TaskRepository _taskRepo;
  final CompletionRepository _completionRepo;
  final SettingsRepository _settings;
  final OccurrenceGenerator _generator;
  final StreakService _streaks;
  final Clock _clock;
  final NotificationStrings _strings;

  const NotificationPlanner(
    this._taskRepo,
    this._completionRepo,
    this._settings,
    this._generator,
    this._streaks,
    this._clock,
    this._strings,
  );

  /// Builds the current plan. Returns the empty list when
  /// [SettingsRepository.remindersEnabled] is false, so the caller
  /// (`NotificationTrigger`) can pass that straight to
  /// `NotificationScheduler.scheduleAll`, which clears everything
  /// previously scheduled.
  Future<List<PendingNotification>> plan() async {
    if (!await _settings.remindersEnabled()) return const [];

    final today = _clock.today();
    // A naive local wall-clock instant, deliberately: see
    // PendingNotification.scheduledFor's doc comment for why this whole
    // seam stays in "local wall clock, no timezone object" terms. This is
    // only valid to compare against instants built the same way (below),
    // which is exactly how the rest of this method builds them.
    final now = DateTime.fromMillisecondsSinceEpoch(_clock.nowEpochMillis());
    final defaultReminderTime = await _settings.defaultReminderTime();
    final streakWarningsEnabled = await _settings.streakWarningsEnabled();

    // activeTasks() already excludes archived and tombstoned tasks; each
    // task's own start_date/end_date bound is applied inside the generator
    // itself (scheduledDatesFor intersects the requested window with the
    // task's own active window) - between the two, archived, ended, and
    // deleted tasks all naturally produce no occurrences here, with no
    // separate filtering needed.
    final tasks = await _taskRepo.activeTasks();
    final completionsByTask = await _completionRepo.liveCompletionsGroupedByTask();
    final windowEnd = today.addDays(rollingWindowDays - 1);

    final notifications = <PendingNotification>[];

    for (final task in tasks) {
      final liveCompletions = completionsByTask[task.id] ?? const [];
      final doneSlots = <(LocalDate, int)>{
        for (final c in liveCompletions) (c.occurrenceDate, c.slot),
      };

      // This task's own reminder instants scheduled for TODAY specifically
      // (a subset of what gets added to `notifications` below), tracked
      // separately so the streak-warning suppression check just below can
      // see them without re-deriving anything.
      final todaysReminderInstants = <DateTime>[];

      final occurrences =
          _generator.occurrencesFor(task, DateRange(today, windowEnd));
      for (final occ in occurrences) {
        // Never remind for something already done: the single most
        // important rule here (see this class's own work order) - reminding
        // someone to do what they already did is what makes people disable
        // notifications permanently.
        if (doneSlots.contains((occ.date, occ.slot))) continue;

        final timeStr = occ.time ?? defaultReminderTime;
        final timeOfDay = timeOfDayFromHHmm(timeStr);
        final instant = DateTime(
          occ.date.year,
          occ.date.month,
          occ.date.day,
          timeOfDay.hour,
          timeOfDay.minute,
        );
        // Never schedule in the past: anything at or before now is dropped.
        if (!instant.isAfter(now)) continue;

        notifications.add(PendingNotification(
          id: pendingNotificationId(
              task.id, occ.date, occ.slot, NotificationKind.reminder),
          kind: NotificationKind.reminder,
          scheduledFor: instant,
          title: _strings.reminderTitle,
          body: _strings.reminderBody(task.title),
          payload: NotificationPayload(
            taskId: task.id,
            occurrenceDate: occ.date,
            slot: occ.slot,
          ).encode(),
        ));

        if (occ.date == today) todaysReminderInstants.add(instant);
      }

      if (!streakWarningsEnabled) continue;

      // The *current* streak - i.e. NOT counting today, which is still open
      // (StreakService.currentStreak's own "today counts as pending"
      // contract) - is exactly "how many consecutive days this streak has
      // going into today", so >= 1 here means today is the day that, left
      // unproven, breaks it.
      final streakDays = _streaks.currentStreak(
        task,
        today,
        (date, slot) => doneSlots.contains((date, slot)),
      );
      if (streakDays < 1) continue;

      final todaysOccurrences =
          _generator.occurrencesFor(task, DateRange(today, today));
      final incompleteToday = todaysOccurrences
          .where((o) => !doneSlots.contains((o.date, o.slot)))
          .toList();
      if (incompleteToday.isEmpty) continue;

      final warningInstant = DateTime(
        today.year,
        today.month,
        today.day,
        eveningWarningHour,
      );
      // Never if that hour has already passed today.
      if (!warningInstant.isAfter(now)) continue;

      // Never for a task that also has a reminder still pending later that
      // same evening - a warning and a reminder minutes apart is nagging.
      // "Later" is relative to the warning's own instant, not just "later
      // than now": a reminder earlier in the day (already fired or due
      // before the evening hour) is a separate, unrelated nudge and does not
      // suppress this one.
      final hasLaterReminderTonight =
          todaysReminderInstants.any((t) => !t.isBefore(warningInstant));
      if (hasLaterReminderTonight) continue;

      // Routes a tap on the warning into the first still-incomplete slot
      // today - a concrete, deterministic occurrence to open the camera
      // for, in due-time order (ascending slot index, matching how the
      // occurrence generator itself orders slots).
      final targetSlot = incompleteToday.first.slot;

      notifications.add(PendingNotification(
        id: pendingNotificationId(
            task.id, today, 0, NotificationKind.streakWarning),
        kind: NotificationKind.streakWarning,
        scheduledFor: warningInstant,
        title: _strings.streakWarningTitle,
        body: _strings.streakWarningBody(task.title, streakDays),
        payload: NotificationPayload(
          taskId: task.id,
          occurrenceDate: today,
          slot: targetSlot,
        ).encode(),
      ));
    }

    return notifications;
  }
}
