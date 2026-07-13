import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:uuid/uuid.dart';

import '../clock.dart';
import '../db/database.dart';

/// A freshly captured or picked photo, before compression or persistence.
class CapturedPhoto {
  final String tempPath;
  final ProofSource source;

  /// Capture time in epoch millis: the [Clock]'s "now" for a camera shot
  /// (the photo was just taken), or the photo library's own asset timestamp
  /// for a gallery pick (via [AssetTimeResolver]). Null when the asset
  /// lookup found no confident match.
  final int? takenAtMillis;

  const CapturedPhoto({
    required this.tempPath,
    required this.source,
    required this.takenAtMillis,
  });
}

/// Captures a proof photo from the camera or the photo gallery. Both sources
/// are always available for every task; there is no per-task restriction.
abstract class PhotoCapture {
  /// Returns null when the user cancels the picker.
  Future<CapturedPhoto?> capture(ProofSource source);
}

/// Resolves a gallery-picked photo's own capture timestamp from the photo
/// library's asset metadata: the library's own record of the asset (e.g.
/// PhotoKit's `creationDate` / MediaStore's `date_taken`), not in-file EXIF.
/// EXIF is trivial to strip or forge client-side; the library's own metadata
/// is not under the picked file's control the same way.
abstract class AssetTimeResolver {
  /// Returns null when no confident match is found, or the underlying
  /// plugin call fails for any reason. Never throws: recency is only a
  /// cheap pre-filter ahead of the real (Gemini) verification gate, so a
  /// lookup failure must degrade to "unknown", not crash the capture flow.
  Future<int?> takenAtFor(String pickedPath);
}

/// [AssetTimeResolver] backed by `photo_manager`.
///
/// Scans the most recently added assets in the device's default image album
/// and matches by file name, since that's the only identifier `image_picker`
/// and `photo_manager` reliably share for a gallery pick. A photo library
/// with only limited-access permission, a cloud-only asset that hasn't
/// downloaded, or simply no match within the scan window all fall back to
/// null rather than guessing.
class PhotoManagerAssetTimeResolver implements AssetTimeResolver {
  /// How many of the most recently added assets to scan for a file-name
  /// match. Albums are newest-first, so a photo the user just picked is
  /// always near the front; this bounds the scan without needing to walk
  /// the whole library.
  final int scanLimit;

  const PhotoManagerAssetTimeResolver({this.scanLimit = 20});

  @override
  Future<int?> takenAtFor(String pickedPath) async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) return null;

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      if (albums.isEmpty) return null;

      final candidates = await albums.first.getAssetListRange(
        start: 0,
        end: scanLimit,
      );

      final targetName = _basename(pickedPath);
      if (targetName.isEmpty) return null;

      for (final asset in candidates) {
        final title = await asset.titleAsync;
        if (title.isNotEmpty && title == targetName) {
          return asset.createDateTime.millisecondsSinceEpoch;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    return idx == -1 ? normalized : normalized.substring(idx + 1);
  }
}

/// [PhotoCapture] backed by `image_picker`. Camera and gallery are both
/// always offered; there is no per-task restriction on source.
class ImagePickerPhotoCapture implements PhotoCapture {
  final ImagePicker _picker;
  final Clock _clock;
  final AssetTimeResolver _assetTimeResolver;

  ImagePickerPhotoCapture(
    this._clock,
    this._assetTimeResolver, {
    ImagePicker? picker,
  }) : _picker = picker ?? ImagePicker();

  @override
  Future<CapturedPhoto?> capture(ProofSource source) async {
    final picked = await _picker.pickImage(
      source: source == ProofSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
    );
    if (picked == null) return null;

    // A camera shot's capture time is "now" by the app's own clock; a
    // gallery pick's capture time has to come from the library's own asset
    // metadata, since the file could have been taken at any point in the
    // past.
    final takenAtMillis = source == ProofSource.camera
        ? _clock.nowEpochMillis()
        : await _assetTimeResolver.takenAtFor(picked.path);

    return CapturedPhoto(
      tempPath: picked.path,
      source: source,
      takenAtMillis: takenAtMillis,
    );
  }
}

