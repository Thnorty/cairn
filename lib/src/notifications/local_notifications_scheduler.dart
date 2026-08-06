import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_scheduler.dart';
import 'pending_notification.dart';

/// The real [NotificationScheduler]: posts Cairn's reminders and
/// streak-at-risk warnings through `flutter_local_notifications`, and
/// surfaces taps on them as decoded [NotificationPayload]s.
///
/// Everything plugin-shaped lives behind this one class, so
/// [NotificationPlanner] and the whole test suite stay free of platform
/// channels - the same arrangement `SupabaseProofVerifier`/
/// `SupabaseSyncTransport`/`RevenueCatPremiumService` have behind their own
/// seams.
///
/// Scheduling is deliberately **inexact**
/// ([AndroidScheduleMode.inexactAllowWhileIdle]): exact alarms on Android
/// 12+ need the `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` permission, which
/// Play reviews as a restricted permission and which is meant for alarm
/// clocks and calendar events, not habit nudges. A reminder that lands a few
/// minutes late is fine; a Play policy rejection is not. `allowWhileIdle` is
/// what still gets it delivered when the device is in Doze.
class LocalNotificationsScheduler implements NotificationScheduler {
  LocalNotificationsScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// The two Android notification channels, one per [NotificationKind] - see
  /// [PendingNotification.kind] for why they are kept separate. The ids are
  /// part of the app's persisted OS state: once a channel exists on a device,
  /// Android ignores any later change to its name or importance, and renaming
  /// an *id* silently creates a second channel while orphaning the user's
  /// settings on the first. They must not be edited casually.
  ///
  /// For the same reason the channel names/descriptions in [_detailsFor] are
  /// deliberately hardcoded English rather than pulled from the ARB: Android
  /// snapshots them at channel-creation time and never re-reads them, so a
  /// localized name would freeze to whatever language the device happened to
  /// be in on the day the user's first reminder fired. Everything the user
  /// reads *inside* Cairn is localized; only these two OS-level channel
  /// labels are not.
  static const String reminderChannelId = 'cairn_reminders';
  static const String streakWarningChannelId = 'cairn_streak_warnings';

  final FlutterLocalNotificationsPlugin _plugin;

  final StreamController<NotificationPayload> _taps =
      StreamController<NotificationPayload>.broadcast();

  /// The tap that cold-started the app, if any, held until the first
  /// subscriber attaches - see [taps].
  NotificationPayload? _launchPayload;

  /// Memoised so concurrent callers (the trigger's first `scheduleAll` and
  /// the tap listener's first subscription both race at startup) share one
  /// initialization rather than each running `tz` setup and
  /// `_plugin.initialize` again.
  Future<void>? _initialization;

