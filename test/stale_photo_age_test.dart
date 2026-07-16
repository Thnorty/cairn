import 'package:cairn/src/services/stale_photo_age.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stalePhotoAgeMinutes', () {
    test('a photo taken exactly 15 minutes ago rounds to 15', () {
      const takenAt = 1000;
      const now = takenAt + 15 * 60000;
      expect(
        stalePhotoAgeMinutes(photoTakenAtMillis: takenAt, nowMillis: now),
        15,
      );
    });

    test('an older photo (well past the recency window) reports its true '
        'age in whole minutes', () {
      const takenAt = 1000;
      const now = takenAt + 42 * 60000;
      expect(
        stalePhotoAgeMinutes(photoTakenAtMillis: takenAt, nowMillis: now),
        42,
      );
    });

    test('rounds to the nearest whole minute rather than flooring', () {
      const takenAt = 1000;
      // 17 minutes 40 seconds: rounds up to 18, not down to 17.
      const now = takenAt + 17 * 60000 + 40000;
      expect(
        stalePhotoAgeMinutes(photoTakenAtMillis: takenAt, nowMillis: now),
        18,
      );

      // 16 minutes 20 seconds: rounds down to 16.
      const now2 = takenAt + 16 * 60000 + 20000;
      expect(
        stalePhotoAgeMinutes(photoTakenAtMillis: takenAt, nowMillis: now2),
        16,
      );
    });
  });
}
