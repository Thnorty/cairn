import 'package:cairn/src/services/camera_session.dart';
import 'package:flutter/widgets.dart';

/// In-memory [CameraSession] for widget tests and the screenshot harness:
/// never touches the real `camera` plugin's platform channel, which
/// `flutter test` cannot exercise (see CLAUDE.md: a real-device camera test
/// is one of the human-required steps this repo cannot complete on its own).
class FakeCameraSession implements CameraSession {
  FakeCameraSession({
    this.initializeResult = true,
    this.hasMultipleCameras = true,
    this.takePicturePath = '/fake/camera/shot.jpg',
    Widget? preview,
  }) : _preview = preview ?? const ColoredBox(color: Color(0xFF3A4230));

  /// What [initialize] resolves to; set false to simulate no camera
  /// hardware/permission denied and exercise the graceful-degradation path.
  final bool initializeResult;

  @override
  bool hasMultipleCameras;

  final String takePicturePath;
  final Widget _preview;

  int initializeCalls = 0;
  int switchCameraCalls = 0;
  int takePictureCalls = 0;
  int disposeCalls = 0;

  /// Set by a test to make the next [takePicture] call throw, simulating a
  /// mid-capture plugin hiccup.
  Object? takePictureError;

  @override
  Future<bool> initialize() async {
    initializeCalls++;
    return initializeResult;
  }

  @override
  Widget buildPreview() => _preview;

  @override
  Future<bool> switchCamera() async {
    switchCameraCalls++;
    return hasMultipleCameras;
  }

  @override
  Future<String> takePicture() async {
    takePictureCalls++;
    final error = takePictureError;
    if (error != null) throw error;
    return takePicturePath;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
