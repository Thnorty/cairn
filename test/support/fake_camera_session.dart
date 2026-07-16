import 'package:cairn/src/services/camera_session.dart';
import 'package:flutter/widgets.dart';

/// Which of a [FakeCameraSession]'s (at most two) simulated cameras is
/// currently active - purely a test-observability concern (real
/// [PluginCameraSession] callers never need to ask "which lens is this",
/// only [CameraSession.hasMultipleCameras]/[CameraSession.switchCamera]), so
/// this lives only on the fake, not on the [CameraSession] interface.
enum FakeCameraLens { back, front }

/// In-memory [CameraSession] for widget tests and the screenshot harness:
/// never touches the real `camera` plugin's platform channel, which
/// `flutter test` cannot exercise (see CLAUDE.md: a real-device camera test
/// is one of the human-required steps this repo cannot complete on its own).
class FakeCameraSession implements CameraSession {
  FakeCameraSession({
    this.initializeResult = true,
    bool hasMultipleCameras = true,
    this.takePicturePath = '/fake/camera/shot.jpg',
    this.previewAspectRatio = 0.72,
    Widget? preview,
  })  : _lenses = hasMultipleCameras
            ? const [FakeCameraLens.back, FakeCameraLens.front]
            : const [FakeCameraLens.back],
        _preview = preview ?? const _CoverTestPatternPreview();

  /// What [initialize] resolves to; set false to simulate no camera
  /// hardware/permission denied and exercise the graceful-degradation path.
  final bool initializeResult;

  final String takePicturePath;

  /// Simulates `PluginCameraSession.previewAspectRatio` for the screenshot
  /// harness: a deliberately non-square, non-screen-matching ratio (a
  /// realistic phone camera sensor's ~3:4 in portrait) so a regenerated
  /// screenshot can visually confirm `_CoverCameraPreview` center-crops
  /// instead of stretching - see this run's spec ("use a non-square test
  /// frame so distortion would be visible") and [_CoverTestPatternPreview],
  /// the default [preview], which draws a circle that only stays visibly
  /// circular when the cover-fit math is correct.
  @override
  final double previewAspectRatio;

  final Widget _preview;
  final List<FakeCameraLens> _lenses;
  int _selectedIndex = 0;

  int initializeCalls = 0;
  int switchCameraCalls = 0;
  int takePictureCalls = 0;
  int disposeCalls = 0;

  /// Set by a test to make the next [takePicture] call throw, simulating a
  /// mid-capture plugin hiccup.
  Object? takePictureError;

  @override
  bool get hasMultipleCameras => _lenses.length > 1;

  /// The lens currently active, for a test to assert [switchCamera]
  /// actually selected the *other* camera - not just that it was called.
  FakeCameraLens get currentLens => _lenses[_selectedIndex];

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
    if (!hasMultipleCameras) return false;
    _selectedIndex = (_selectedIndex + 1) % _lenses.length;
    return true;
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

/// A perfect circle on a contrasting field, sized to fill whatever box it's
/// given: stays visibly circular in a screenshot only when the preview is
/// scaled uniformly (`BoxFit.cover`) - a non-uniform stretch would render it
/// as an ellipse instead, which is exactly the defect this run's spec asks
/// to confirm fixed by eye.
class _CoverTestPatternPreview extends StatelessWidget {
  const _CoverTestPatternPreview();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF3A4230),
      child: CustomPaint(painter: _CoverTestPatternPainter(), size: Size.infinite),
    );
  }
}

class _CoverTestPatternPainter extends CustomPainter {
  const _CoverTestPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide * 0.38,
      Paint()..color = const Color(0xFFE4DECE),
    );
  }

  @override
  bool shouldRepaint(_CoverTestPatternPainter oldDelegate) => false;
}
