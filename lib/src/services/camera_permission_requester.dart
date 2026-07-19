import 'package:permission_handler/permission_handler.dart';

/// Fires the real OS camera-permission prompt from the onboarding
/// verification screen's "Allow camera" button.
///
/// Kept as its own tiny interface (rather than calling
/// `package:permission_handler` directly from the screen) so widget tests
/// can drive the button with a fake and never touch the plugin's platform
/// channel, matching every other plugin-backed seam in this app
/// ([CameraSession], [PhotoCapture], [RecentPhotoLibrary],
/// [AppSettingsOpener]).
///
/// Onboarding entry is deliberately NOT gated on the result of [request]:
/// the caller marks onboarding complete and enters the app whether the user
/// allows or denies the prompt (`image_picker` re-prompts at first capture
/// if it was denied here).
abstract class CameraPermissionRequester {
  /// Requests camera permission. Resolves once the OS prompt is dismissed
  /// (allowed or denied) - callers only await this to sequence "ask, then
  /// proceed", never to branch on the outcome.
  Future<void> request();
}

/// [CameraPermissionRequester] backed by `package:permission_handler`'s
/// `Permission.camera.request()`.
class PermissionHandlerCameraPermissionRequester
    implements CameraPermissionRequester {
  const PermissionHandlerCameraPermissionRequester();

  @override
  Future<void> request() async {
    try {
      await Permission.camera.request();
    } catch (_) {
      // Best-effort: onboarding entry never blocks on this - see this
      // class's doc comment.
    }
  }
}
