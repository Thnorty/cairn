import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/widgets.dart';

/// Abstraction over a live, custom in-app camera capture session.
///
/// `Cairn Camera Capture.dc.html` calls for a custom in-app camera: a live
/// preview, a shutter button, a flip-camera control and a "Verifying…"
/// overlay - none of which the existing `image_picker`-backed [PhotoCapture]
/// (`photo_capture.dart`) can produce, since `ImageSource.camera` launches
/// the *system* camera app, which owns its own UI. This is exactly the
/// escalation the guideline itself anticipated ("image_picker (MVP) ->
/// camera when you want a custom capture UI/overlay").
///
/// Kept as its own small interface (rather than baking `package:camera`
/// straight into `CameraCaptureScreen`) so widget tests can drive the whole
/// capture/verify/route flow with [FakeCameraSession]-style fakes and never
/// touch the plugin's platform channel, which `flutter test` cannot exercise
/// (see CLAUDE.md: a real-device camera test is one of the human-required
/// steps this repo cannot complete on its own).
abstract class CameraSession {
  /// Acquires the device's default camera and starts the preview. Returns
  /// false (never throws) on any failure - no camera hardware, permission
  /// denied, the hardware already in use, or the plugin being unavailable on
  /// this platform - so the caller can degrade to the gallery path instead
  /// of dead-ending on a broken viewfinder.
  Future<bool> initialize();

  /// The live preview widget. Only meaningful after [initialize] has
  /// returned true; rebuilding after [switchCamera] reflects the
  /// newly-selected camera.
  Widget buildPreview();

  /// The live preview's aspect ratio (width / height) as it should be
  /// *displayed* on screen - already adjusted for orientation, not the raw
  /// value a camera controller reports (which is measured in the sensor's
  /// native landscape orientation). 1 (square) before [initialize] has
  /// succeeded. Callers use this to size the preview so it fills the
  /// viewfinder by center-cropping (`BoxFit.cover`) rather than stretching -
  /// see `CameraCaptureScreen`'s `_CoverCameraPreview`, which exists because
  /// a plain `CameraPreview(controller)` dropped into a
  /// `Stack(fit: StackFit.expand)` gets *tight* constraints from that Stack,
  /// and a tight-constrained `AspectRatio` (which is exactly what
  /// `package:camera`'s own `CameraPreview` wraps itself in) can't honour
  /// its own ratio and just stretches to fill instead.
  double get previewAspectRatio;

  /// Whether more than one camera is available to switch between (e.g. both
  /// a front and a rear camera). [switchCamera] is a no-op when this is
  /// false.
  bool get hasMultipleCameras;

  /// Switches to the next available camera (front/back). Returns false
  /// (leaving the current camera active) when [hasMultipleCameras] is false
  /// or the switch itself fails.
  Future<bool> switchCamera();

  /// Captures a still photo and returns its temporary file path.
  Future<String> takePicture();

  /// Releases the underlying camera resource. Safe to call more than once.
  /// Must be called from the owning widget's `dispose()`.
  Future<void> dispose();
}

/// [CameraSession] backed by `package:camera`'s [CameraController].
class PluginCameraSession implements CameraSession {
  List<CameraDescription> _cameras = const [];
  int _selectedIndex = 0;
  CameraController? _controller;

  @override
  bool get hasMultipleCameras => _cameras.length > 1;

  @override
  Future<bool> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return false;
      return await _startController(_selectedIndex);
    } catch (_) {
      return false;
    }
  }

  /// Starts a controller for `_cameras[index]`, disposing whichever
  /// controller is currently active *first*.
  ///
  /// Real-device regression fix: this used to initialize the *new*
  /// controller before disposing the old one (so both briefly held the
  /// camera hardware at once). Most phones can't open two `CameraDescription`
  /// devices simultaneously, so the new controller's `initialize()` threw,
  /// the `catch` swallowed it, and `switchCamera` silently returned false -
  /// the flip control looked completely dead on a real device even though
  /// every piece of the plumbing (`hasMultipleCameras`, the index cycling,
  /// the widget wiring) was already correct. Disposing first frees the
  /// hardware before the new controller ever touches it. If the new
  /// controller then fails anyway, this falls back to re-starting the
  /// previous camera so the screen doesn't lose its preview entirely over a
  /// single failed flip.
  Future<bool> _startController(int index) async {
    final previousDescription =
        _controller == null ? null : _cameras[_selectedIndex];
    await _controller?.dispose();
    _controller = null;

    try {
      final controller = CameraController(
        _cameras[index],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      _controller = controller;
      _selectedIndex = index;
      return true;
    } catch (_) {
      if (previousDescription == null) return false;
      // Best-effort fallback: try to get the previous camera back rather
      // than leaving the screen with no preview at all. If this also
      // fails, `_controller` stays null and `buildPreview` degrades to an
      // empty box.
      try {
        final fallback = CameraController(
          previousDescription,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await fallback.initialize();
        _controller = fallback;
        return false;
      } catch (_) {
        return false;
      }
    }
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controller);
  }

  @override
  double get previewAspectRatio {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return 1;
    final raw = controller.value.aspectRatio;
    if (raw <= 0) return 1;
    // Mirrors `CameraPreview`'s own `_isLandscape()` check (see
    // package:camera's camera_preview.dart): `CameraController.value
    // .aspectRatio` is measured in the sensor's native landscape
    // orientation, so it needs inverting for the common portrait case.
    final orientation =
        controller.value.lockedCaptureOrientation ?? controller.value.deviceOrientation;
    final isLandscape = orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
    return isLandscape ? raw : 1 / raw;
  }

  @override
  Future<bool> switchCamera() async {
    if (!hasMultipleCameras) return false;
    final nextIndex = (_selectedIndex + 1) % _cameras.length;
    return _startController(nextIndex);
  }

  @override
  Future<String> takePicture() async {
    final controller = _controller;
    if (controller == null) {
      throw StateError('takePicture called before initialize() succeeded');
    }
    final file = await controller.takePicture();
    return file.path;
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
