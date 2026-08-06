import 'dart:async';

import 'package:cairn/src/notifications/notification_scheduler.dart';
import 'package:cairn/src/notifications/pending_notification.dart';

/// In-memory test fake for [NotificationScheduler]: records what it was last
/// asked to schedule (and how many times each method was called) rather than
/// touching any plugin, so tests can assert on `NotificationPlanner`'s output
/// reaching the scheduler without a real `flutter_local_notifications`
/// dependency.
class FakeNotificationScheduler implements NotificationScheduler {
  /// The notifications passed to the most recent [scheduleAll] call, or the
  /// empty list before any call (or after [cancelAll]).
  List<PendingNotification> lastScheduled = const [];

  int scheduleAllCallCount = 0;
  int cancelAllCallCount = 0;

  final StreamController<NotificationPayload> _taps =
      StreamController<NotificationPayload>.broadcast();

  /// The tap the real scheduler would replay to its first subscriber, set by
  /// [presetLaunchTap]. Mirrors [LocalNotificationsScheduler]'s own
  /// cold-start behaviour so a test can exercise the "app was launched by a
  /// notification" path, which is otherwise unreachable from a widget test.
  NotificationPayload? _launchPayload;

  /// Arranges for [taps] to replay [payload] to its first subscriber, as a
  /// cold-start launch tap would.
  void presetLaunchTap(NotificationPayload payload) {
    _launchPayload = payload;
  }

  /// Emits a tap to any current subscriber, as a tap on a live app would.
  void emitTap(NotificationPayload payload) => _taps.add(payload);

  @override
  Future<void> scheduleAll(List<PendingNotification> notifications) async {
    scheduleAllCallCount++;
    lastScheduled = notifications;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCallCount++;
    lastScheduled = const [];
  }

  @override
  Stream<NotificationPayload> get taps async* {
    final pending = _launchPayload;
    if (pending != null) {
      _launchPayload = null;
      yield pending;
    }
    yield* _taps.stream;
  }

  Future<void> dispose() => _taps.close();
}
