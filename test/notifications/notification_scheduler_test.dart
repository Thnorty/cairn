import 'package:cairn/src/models/local_date.dart';
import 'package:cairn/src/notifications/notification_scheduler.dart';
import 'package:cairn/src/notifications/pending_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnconfiguredNotificationScheduler', () {
    const scheduler = UnconfiguredNotificationScheduler();

    test('scheduleAll is an inert no-op', () async {
      await expectLater(
        scheduler.scheduleAll([
          PendingNotification(
            id: 1,
            kind: NotificationKind.reminder,
            scheduledFor: DateTime(2026, 7, 20, 9),
            title: 'title',
            body: 'body',
            payload: const NotificationPayload(
              taskId: 't1',
              occurrenceDate: LocalDate(2026, 7, 20),
              slot: 0,
            ).encode(),
          ),
        ]),
        completes,
      );
    });

    test('cancelAll is an inert no-op', () async {
      await expectLater(scheduler.cancelAll(), completes);
    });

    test('taps never emits', () async {
      await expectLater(scheduler.taps, emitsDone);
    });
  });
}
