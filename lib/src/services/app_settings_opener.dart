import 'package:permission_handler/permission_handler.dart';

/// Opens the OS's own app-settings screen, so a user who denied camera
/// permission can grant it without leaving the app entirely
/// (`Cairn Camera Unavailable.dc.html`'s "Open camera settings" button).
///
/// Kept as its own tiny interface (rather than calling
/// `package:permission_handler` directly from the screen) so widget tests
/// can drive the button with a fake and never touch the plugin's platform
/// channel, matching every other plugin-backed seam in this app
/// ([CameraSession], [PhotoCapture], [RecentPhotoLibrary]).
abstract class AppSettingsOpener {
  /// Opens the app's settings page in the OS settings app. A no-op (never
  /// throws) if the platform call fails for any reason - this is a
  /// convenience shortcut, not something the rest of the flow depends on to
  /// proceed.
  Future<void> openCameraSettings();
}

/// [AppSettingsOpener] backed by `package:permission_handler`'s
/// `openAppSettings()`, which launches the platform's own per-app settings
/// screen (no extra native permission or manifest entry required: it's the
/// same system Intent/URL scheme every Android/iOS app can invoke for
/// itself).
class PermissionHandlerAppSettingsOpener implements AppSettingsOpener {
  const PermissionHandlerAppSettingsOpener();

  @override
  Future<void> openCameraSettings() async {
    try {
      await openAppSettings();
    } catch (_) {
      // Best-effort convenience shortcut; nothing else in the flow depends
      // on this succeeding.
    }
  }
}
