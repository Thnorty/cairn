import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/local_date.dart';
import 'package:cairn/src/notifications/pending_notification.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/settings_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/notification_planner.dart';
import 'package:cairn/src/services/occurrence_generator.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/services/streak_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../helpers.dart';
import '../support/test_notification_strings.dart';

void main() {
  late AppDatabase db;
  late TaskRepository taskRepo;
  late SettingsRepository settings;

  setUp(() {
    db = inMemoryDatabase();
    taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 20)));
    settings = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// [today] at [hour]:[minute] as a naive local wall-clock [DateTime] -
  /// the exact same construction [NotificationPlanner] itself uses for
  /// `scheduledFor`, so comparisons in these tests never depend on the test
  /// runner's own machine timezone (`FixedClock.nowMillis` is built the same
  /// way below).
  DateTime instantAt(LocalDate date, int hour, [int minute = 0]) =>
      DateTime(date.year, date.month, date.day, hour, minute);

  /// A [FixedClock] pinned to [today], with "now" at [hour]:[minute] on that
  /// same date - built via the local-`DateTime`-to-millis round trip so it
  /// stays consistent with [NotificationPlanner]'s own
  /// `DateTime.fromMillisecondsSinceEpoch(clock.nowEpochMillis())` regardless
  /// of the machine's timezone (see `FixedClock`'s own doc comment: its
  /// default `nowMillis` is UTC-midnight-based and NOT safe for wall-clock
  /// comparisons like this).
  FixedClock clockAt(LocalDate today, int hour, [int minute = 0]) => FixedClock(
        today,
        nowMillis: instantAt(today, hour, minute).millisecondsSinceEpoch,
      );

  NotificationPlanner buildPlanner(Clock clock) {
    return NotificationPlanner(
      TaskRepository(db, clock),
      CompletionRepository(db, clock, verifier: FakeProofVerifier()),
      settings,
      const OccurrenceGenerator(),
      const StreakService(),
      clock,
      testNotificationStrings,
    );
  }

  /// Inserts a completion row directly (bypassing [CompletionRepository],
  /// whose no-back-filling guard only ever allows completing *today's* own
  /// occurrence) so a streak can be seeded on past dates - the same
  /// rationale `test/services/insights_service_test.dart`'s own
  /// `seedCompletion` documents.
  Future<void> seedCompletion({
    required String taskId,
    required LocalDate occurrenceDate,
    int slot = 0,
  }) async {
    await db.into(db.completions).insert(
          CompletionsCompanion.insert(
            id: const Uuid().v7(),
            taskId: taskId,
            occurrenceDate: occurrenceDate,
            slot: Value(slot),
            completedAt: 0,
            verificationStatus: const Value(VerificationStatus.verified),
            updatedAt: 0,
          ),
        );
  }

  final today = d(2026, 7, 20);

  group('reminders disabled', () {
    test('plan is empty when remindersEnabled is false (the default)',
        () async {
      await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: today,
      );
      final planner = buildPlanner(clockAt(today, 0, 1));

      expect(await planner.plan(), isEmpty);
    });
  });

  group('reminder time resolution', () {
    test('uses dueTimes[slot] for each slot when due_times is non-empty',
        () async {
      await settings.setRemindersEnabled(true);
      final task = await taskRepo.createTask(
        title: 'Meds',
        recurrenceType: RecurrenceType.daily,
        dueTimes: const ['08:00', '20:00'],
        startDate: today,
      );
      final planner = buildPlanner(clockAt(today, 0, 1));

      final plan = await planner.plan();
      final todays = plan.where((n) =>
          NotificationPayload.decode(n.payload).occurrenceDate == today &&
          NotificationPayload.decode(n.payload).taskId == task.id);

      final slot0 = todays.singleWhere(
          (n) => NotificationPayload.decode(n.payload).slot == 0);
      final slot1 = todays.singleWhere(
          (n) => NotificationPayload.decode(n.payload).slot == 1);
      expect(slot0.scheduledFor, instantAt(today, 8, 0));
      expect(slot1.scheduledFor, instantAt(today, 20, 0));
    });

    test('falls back to the configured default reminder time when '
        'due_times is empty', () async {
      await settings.setRemindersEnabled(true);
      await settings.setDefaultReminderTime('07:30');
      final task = await taskRepo.createTask(
        title: 'Journal',
        recurrenceType: RecurrenceType.daily,
        startDate: today,
      );
      final planner = buildPlanner(clockAt(today, 0, 1));

      final plan = await planner.plan();
      final todaysUntimed = plan.singleWhere((n) {
        final p = NotificationPayload.decode(n.payload);
        return p.taskId == task.id && p.occurrenceDate == today;
      });
      expect(todaysUntimed.scheduledFor, instantAt(today, 7, 30));
    });

    test('falls back to 09:00 when neither due_times nor a stored default '
        'reminder time is configured', () async {
      await settings.setRemindersEnabled(true);
      final task = await taskRepo.createTask(
        title: 'Journal',
        recurrenceType: RecurrenceType.daily,
        startDate: today,
      );
      final planner = buildPlanner(clockAt(today, 0, 1));

      final plan = await planner.plan();
      final todaysUntimed = plan.singleWhere((n) {
        final p = NotificationPayload.decode(n.payload);
        return p.taskId == task.id && p.occurrenceDate == today;
      });
      expect(todaysUntimed.scheduledFor, instantAt(today, 9, 0));
    });
  });

  group('already-completed occurrences', () {
    test('a slot with a live completion is not scheduled, but the same '
        'task\'s other still-open slots/days are', () async {
      await settings.setRemindersEnabled(true);
      final task = await taskRepo.createTask(
        title: 'Stretch',
        recurrenceType: RecurrenceType.daily,
        dueTimes: const ['08:00'],
        startDate: today,
      );
      await seedCompletion(taskId: task.id, occurrenceDate: today, slot: 0);
      final planner = buildPlanner(clockAt(today, 0, 1));

      final plan = await planner.plan();
      final forTask = plan
          .map((n) => NotificationPayload.decode(n.payload))
          .where((p) => p.taskId == task.id);

      expect(forTask.any((p) => p.occurrenceDate == today), isFalse);
      expect(forTask.any((p) => p.occurrenceDate == today.addDays(1)), isTrue);
    });
  });

  group('past instants', () {
    test('a reminder whose computed instant is at or before now is dropped',
        () async {
      await settings.setRemindersEnabled(true);
      final task = await taskRepo.createTask(
        title: 'Morning run',
        recurrenceType: RecurrenceType.daily,
        dueTimes: const ['08:00'],
        startDate: today,
      );
      // Now is exactly 08:00 - "at or before now" must drop it.
      final planner = buildPlanner(clockAt(today, 8, 0));

      final plan = await planner.plan();
      final todaysReminder = plan.where((n) {
        final p = NotificationPayload.decode(n.payload);
        return p.taskId == task.id && p.occurrenceDate == today;
      });
      expect(todaysReminder, isEmpty);

      // Tomorrow's 08:00 is still in the future and must still be planned.
      final tomorrowsReminder = plan.where((n) {
        final p = NotificationPayload.decode(n.payload);
        return p.taskId == task.id && p.occurrenceDate == today.addDays(1);
      });
      expect(tomorrowsReminder, isNotEmpty);
    });
  });

  group('archived, ended and deleted tasks', () {
    test('produce no notifications, while an otherwise-identical active '
        'task does', () async {
      await settings.setRemindersEnabled(true);

      final control = await taskRepo.createTask(
        title: 'Control',
        recurrenceType: RecurrenceType.daily,
        startDate: today,
      );

      final archived = await taskRepo.createTask(
        title: 'Archived',
        recurrenceType: RecurrenceType.daily,
        startDate: today,
      );
      await taskRepo.archiveTask(archived.id);

      final ended = await taskRepo.createTask(
        title: 'Ended',
        recurrenceType: RecurrenceType.daily,
        startDate: today.addDays(-10),
        endDate: today.addDays(-1),
      );

      final deleted = await taskRepo.createTask(
        title: 'Deleted',
        recurrenceType: RecurrenceType.daily,
        startDate: today,
      );
      await taskRepo.tombstoneDelete(deleted.id);

      final planner = buildPlanner(clockAt(today, 0, 1));
      final plan = await planner.plan();
      final taskIdsInPlan =
          plan.map((n) => NotificationPayload.decode(n.payload).taskId).toSet();

      expect(taskIdsInPlan, contains(control.id));
      expect(taskIdsInPlan, isNot(contains(archived.id)));
      expect(taskIdsInPlan, isNot(contains(ended.id)));
      expect(taskIdsInPlan, isNot(contains(deleted.id)));
    });
  });

  group('rolling window boundary', () {
    test('includes the last day of the window and excludes the first day '
        'beyond it', () async {
      await settings.setRemindersEnabled(true);
      final task = await taskRepo.createTask(
        title: 'Daily',
        recurrenceType: RecurrenceType.daily,
        startDate: today,
      );
      final planner = buildPlanner(clockAt(today, 0, 1));

      final plan = await planner.plan();
      final dates = plan
          .map((n) => NotificationPayload.decode(n.payload))
          .where((p) => p.taskId == task.id)
          .map((p) => p.occurrenceDate)
          .toSet();

      final lastDayInWindow =
          today.addDays(NotificationPlanner.rollingWindowDays - 1);
      final firstDayBeyondWindow =
          today.addDays(NotificationPlanner.rollingWindowDays);

      expect(dates, contains(lastDayInWindow));
      expect(dates, isNot(contains(firstDayBeyondWindow)));
    });
  });

  group('stable ids', () {
    test('two identical plans produce the exact same set of ids', () async {
      await settings.setRemindersEnabled(true);
      await taskRepo.createTask(
        title: 'Read',
        recurrenceType: RecurrenceType.daily,
        startDate: today,
      );
      final planner = buildPlanner(clockAt(today, 0, 1));

      final first = await planner.plan();
      final second = await planner.plan();

      expect(
        second.map((n) => n.id).toSet(),
        first.map((n) => n.id).toSet(),
      );
    });

    test('two different tasks never share an id in the same plan', () async {
      await settings.setRemindersEnabled(true);
      await taskRepo.createTask(
        title: 'Read',
        recurrenceType: RecurrenceType.daily,
        startDate: today,
      );
      await taskRepo.createTask(
        title: 'Write',
        recurrenceType: RecurrenceType.daily,
        startDate: today,
      );
      final planner = buildPlanner(clockAt(today, 0, 1));

      final plan = await planner.plan();
      final ids = plan.map((n) => n.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('streak-at-risk warnings', () {
    test('only fires for a task whose current streak is at least 1, not '
        'for a brand-new task with no history', () async {
      await settings.setRemindersEnabled(true);

      final streaking = await taskRepo.createTask(
        title: 'Streaking',
        recurrenceType: RecurrenceType.daily,
        startDate: today.addDays(-5),
      );
      await seedCompletion(
          taskId: streaking.id, occurrenceDate: today.addDays(-1));
      await seedCompletion(
          taskId: streaking.id, occurrenceDate: today.addDays(-2));

      final fresh = await taskRepo.createTask(
        title: 'Fresh',
        recurrenceType: RecurrenceType.daily,
        startDate: today,
      );

      // 07:00: well before the fixed 20:00 warning hour, and before either
      // task's own default 09:00 reminder so that reminder doesn't get
      // confused with the warning in this assertion.
      final planner = buildPlanner(clockAt(today, 7, 0));
      final plan = await planner.plan();

      final warningInstant =
          instantAt(today, NotificationPlanner.eveningWarningHour);
      final warnings = plan.where((n) => n.scheduledFor == warningInstant);
      final warnedTaskIds =
          warnings.map((n) => NotificationPayload.decode(n.payload).taskId);

      expect(warnedTaskIds, contains(streaking.id));
      expect(warnedTaskIds, isNot(contains(fresh.id)));
    });

    test('fires at most once per task even though the warning check runs '
        'once per task, not per slot', () async {
      await settings.setRemindersEnabled(true);
      final task = await taskRepo.createTask(
        title: 'Multi-slot',
        recurrenceType: RecurrenceType.daily,
        dueTimes: const ['06:00', '07:00'],
        startDate: today.addDays(-5),
      );
      await seedCompletion(
          taskId: task.id, occurrenceDate: today.addDays(-1), slot: 0);
      await seedCompletion(
          taskId: task.id, occurrenceDate: today.addDays(-1), slot: 1);
      await seedCompletion(
          taskId: task.id, occurrenceDate: today.addDays(-2), slot: 0);
      await seedCompletion(
          taskId: task.id, occurrenceDate: today.addDays(-2), slot: 1);

      final planner = buildPlanner(clockAt(today, 5, 0));
      final plan = await planner.plan();

      final warningInstant =
          instantAt(today, NotificationPlanner.eveningWarningHour);
      final warningsForTask = plan.where((n) =>
          n.scheduledFor == warningInstant &&
          NotificationPayload.decode(n.payload).taskId == task.id);

      expect(warningsForTask.length, 1);
    });

    test('is suppressed when a reminder for the same task is still pending '
        'later that same evening', () async {
      await settings.setRemindersEnabled(true);
      final task = await taskRepo.createTask(
        title: 'Late task',
        recurrenceType: RecurrenceType.daily,
        dueTimes: const ['20:30'], // after the 20:00 warning hour
        startDate: today.addDays(-5),
      );
      await seedCompletion(taskId: task.id, occurrenceDate: today.addDays(-1));
      await seedCompletion(taskId: task.id, occurrenceDate: today.addDays(-2));

      final planner = buildPlanner(clockAt(today, 7, 0));
      final plan = await planner.plan();

      final warningInstant =
          instantAt(today, NotificationPlanner.eveningWarningHour);
      final hasWarning = plan.any((n) =>
          n.scheduledFor == warningInstant &&
          NotificationPayload.decode(n.payload).taskId == task.id);
      final hasLateReminder = plan.any((n) =>
          n.scheduledFor == instantAt(today, 20, 30) &&
          NotificationPayload.decode(n.payload).taskId == task.id);

      expect(hasLateReminder, isTrue);
      expect(hasWarning, isFalse);
    });

    test('is not suppressed by an earlier-in-the-day reminder that has '
        'nothing to do with the evening', () async {
      await settings.setRemindersEnabled(true);
      final task = await taskRepo.createTask(
        title: 'Early task',
        recurrenceType: RecurrenceType.daily,
        dueTimes: const ['10:00'], // well before the 20:00 warning hour
        startDate: today.addDays(-5),
      );
      await seedCompletion(taskId: task.id, occurrenceDate: today.addDays(-1));
      await seedCompletion(taskId: task.id, occurrenceDate: today.addDays(-2));

      final planner = buildPlanner(clockAt(today, 7, 0));
      final plan = await planner.plan();

      final warningInstant =
          instantAt(today, NotificationPlanner.eveningWarningHour);
      final hasWarning = plan.any((n) =>
          n.scheduledFor == warningInstant &&
          NotificationPayload.decode(n.payload).taskId == task.id);

      expect(hasWarning, isTrue);
    });

    test('is suppressed once the evening warning hour has already passed '
        'today', () async {
      await settings.setRemindersEnabled(true);
      final task = await taskRepo.createTask(
        title: 'Late check',
        recurrenceType: RecurrenceType.daily,
        startDate: today.addDays(-5),
      );
      await seedCompletion(taskId: task.id, occurrenceDate: today.addDays(-1));
      await seedCompletion(taskId: task.id, occurrenceDate: today.addDays(-2));

      // Now is 21:00 - past the fixed 20:00 warning hour.
      final planner = buildPlanner(clockAt(today, 21, 0));
      final plan = await planner.plan();

      final warningInstant =
          instantAt(today, NotificationPlanner.eveningWarningHour);
      final hasWarning = plan.any((n) => n.scheduledFor == warningInstant);
      expect(hasWarning, isFalse);
    });

    test('never fires when streakWarningsEnabled is false', () async {
      await settings.setRemindersEnabled(true);
      await settings.setStreakWarningsEnabled(false);
      final task = await taskRepo.createTask(
        title: 'Streaking',
        recurrenceType: RecurrenceType.daily,
        startDate: today.addDays(-5),
      );
      await seedCompletion(taskId: task.id, occurrenceDate: today.addDays(-1));
      await seedCompletion(taskId: task.id, occurrenceDate: today.addDays(-2));

      final planner = buildPlanner(clockAt(today, 7, 0));
      final plan = await planner.plan();

      final warningInstant =
          instantAt(today, NotificationPlanner.eveningWarningHour);
      expect(plan.any((n) => n.scheduledFor == warningInstant), isFalse);
    });

    test('never fires for a task with no incomplete occurrence today',
        () async {
      await settings.setRemindersEnabled(true);
      final task = await taskRepo.createTask(
        title: 'Already done today',
        recurrenceType: RecurrenceType.daily,
        startDate: today.addDays(-5),
      );
      await seedCompletion(taskId: task.id, occurrenceDate: today.addDays(-1));
      await seedCompletion(taskId: task.id, occurrenceDate: today);

      final planner = buildPlanner(clockAt(today, 7, 0));
      final plan = await planner.plan();

      final warningInstant =
          instantAt(today, NotificationPlanner.eveningWarningHour);
      expect(plan.any((n) => n.scheduledFor == warningInstant), isFalse);
    });
  });

  group('copy and kind', () {
    test('stamps the INJECTED strings onto each notification, interpolating '
        'the task title and streak length', () async {
      await settings.setRemindersEnabled(true);
      final task = await taskRepo.createTask(
        title: 'Read 20 pages',
        recurrenceType: RecurrenceType.daily,
        startDate: today.addDays(-5),
      );
      // A live streak going into today, so the evening warning fires too.
      await seedCompletion(taskId: task.id, occurrenceDate: today.addDays(-1));
      await seedCompletion(taskId: task.id, occurrenceDate: today.addDays(-2));

      final planner = buildPlanner(clockAt(today, 7, 0));
      final plan = await planner.plan();

      final reminder = plan.firstWhere(
        (n) => n.kind == NotificationKind.reminder && n.scheduledFor.day == today.day,
      );
      expect(reminder.title, testNotificationStrings.reminderTitle);
      expect(reminder.body, 'reminder-body:Read 20 pages');

      final warning =
          plan.firstWhere((n) => n.kind == NotificationKind.streakWarning);
      expect(warning.title, testNotificationStrings.streakWarningTitle);
      expect(warning.body, 'streak-body:Read 20 pages:2');
    });

    test('tags each notification with its kind, so the scheduler can put the '
        'two on separate Android channels', () async {
      await settings.setRemindersEnabled(true);
      final task = await taskRepo.createTask(
        title: 'Read 20 pages',
        recurrenceType: RecurrenceType.daily,
        startDate: today.addDays(-5),
      );
      await seedCompletion(taskId: task.id, occurrenceDate: today.addDays(-1));

      final planner = buildPlanner(clockAt(today, 7, 0));
      final plan = await planner.plan();

      expect(
        plan.where((n) => n.kind == NotificationKind.streakWarning).length,
        1,
      );
      expect(
        plan.where((n) => n.kind == NotificationKind.reminder),
        isNotEmpty,
      );
    });
  });
}
