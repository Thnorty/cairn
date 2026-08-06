import 'pending_notification.dart';

/// Seam between the notification-scheduling engine (`NotificationPlanner`,
/// `lib/src/services/notification_planner.dart`) and whatever actually posts
/// OS-level notifications (`flutter_local_notifications`, a later work
/// order). [PendingNotification.scheduledFor] is a naive local wall-clock
/// [DateTime]; the real implementation is responsible for converting it to a
/// `TZDateTime` in the device's own timezone before scheduling it with the
/// plugin.
///
/// Same pattern as `ProofVerifier`/`SyncTransport`/`PremiumService`: an
/// abstract seam, an inert unconfigured implementation
/// ([UnconfiguredNotificationScheduler]), and an in-memory fake for tests
/// (`test/support/fake_notification_scheduler.dart`'s `FakeNotificationScheduler`).
abstract class NotificationScheduler {
  /// Replaces every previously scheduled notification with exactly
  /// [notifications]: this is a wholesale replace, not an incremental diff,
  /// so a caller that wants nothing scheduled (e.g. reminders were just
  /// turned off, or the planner computed an empty plan) simply passes an
  /// empty list rather than calling [cancelAll] separately.
  Future<void> scheduleAll(List<PendingNotification> notifications);

  /// Cancels every currently scheduled notification without scheduling
  /// anything new.
  Future<void> cancelAll();

  /// Payloads of notifications the user has tapped, decoded back into the
  /// exact occurrence to open the camera for.
  ///
  /// Belongs on this same seam rather than a second one because the object
  /// that schedules a notification is the only object that can hear it
  /// tapped: on Android the tap is delivered through the very plugin
  /// instance that posted it, either as a live callback (app already
  /// running) or as the launch intent that cold-started the process. A
  /// separate interface would have to reach back into this one's plugin
  /// anyway.
  ///
  /// Implementations MUST deliver a cold-start tap to the first subscriber
  /// even if that subscriber attaches after the tap was observed - the app
  /// is necessarily still booting at that moment, so a plain broadcast
  /// stream would drop exactly the tap that started it.
  Stream<NotificationPayload> get taps;
}

/// Inert scheduler: every call is a no-op and [taps] never emits. Mirrors
/// `UnconfiguredSyncTransport`/`UnconfiguredPremiumService`.
///
/// The real [LocalNotificationsScheduler]
/// (`lib/src/notifications/local_notifications_scheduler.dart`) has since
/// landed and is what the app actually runs, so this now exists for the
/// platforms and harnesses where a plugin-backed scheduler is not wanted:
/// any test that builds a full provider container without wanting
/// `flutter_local_notifications`' platform channels in it, and desktop/web
/// targets where the notification feature is simply not offered.
class UnconfiguredNotificationScheduler implements NotificationScheduler {
  const UnconfiguredNotificationScheduler();

  @override
  Future<void> scheduleAll(List<PendingNotification> notifications) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Stream<NotificationPayload> get taps => const Stream.empty();
}
