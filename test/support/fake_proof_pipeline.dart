import 'dart:convert';
import 'dart:typed_data';

import 'package:cairn/src/db/database.dart' show ProofSource;
import 'package:cairn/src/services/photo_capture.dart';

/// A real, valid 1x1 transparent PNG (base64-decoded), so any widget under
/// test that actually renders the "compressed" bytes with `Image.memory`
/// (the verification-flow outcome screens' proof-photo pebble) gets a codec
/// that decodes cleanly instead of throwing an async "Invalid image data"
/// error that `flutter_test` treats as a test failure. Arbitrary non-image
/// bytes (e.g. a plain ASCII placeholder) are fine for the non-widget
/// `ProofFlowService`/`CompletionRepository` tests, which never decode them,
/// but not here.
final Uint8List kFakeImageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

/// Shared photo-pipeline fakes for widget tests that need to drive
/// [ProofFlowService] without touching any real plugin (`image_picker`,
/// `flutter_image_compress`, `path_provider`) - none of which `flutter test`
/// can exercise. `test/proof_flow_test.dart` keeps its own private,
/// near-identical fakes for its non-widget tests; these are shared here
/// because more than one widget test file needs them
/// (`camera_capture_screen_test.dart`, the screenshot harness).
class FakePhotoCapture implements PhotoCapture {
  FakePhotoCapture({this.takenAtMillis, this.tempPath = '/fake/gallery-pick.jpg'});

  final int? takenAtMillis;
  final String tempPath;
  int callCount = 0;

  @override
  Future<CapturedPhoto?> capture(ProofSource source) async {
    callCount++;
    return CapturedPhoto(tempPath: tempPath, source: source, takenAtMillis: takenAtMillis);
  }
}

class FakeImageCompressor implements ImageCompressor {
  int callCount = 0;

  @override
  Future<Uint8List> compress(String path) async {
    callCount++;
    return kFakeImageBytes;
  }
}

class FakeProofPhotoStore implements ProofPhotoStore {
  final Map<String, Uint8List> _files = {};
  int _nextId = 0;
  final List<String> saved = [];
  final List<String> deleted = [];

  @override
  Future<String> save(Uint8List bytes) async {
    final path = '/fake/proofs/${_nextId++}.jpg';
    _files[path] = bytes;
    saved.add(path);
    return path;
  }

  @override
  Future<Uint8List?> load(String path) async => _files[path];

  @override
  Future<void> delete(String path) async {
    _files.remove(path);
    deleted.add(path);
  }
}