  Future<void> _ensureInitialized() =>
      _initialization ??= _initialize();

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Leaves `tz.local` as UTC. Benign: `zonedSchedule` fires on an
      // absolute instant, and `TZDateTime.from` below converts from a
      // DateTime that already carries the correct instant, so the reminder
      // still lands at the right wall-clock moment either way. Only
      // hypothetical future features that *format* a TZDateTime would care.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        // NOT @mipmap/ic_launcher. Android rebuilds a notification's small
        // icon from its ALPHA CHANNEL as a silhouette and tints that itself,
        // so a fully-opaque launcher icon renders as a solid white square -
        // which is exactly what the first device run showed. `ic_stat_cairn`
        // is the cairn shape on a transparent background, built for this.
        android: AndroidInitializationSettings('@drawable/ic_stat_cairn'),
      ),
      onDidReceiveNotificationResponse: _handleResponse,
    );

    // Create BOTH channels up front rather than letting the plugin create
    // each one lazily when its first notification is posted.
    //
    // Lazy creation makes the two-channel split a promise the app does not
    // keep: the streak-warning channel would not exist in Android's own
    // per-app notification settings until a streak warning actually fired,
    // which for a new user can be weeks away (it needs a live streak *and* an
    // unproven day). A user who goes looking for the OS-level control the
    // in-app "Streak warnings" switch implies would simply not find it. Both
    // channels existing from first launch is the whole point of splitting
    // them - see PendingNotification.kind. Verified on device: before this,
    // only `cairn_reminders` was present.
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        for (final kind in NotificationKind.values) {
          await android.createNotificationChannel(_channelFor(kind));
        }
      }
    } catch (_) {
      // Non-fatal: posting a notification creates its channel anyway, so the
      // worst case here is a return to the old lazy behaviour.
    }

    // The cold-start path: the app was launched *by* a notification tap, so
    // there was no live callback to receive - the process did not exist yet.
    // This is a query of the launch intent and stays valid for the life of
    // the process, so it is safe to read here rather than before `runApp`.
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch != null && launch.didNotificationLaunchApp) {
        final decoded = _decode(launch.notificationResponse?.payload);
        if (decoded != null) _launchPayload = decoded;
      }
    } catch (_) {
      // A launch-details failure must not stop scheduling from working.
    }
  }

  void _handleResponse(NotificationResponse response) {
    final decoded = _decode(response.payload);
    if (decoded != null) _taps.add(decoded);
  }

  /// Never throws on a malformed payload, unlike
  /// [NotificationPayload.decode] itself (which deliberately does, so bad
  /// input is loud at the point of use). Here it must not: a payload written
  /// by an *older build* of the app can still be sitting in a scheduled
  /// notification days later, and an app that crashes on being tapped is far
  /// worse than one that ignores a tap it cannot route.
  NotificationPayload? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return NotificationPayload.decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> scheduleAll(List<PendingNotification> notifications) async {
    await _ensureInitialized();

    // Wholesale replace, per the seam's contract. Cancelling first (rather
    // than diffing) is what makes a notification the planner has dropped -
    // because the occurrence was completed, the task archived, or reminders
    // switched off - actually disappear.
    await _plugin.cancelAll();

    for (final notification in notifications) {
      try {
        await _plugin.zonedSchedule(
          id: notification.id,
          title: notification.title,
          body: notification.body,
          payload: notification.payload,
          scheduledDate: tz.TZDateTime.from(notification.scheduledFor, tz.local),
          notificationDetails: _detailsFor(notification.kind),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (_) {
        // Per-notification, so one rejected entry (a date the platform
        // dislikes, a transient plugin error) costs only itself instead of
        // silently truncating the rest of the plan.
      }
    }
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }

  /// Replays [_launchPayload] to the first subscriber before forwarding the
  /// live stream, which is what satisfies the seam's cold-start requirement:
  /// the launch tap is observed during [_initialize], necessarily before any
  /// widget has had a chance to subscribe, and a bare broadcast stream would
  /// drop it. Cleared as it is yielded, so one tap routes exactly once.
  @override
  Stream<NotificationPayload> get taps async* {
    await _ensureInitialized();
    final pending = _launchPayload;
    if (pending != null) {
      _launchPayload = null;
      yield pending;
    }
    yield* _taps.stream;
  }

  /// Releases the tap controller. Wired to the provider's `onDispose`.
  Future<void> dispose() => _taps.close();

  /// The one place each channel's id, name and description are defined, so
  /// [_channelFor] (which creates it) and [_detailsFor] (which posts to it)
  /// can never drift apart into two channels that differ only by a typo.
  static const ({String id, String name, String description}) _reminderChannel =
      (
    id: reminderChannelId,
    name: 'Habit reminders',
    description: 'A nudge when a habit is due.',
  );

  static const ({String id, String name, String description})
      _streakWarningChannel = (
    id: streakWarningChannelId,
    name: 'Streak warnings',
    description: 'One evening heads-up before a streak breaks.',
  );

  static ({String id, String name, String description}) _specFor(
    NotificationKind kind,
  ) =>
      switch (kind) {
        NotificationKind.reminder => _reminderChannel,
        NotificationKind.streakWarning => _streakWarningChannel,
      };

  AndroidNotificationChannel _channelFor(NotificationKind kind) {
    final spec = _specFor(kind);
    return AndroidNotificationChannel(
      spec.id,
      spec.name,
      description: spec.description,
      importance: Importance.defaultImportance,
    );
  }

  NotificationDetails _detailsFor(NotificationKind kind) {
    final spec = _specFor(kind);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        spec.id,
        spec.name,
        channelDescription: spec.description,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
  }
}
