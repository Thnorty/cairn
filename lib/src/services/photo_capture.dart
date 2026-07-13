import 'dart:io';
import 'dart:typed_data';

import 'package:exif/exif.dart';
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

/// EXIF's placeholder for "no timestamp known", written by some cameras
/// instead of omitting the tag.
const _exifZeroDateTime = '0000:00:00 00:00:00';

/// EXIF date/time format: "YYYY:MM:DD HH:MM:SS" (colons in the date part
/// too, not dashes). No timezone is carried, ever.
final RegExp _exifDateTimePattern =
    RegExp(r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$');

/// Parses an EXIF `DateTimeOriginal`/`DateTimeDigitized`/`DateTime` value
/// ("YYYY:MM:DD HH:MM:SS") into epoch millis. EXIF timestamps carry no
/// timezone, so the value is interpreted as device-*local* time (i.e.
/// whatever `DateTime(...)` without a `.utc` gives on this device).
///
/// A pure, top-level function (no plugin/IO dependency) so it's directly
/// unit-testable. Returns null, rather than throwing, for:
/// - an empty (or all-whitespace) string,
/// - a string that doesn't match the expected shape,
/// - a string that matches the shape but isn't a real calendar date/time
///   (e.g. month 13), since [DateTime]'s constructor silently normalizes
///   overflowing components instead of throwing,
/// - the all-zeroes placeholder some cameras write when they have no clock
///   set.
int? parseExifDateTime(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value == _exifZeroDateTime) return null;

  final match = _exifDateTimePattern.firstMatch(value);
  if (match == null) return null;

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);

  final parsed = DateTime(year, month, day, hour, minute, second);
  // DateTime normalizes out-of-range components (e.g. month 13 rolls into
  // the next year) instead of throwing, so a round-trip mismatch is the
  // only signal that the input wasn't a real date/time.
  if (parsed.year != year ||
      parsed.month != month ||
      parsed.day != day ||
      parsed.hour != hour ||
      parsed.minute != minute ||
      parsed.second != second) {
    return null;
  }
  return parsed.millisecondsSinceEpoch;
}

/// [AssetTimeResolver] fallback backed by in-file EXIF metadata
/// (`DateTimeOriginal`, falling back to `DateTimeDigitized`, then
/// `DateTime`). EXIF is trivial to strip or forge client-side, which is why
/// [PhotoManagerAssetTimeResolver]'s photo-library lookup is tried first and
/// stays authoritative; this only fires when that lookup returns null, e.g.
/// on Android 13+ where the system Photo Picker hands the app a *copy* of
/// the asset (in the app's own cache dir, under a name the library lookup
/// can't match) even though the copy's bytes still carry the original
/// EXIF block.
///
/// A screenshot typically carries no `DateTimeOriginal` (or any capture
/// timestamp) at all, so this resolves to null for one too, same as the
/// photo-library lookup, and recency fails open. That's deliberate:
/// screenshot detection is the verifier's job
/// ([ProofVerdict.isScreenshotOrScreen]), not recency's.
class ExifAssetTimeResolver implements AssetTimeResolver {
  /// EXIF tag keys to check, in priority order, as returned by
  /// `readExifFromBytes` (each key is `"<IFD name> <tag name>"`).
  static const _tagKeys = [
    'EXIF DateTimeOriginal',
    'EXIF DateTimeDigitized',
    'Image DateTime',
  ];

  const ExifAssetTimeResolver();

  @override
  Future<int?> takenAtFor(String pickedPath) async {
    try {
      final bytes = await File(pickedPath).readAsBytes();
      final tags = await readExifFromBytes(bytes);
      for (final key in _tagKeys) {
        final tag = tags[key];
        if (tag == null) continue;
        final parsed = parseExifDateTime(tag.printable);
        if (parsed != null) return parsed;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// [AssetTimeResolver] that tries a list of resolvers in order and returns
/// the first non-null result.
///
/// A resolver that throws is treated exactly like one that returns null: it
/// must not break the chain, since every resolver here is already a
/// best-effort lookup ([AssetTimeResolver.takenAtFor] documents "never
/// throws", but this chain doesn't rely on that promise being honoured by
/// every implementation).
class ChainedAssetTimeResolver implements AssetTimeResolver {
  final List<AssetTimeResolver> _resolvers;

  const ChainedAssetTimeResolver(this._resolvers);

  @override
  Future<int?> takenAtFor(String pickedPath) async {
    for (final resolver in _resolvers) {
      try {
        final result = await resolver.takenAtFor(pickedPath);
        if (result != null) return result;
      } catch (_) {
        // Fall through to the next resolver.
      }
    }
    return null;
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
