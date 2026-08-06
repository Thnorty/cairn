import 'package:permission_handler/permission_handler.dart' as ph;

/// Opens the OS's own per-app settings screen, so a user who denied a
/// permission can grant it without leaving the app entirely: the Camera
/// Unavailable screen's "Open camera settings" button
/// (`Cairn Camera Unavailable.dc.html`) and the Notifications settings
/// screen's "Open system settings" button (`Cairn Notifications.dc.html`)
/// both land on the same page.
///
/// Kept as its own tiny interface (rather than calling
/// `package:permission_handler` directly from the screens) so widget tests
/// can drive the button with a fake and never touch the plugin's platform
/// channel, matching every other plugin-backed seam in this app
/// ([CameraSession], [PhotoCapture], [RecentPhotoLibrary],
/// [NotificationPermissionRequester]).
abstract class AppSettingsOpener {
  /// Opens the app's settings page in the OS settings app. A no-op (never
  /// throws) if the platform call fails for any reason - this is a
  /// convenience shortcut, not something the rest of the flow depends on to
  /// proceed.
  ///
  /// Deliberately not named for any one permission: the platform offers a
  /// single per-app settings page, not a per-permission deep link, so both
  /// call sites land in the same place. (This was `openCameraSettings` while
  /// the camera was its only caller, which read as a promise the platform
  /// cannot keep.)
  Future<void> openAppSettings();
}

/// [AppSettingsOpener] backed by `package:permission_handler`'s top-level
/// `openAppSettings()`, which launches the platform's own per-app settings
/// screen (no extra native permission or manifest entry required: it's the
/// same system Intent/URL scheme every Android/iOS app can invoke for
/// itself).
///
/// The package is imported under a `ph` prefix because this class's own
/// method now shares that function's name - unprefixed, the call below would
/// resolve to itself and recurse forever.
class PermissionHandlerAppSettingsOpener implements AppSettingsOpener {
  const PermissionHandlerAppSettingsOpener();

  @override
  Future<void> openAppSettings() async {
    try {
      await ph.openAppSettings();
    } catch (_) {
      // Best-effort convenience shortcut; nothing else in the flow depends
      // on this succeeding.
    }
  }
}
