import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/notifications/notification_scheduler.dart';
import 'package:cairn/src/notifications/notification_trigger.dart';
import 'package:cairn/src/notifications/pending_notification.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/settings_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/notification_planner.dart';
import 'package:cairn/src/services/occurrence_generator.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/services/streak_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fake_notification_scheduler.dart';
import '../support/test_notification_strings.dart';

/// Always throws, to simulate a failure anywhere between resolving the
/// planner and calling `plan()` - the same rationale
/// `test/sync/sync_trigger_test.dart`'s `_ThrowingSyncService` documents for
/// `SyncTrigger`.
NotificationPlanner _throwingPlannerResolver() {
  throw StateError('simulated planner resolution failure');
}

/// Always throws from `scheduleAll`, to simulate a scheduler-side failure.
class _ThrowingScheduler implements NotificationScheduler {
  @override
  Future<void> scheduleAll(List<PendingNotification> notifications) async {
    throw StateError('simulated scheduleAll failure');
  }

  @override
  Future<void> cancelAll() async {}

  @override
  Stream<NotificationPayload> get taps => const Stream.empty();
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = inMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  NotificationPlanner buildPlanner(AppDatabase db, Clock clock) {
    return NotificationPlanner(
      TaskRepository(db, clock),
      CompletionRepository(db, clock, verifier: FakeProofVerifier()),
      SettingsRepository(db),
      const OccurrenceGenerator(),
      const StreakService(),
      clock,
      testNotificationStrings,
    );
  }

  group('NotificationTrigger.runOnce', () {
    test('forwards an empty plan to scheduler.scheduleAll when reminders '
        'are disabled (the default)', () async {
      final planner = buildPlanner(db, FixedClock(d(2026, 7, 20)));
      final scheduler = FakeNotificationScheduler();
      final trigger =
          NotificationTrigger(db, () => planner, () => scheduler);

      await trigger.runOnce();

      expect(scheduler.scheduleAllCallCount, 1);
      expect(scheduler.lastScheduled, isEmpty);
    });

    test('forwards the planner\'s actual plan to scheduler.scheduleAll',
        () async {
      final clock = FixedClock(
        d(2026, 7, 20),
        nowMillis: DateTime(2026, 7, 20, 0, 1).millisecondsSinceEpoch,
      );
      final settings = SettingsRepository(db);
      await settings.setRemindersEnabled(true);
      await TaskRepository(db, clock).createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 20),
      );

      final planner = buildPlanner(db, clock);
      final scheduler = FakeNotificationScheduler();
      final trigger =
          NotificationTrigger(db, () => planner, () => scheduler);

      final expectedPlan = await planner.plan();
      await trigger.runOnce();

      expect(expectedPlan, isNotEmpty);
      expect(scheduler.lastScheduled.length, expectedPlan.length);
      expect(
        scheduler.lastScheduled.map((n) => n.id).toSet(),
        expectedPlan.map((n) => n.id).toSet(),
      );
    });

    test('swallows an error thrown while resolving/planning', () async {
      final scheduler = FakeNotificationScheduler();
      final trigger = NotificationTrigger(
        db,
        _throwingPlannerResolver,
        () => scheduler,
      );

      await expectLater(trigger.runOnce(), completes);
      expect(scheduler.scheduleAllCallCount, 0);
    });

    test('swallows an error thrown out of scheduler.scheduleAll', () async {
      final planner = buildPlanner(db, FixedClock(d(2026, 7, 20)));
      final trigger = NotificationTrigger(
        db,
        () => planner,
        () => _ThrowingScheduler(),
      );

      await expectLater(trigger.runOnce(), completes);
    });
  });
}
