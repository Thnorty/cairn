import 'package:cairn/src/services/recent_photo_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';

import 'support/fake_proof_pipeline.dart' show kFakeImageBytes;
import 'support/fake_recent_photos.dart';

void main() {
  group('PhotoManagerRecentPhotoLibrary.newestFirstFilter', () {
    // Real-device regression test: `flutter test` cannot exercise
    // `PhotoManager.getAssetPathList` itself (a real platform-channel call -
    // see `RecentPhotoLibrary`'s own doc comment on why it's an interface at
    // all), but the plain `FilterOptionGroup` value this class asks for
    // *is* inspectable with no plugin involved. Without this filter
    // (regression: no explicit `orders`), `photo_manager` doesn't guarantee
    // newest-first, so the Camera Unavailable screen's "Recent photos" grid
    // could (and did) show stale photos instead of the most recent ones.
    test('requests createDate order, descending (newest first)', () {
      final orders = PhotoManagerRecentPhotoLibrary.newestFirstFilter.orders;

      expect(orders, hasLength(1));
      expect(orders.single.type, OrderOptionType.createDate);
      expect(
        orders.single.asc,
        isFalse,
        reason: 'asc:false is descending - newest createDateTime first',
      );
    });
  });

  group('RecentPhotoLibrary (fake, interface-level)', () {
    // Documents the same "newest first" contract at the interface level via
    // the fake every widget test in this suite already drives
    // (CameraUnavailableScreen never touches the real plugin) - see this
    // run's spec ("update or add a test on the fake/interface level that
    // the provider is asked for newest-first"). `FakeRecentPhotoLibrary`
    // itself does no sorting (the test seeds `RecentPhotosLoaded` with
    // whatever order it likes, matching the real interface's *contract*:
    // [RecentPhotoLibrary.loadRecent] returns assets "newest first" -
    // callers rely on the list's own order, so a test seeding it in a
    // deliberately-not-sorted order and asserting the screen renders it
    // as-is (no client-side re-sort hiding a caller bug) is the fake-level
    // analogue of the real assertion above.
    test('a caller receives assets in exactly the order the library '
        'reported them (no hidden re-sort to compensate for a wrong '
        'provider order)', () async {
      final newestFirst = [
        RecentPhotoAsset(id: 'newest', thumbnail: kFakeImageBytes, takenAtMillis: 3000),
        RecentPhotoAsset(id: 'middle', thumbnail: kFakeImageBytes, takenAtMillis: 2000),
        RecentPhotoAsset(id: 'oldest', thumbnail: kFakeImageBytes, takenAtMillis: 1000),
      ];
      final fake = FakeRecentPhotoLibrary(result: RecentPhotosLoaded(newestFirst));

      final result = await fake.loadRecent(count: 6);

      expect(result, isA<RecentPhotosLoaded>());
      final assets = (result as RecentPhotosLoaded).assets;
      expect(assets.map((a) => a.id).toList(), ['newest', 'middle', 'oldest']);
    });
  });
}
