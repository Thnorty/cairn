import 'package:camera/camera.dart';
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

  Future<bool> _startController(int index) async {
    try {
      final controller = CameraController(
        _cameras[index],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      await _controller?.dispose();
      _controller = controller;
      _selectedIndex = index;
      return true;
    } catch (_) {
      return false;
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
