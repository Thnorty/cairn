import 'package:permission_handler/permission_handler.dart';

/// Fires the OS notification-permission prompt (onboarding step 5's "Allow
/// notifications", and turning the master switch on from the Notifications
/// settings screen), and reports whether Cairn is currently allowed to
/// deliver notifications at all.
///
/// Kept as its own tiny interface rather than calling
/// `package:permission_handler` directly from the screens, so widget tests
/// drive both paths with a fake and never touch the plugin's platform
/// channel - the same arrangement as [CameraPermissionRequester] and
/// [AppSettingsOpener], which this deliberately mirrors.
///
/// Unlike [CameraPermissionRequester], [request] DOES report its outcome:
/// the camera ask never branches on the result (entry into the app is not
/// gated on it), but this one does - a grant is what flips reminders on, and
/// a denial is what puts the Notifications settings screen into its
/// "Android is blocking these" state.
abstract class NotificationPermissionRequester {
  /// Requests notification permission, resolving once the OS prompt is
  /// dismissed. True iff Cairn may now post notifications.
  ///
  /// On Android 12 and below there is no runtime notification permission at
  /// all, so this resolves true without showing anything.
  Future<bool> request();

  /// Whether Cairn may currently post notifications, without prompting.
  Future<bool> isGranted();
}

/// [NotificationPermissionRequester] backed by `package:permission_handler`'s
/// `Permission.notification`, which maps to the Android 13+ `POST_NOTIFICATIONS`
/// runtime permission and, on older versions, to whether the user has
/// switched Cairn's notifications off in system settings.
class PermissionHandlerNotificationPermissionRequester
    implements NotificationPermissionRequester {
  const PermissionHandlerNotificationPermissionRequester();

  @override
  Future<bool> request() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      // Treated as a denial: the caller's next move is to leave reminders
      // off, which is the safe direction to fail in - it never claims a
      // permission the app might not have.
      return false;
    }
  }

  @override
  Future<bool> isGranted() async {
    try {
      return await Permission.notification.isGranted;
    } catch (_) {
      // Fails OPEN, the opposite direction to [request], and deliberately:
      // this answer only drives whether the settings screen shows its
      // "Android is blocking these" notice. Showing that alarming banner
      // because a plugin call failed would be worse than omitting it, and
      // the user has a real signal either way (notifications arriving, or
      // not).
      return true;
    }
  }
}
