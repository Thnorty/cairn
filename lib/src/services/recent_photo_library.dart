import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:photo_manager/photo_manager.dart';

/// A single recent photo-library asset offered as a quick-pick proof source
/// on `Cairn Camera Unavailable.dc.html`'s "Recent photos" grid: a
/// pre-decoded thumbnail for the grid cell, and the asset's own capture
/// time (for the recency check, exactly like any other gallery pick - see
/// [RecentPhotoLibrary]'s doc comment).
class RecentPhotoAsset {
  final String id;
  final Uint8List thumbnail;
  final int takenAtMillis;

  const RecentPhotoAsset({
    required this.id,
    required this.thumbnail,
    required this.takenAtMillis,
  });
}

/// Outcome of [RecentPhotoLibrary.loadRecent].
sealed class RecentPhotosResult {
  const RecentPhotosResult();
}

/// The photo library was readable; [assets] is the most recent assets
/// found, newest first (possibly empty - no photos at all).
class RecentPhotosLoaded extends RecentPhotosResult {
  final List<RecentPhotoAsset> assets;
  const RecentPhotosLoaded(this.assets);
}

/// The photo library could not be read at all (permission denied, or the
/// plugin call failed). The Camera Unavailable screen degrades to a plain
/// "Choose from gallery" button rather than a broken/empty grid in this
/// case - see [RecentPhotosLoaded] with an empty list for the "readable but
/// no photos" case, which degrades the same way.
class RecentPhotosUnavailable extends RecentPhotosResult {
  const RecentPhotosUnavailable();
}

/// Abstraction over the device photo library's most-recent-assets listing,
/// backing `Cairn Camera Unavailable.dc.html`'s "Recent photos" quick-pick
/// grid.
///
/// Kept as its own small interface (matching the existing
/// [AssetTimeResolver]/[PhotoCapture] pattern in `photo_capture.dart`) so
/// widget tests can drive the grid with a fake and never touch
/// `photo_manager`'s platform channel, which `flutter test` cannot exercise.
abstract class RecentPhotoLibrary {
  /// Loads up to [count] of the most recently added image assets, newest
  /// first, with their thumbnail bytes already decoded for the grid.
  Future<RecentPhotosResult> loadRecent({required int count});

  /// Resolves [assetId] to a file path on disk, for submission through the
  /// same compress/save/complete pipeline every other proof source uses
  /// (`ProofFlowService.submitCapturedProof`). Null when the asset can no
  /// longer be resolved (e.g. deleted from the library between the grid
  /// load and the tap).
  Future<String?> filePathFor(String assetId);
}

/// [RecentPhotoLibrary] backed by `photo_manager`.
class PhotoManagerRecentPhotoLibrary implements RecentPhotoLibrary {
  /// Thumbnail size requested from `photo_manager`, matching the grid
  /// cell's roughly-square aspect ratio at typical phone widths.
  static const _thumbnailSize = ThumbnailSize(240, 240);

  /// The newest-first filter this class asks `photo_manager` for.
  ///
  /// Real-device regression fix: without an explicit `orders`,
  /// `photo_manager` doesn't guarantee newest-first, so this grid could
  /// (and did) show stale photos instead of the most recent ones.
  /// `createDate desc` is exactly the "newest first" this screen's own doc
  /// comment (and [RecentPhotosLoaded]'s) promises its caller.
  ///
  /// Extracted to its own testable getter (rather than inlined at the call
  /// site below) because `flutter test` cannot exercise
  /// `PhotoManager.getAssetPathList` itself (it's a real platform-channel
  /// call - see this file's own doc comment on why [RecentPhotoLibrary] is
  /// an interface at all) but *can* construct and inspect this plain
  /// `FilterOptionGroup` value with no plugin involved - see
  /// `recent_photo_library_test.dart`.
  @visibleForTesting
  static FilterOptionGroup get newestFirstFilter => FilterOptionGroup(
        orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
      );

  const PhotoManagerRecentPhotoLibrary();

  @override
  Future<RecentPhotosResult> loadRecent({required int count}) async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) return const RecentPhotosUnavailable();

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
        filterOption: newestFirstFilter,
      );
      if (albums.isEmpty) return const RecentPhotosLoaded([]);

      final candidates = await albums.first.getAssetListRange(
        start: 0,
        end: count,
      );

      final assets = <RecentPhotoAsset>[];
      for (final asset in candidates) {
        final thumb = await asset.thumbnailDataWithSize(_thumbnailSize);
        if (thumb == null) continue;
        assets.add(RecentPhotoAsset(
          id: asset.id,
          thumbnail: thumb,
          takenAtMillis: asset.createDateTime.millisecondsSinceEpoch,
        ));
      }
      return RecentPhotosLoaded(assets);
    } catch (_) {
      return const RecentPhotosUnavailable();
    }
  }

  @override
  Future<String?> filePathFor(String assetId) async {
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) return null;
      final file = await asset.file;
      return file?.path;
    } catch (_) {
      return null;
    }
  }
}