/// Compresses a photo file for the wire.
abstract class ImageCompressor {
  Future<Uint8List> compress(String path);
}

/// [ImageCompressor] backed by `flutter_image_compress`. Steps the JPEG
/// quality down (with the short edge floored) until the result fits
/// [targetBytes] or [floorQuality] is reached, then returns whatever it got:
/// a slightly-oversized proof photo is preferable to failing the whole
/// completion over a wire-size budget.
class FlutterImageCompressor implements ImageCompressor {
  /// Target size in bytes for the compressed photo (roughly 150 KB by
  /// default, per the guideline's wire budget).
  final int targetBytes;

  /// Target floor, in pixels, for the image's short edge: passed as the
  /// plugin's `minWidth`/`minHeight`. Per flutter_image_compress's own
  /// documented formula, `scale = max(1.0, min(srcW / minShortEdge, srcH /
  /// minShortEdge))`, so this is a floor on the short edge, not a cap on the
  /// long edge, and the plugin never upscales. A 4000x3000 source with the
  /// default 1600 becomes 2133x1600 (short edge lands on 1600, long edge
  /// stays larger); an extreme aspect ratio such as a 6000x1000 panorama may
  /// not be resized at all, since its short edge is already under the
  /// floor, leaving the JPEG quality ladder alone to carry the wire budget.
  final int minShortEdge;

  /// Quality to start stepping down from.
  final int initialQuality;

  /// Quality floor: stepping down stops here even if the target size still
  /// isn't met, so compression can't degrade a photo into noise.
  final int floorQuality;

  /// How much to reduce quality by on each step.
  final int qualityStep;

  const FlutterImageCompressor({
    this.targetBytes = 150 * 1024,
    this.minShortEdge = 1600,
    this.initialQuality = 90,
    this.floorQuality = 30,
    this.qualityStep = 10,
  });

  @override
  Future<Uint8List> compress(String path) async {
    var quality = initialQuality;
    Uint8List? best;
    while (true) {
      final result = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: minShortEdge,
        minHeight: minShortEdge,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (result != null) {
        best = result;
        if (result.lengthInBytes <= targetBytes || quality <= floorQuality) {
          return result;
        }
      } else if (quality <= floorQuality) {
        // The compressor never produced anything usable; fall back to the
        // original file rather than losing the proof entirely.
        return best ?? File(path).readAsBytes();
      }
      quality -= qualityStep;
      if (quality < floorQuality) quality = floorQuality;
    }
  }
}

/// Persists proof photos on local disk, keyed by a generated file name.
abstract class ProofPhotoStore {
  /// Writes [bytes] as a new file and returns its path.
  Future<String> save(Uint8List bytes);

  /// Reads the file at [path]. Returns null when it no longer exists.
  Future<Uint8List?> load(String path);

  /// Removes the file at [path]. A no-op when it's already gone.
  Future<void> delete(String path);
}

/// [ProofPhotoStore] writing to a `proofs/` subdirectory of the path_provider
/// application-documents directory, one `<uuid v7>.jpg` file per photo.
class FileProofPhotoStore implements ProofPhotoStore {
  final Uuid _uuid;

  FileProofPhotoStore({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  Future<Directory> _proofsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}${Platform.pathSeparator}proofs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<String> save(Uint8List bytes) async {
    final dir = await _proofsDir();
    final path = '${dir.path}${Platform.pathSeparator}${_uuid.v7()}.jpg';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  @override
  Future<Uint8List?> load(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      return await file.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (!await file.exists()) return;
    try {
      await file.delete();
    } on FileSystemException {
      // Already gone (raced with another delete); nothing to do.
    }
  }
}
