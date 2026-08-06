import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/database.dart';
import '../../notifications/pending_notification.dart';
import '../../providers.dart';
import '../proof/proof_entry.dart';

/// Routes a tapped reminder or streak warning straight into the camera for
/// the exact occurrence it was about, which is
/// `Cairn Onboarding Notifications.dc.html`'s explicit promise ("Tap it to go
/// straight to the camera").
///
/// Wraps [AppShell] rather than living inside it, and is mounted only on the
/// post-onboarding branch of [OnboardingGate]: a tap must never drop a
/// first-launch user into the camera in the middle of the onboarding flow,
/// and there is nothing to route to before any task exists anyway.
///
/// Handles both arrival paths through the one stream - a tap while the app is
/// running, and the tap that cold-started the process - because
/// [NotificationScheduler.taps] replays the launch tap to its first
/// subscriber (see [LocalNotificationsScheduler.taps]).
class NotificationTapListener extends ConsumerStatefulWidget {
  const NotificationTapListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationTapListener> createState() =>
      _NotificationTapListenerState();
}

class _NotificationTapListenerState
    extends ConsumerState<NotificationTapListener> {
  /// Stops a second tap (or a launch-tap replay arriving alongside a live
  /// one) from stacking a second camera route while the first is still
  /// opening.
  bool _routing = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(notificationTapsProvider, (_, next) {
      final payload = next.asData?.value;
      if (payload != null) unawaited(_route(payload));
    });
    return widget.child;
  }

  Future<void> _route(NotificationPayload payload) async {
    if (_routing) return;
    _routing = true;
    try {
      // A notification is scheduled up to 14 days ahead and survives the app
      // being killed, so by the time it is tapped the occurrence it names may
      // no longer be today - the phone was on silent overnight, or the app
      // was opened from the tray the next morning. Completing a past date is
      // forbidden (CLAUDE.md's no-back-filling rule), and letting it through
      // would surface `startProofFlow`'s untranslated "Cannot complete a past
      // date" safety net as if it were product copy. Opening the app to Today
      // and saying nothing is the honest outcome.
      if (payload.occurrenceDate != ref.read(clockProvider).today()) return;

      // activeTasks() excludes archived and tombstoned tasks, so a
      // notification for a habit deleted since it was scheduled resolves to
      // nothing and is dropped. `precheckProof` would reject it too, but this
      // way it is dropped silently rather than via that same safety net.
      final tasks = await ref.read(taskRepositoryProvider).activeTasks();
      Task? task;
      for (final candidate in tasks) {
        if (candidate.id == payload.taskId) {
          task = candidate;
          break;
        }
      }
      if (task == null || !mounted) return;

      await startProofFlow(
        context,
        ref,
        taskId: task.id,
        taskTitle: task.title,
        occurrenceDate: payload.occurrenceDate,
        slot: payload.slot,
      );
    } finally {
      _routing = false;
    }
  }
}
