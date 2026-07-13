import 'package:cairn/src/services/photo_capture.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test double for [AssetTimeResolver] that either returns a scripted value
/// or throws, and records how many times it was called.
class _FakeAssetTimeResolver implements AssetTimeResolver {
  final int? Function()? _result;
  int callCount = 0;

  _FakeAssetTimeResolver.returning(int? value) : _result = (() => value);
  _FakeAssetTimeResolver.throwing() : _result = null;

  @override
  Future<int?> takenAtFor(String pickedPath) async {
    callCount++;
    final result = _result;
    if (result == null) {
      throw StateError('boom');
    }
    return result();
  }
}

void main() {
  group('parseExifDateTime', () {
    test('a valid timestamp parses to the right local-time epoch millis', () {
      final expected = DateTime(2026, 7, 13, 14, 5, 9).millisecondsSinceEpoch;
      expect(parseExifDateTime('2026:07:13 14:05:09'), expected);
    });

    test('an empty string returns null', () {
      expect(parseExifDateTime(''), isNull);
    });

    test('an all-whitespace string returns null', () {
      expect(parseExifDateTime('   '), isNull);
    });

    test('a malformed string returns null', () {
      expect(parseExifDateTime('not a date'), isNull);
      // Dashes instead of EXIF's colons in the date part.
      expect(parseExifDateTime('2026-07-13 14:05:09'), isNull);
      // Truncated.
      expect(parseExifDateTime('2026:07:13 14:05'), isNull);
    });

    test('numeric but out-of-range components return null', () {
      // DateTime's constructor silently normalizes overflowing components
      // (e.g. month 13 rolls into next year) rather than throwing; the
      // parser must catch that via a round-trip check rather than let it
      // through as a "valid" but wrong date.
      expect(parseExifDateTime('2026:13:40 25:61:61'), isNull);
    });

    test('the all-zeroes placeholder returns null', () {
      expect(parseExifDateTime('0000:00:00 00:00:00'), isNull);
    });
  });

  group('ChainedAssetTimeResolver', () {
    test('the first non-null result wins, and later resolvers are not '
        'consulted', () async {
      final first = _FakeAssetTimeResolver.returning(111);
      final second = _FakeAssetTimeResolver.returning(222);
      final chain = ChainedAssetTimeResolver([first, second]);

      expect(await chain.takenAtFor('/tmp/photo.jpg'), 111);
      expect(first.callCount, 1);
      expect(second.callCount, 0);
    });

    test('a null result falls through to the next resolver', () async {
      final first = _FakeAssetTimeResolver.returning(null);
      final second = _FakeAssetTimeResolver.returning(222);
      final chain = ChainedAssetTimeResolver([first, second]);

      expect(await chain.takenAtFor('/tmp/photo.jpg'), 222);
    });

    test('a resolver that throws is treated as null and skipped, not '
        'propagated', () async {
      final first = _FakeAssetTimeResolver.throwing();
      final second = _FakeAssetTimeResolver.returning(333);
      final chain = ChainedAssetTimeResolver([first, second]);

      expect(await chain.takenAtFor('/tmp/photo.jpg'), 333);
      expect(first.callCount, 1);
      expect(second.callCount, 1);
    });

    test('all resolvers null (or throwing) yields null', () async {
      final first = _FakeAssetTimeResolver.throwing();
      final second = _FakeAssetTimeResolver.returning(null);
      final chain = ChainedAssetTimeResolver([first, second]);

      expect(await chain.takenAtFor('/tmp/photo.jpg'), isNull);
    });

    test('an empty resolver list yields null', () async {
      const chain = ChainedAssetTimeResolver([]);
      expect(await chain.takenAtFor('/tmp/photo.jpg'), isNull);
    });
  });
}
