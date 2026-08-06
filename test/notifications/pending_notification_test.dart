import 'package:cairn/src/models/local_date.dart';
import 'package:cairn/src/notifications/pending_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationPayload encode/decode', () {
    test('round-trips every field exactly', () {
      const payload = NotificationPayload(
        taskId: 'task-abc-123',
        occurrenceDate: LocalDate(2026, 7, 20),
        slot: 1,
      );

      final decoded = NotificationPayload.decode(payload.encode());

      expect(decoded, payload);
      expect(decoded.taskId, 'task-abc-123');
      expect(decoded.occurrenceDate, const LocalDate(2026, 7, 20));
      expect(decoded.slot, 1);
    });

    test('round-trips slot 0 (the untimed/single-slot case)', () {
      const payload = NotificationPayload(
        taskId: 'task-xyz',
        occurrenceDate: LocalDate(2026, 1, 1),
        slot: 0,
      );

      expect(NotificationPayload.decode(payload.encode()), payload);
    });

    test('encode produces snake_case keys with occurrence_date as an ISO '
        'string, the same wire convention ProofVerdict.toJson uses', () {
      const payload = NotificationPayload(
        taskId: 't1',
        occurrenceDate: LocalDate(2026, 3, 5),
        slot: 2,
      );

      expect(
        payload.encode(),
        '{"task_id":"t1","occurrence_date":"2026-03-05","slot":2}',
      );
    });

    test('decode throws on malformed JSON rather than silently defaulting',
        () {
      expect(
        () => NotificationPayload.decode('not json'),
        throwsFormatException,
      );
    });

    test('decode throws on a missing field rather than silently defaulting',
        () {
      expect(
        () => NotificationPayload.decode('{"task_id":"t1"}'),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('pendingNotificationId', () {
    const date = LocalDate(2026, 7, 20);

    test('is stable: the same (task, date, slot, kind) always hashes to the '
        'same id', () {
      final first =
          pendingNotificationId('task-1', date, 0, NotificationKind.reminder);
      final second =
          pendingNotificationId('task-1', date, 0, NotificationKind.reminder);

      expect(second, first);
    });

    test('is always a non-negative (positive 32-bit) int', () {
      for (var i = 0; i < 50; i++) {
        final id = pendingNotificationId(
          'task-$i',
          date.addDays(i),
          i % 3,
          i.isEven ? NotificationKind.reminder : NotificationKind.streakWarning,
        );
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });

    test('differs when the task id differs', () {
      final a =
          pendingNotificationId('task-1', date, 0, NotificationKind.reminder);
      final b =
          pendingNotificationId('task-2', date, 0, NotificationKind.reminder);
      expect(a, isNot(b));
    });

    test('differs when the date differs', () {
      final a =
          pendingNotificationId('task-1', date, 0, NotificationKind.reminder);
      final b = pendingNotificationId(
          'task-1', date.addDays(1), 0, NotificationKind.reminder);
      expect(a, isNot(b));
    });

    test('differs when the slot differs', () {
      final a =
          pendingNotificationId('task-1', date, 0, NotificationKind.reminder);
      final b =
          pendingNotificationId('task-1', date, 1, NotificationKind.reminder);
      expect(a, isNot(b));
    });

    test('differs when the kind differs, even with every other component '
        'identical', () {
      final reminder =
          pendingNotificationId('task-1', date, 0, NotificationKind.reminder);
      final warning = pendingNotificationId(
          'task-1', date, 0, NotificationKind.streakWarning);
      expect(reminder, isNot(warning));
    });
  });
}
