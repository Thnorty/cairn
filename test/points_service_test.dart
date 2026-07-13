import 'package:cairn/src/services/points_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = PointsService();

  group('pointsForCompletion', () {
    test('base 10 m with no streak and no perfect-day bonus', () {
      expect(
        service.pointsForCompletion(
          streakLengthIncludingThis: 1,
          isPerfectDayFinalOccurrence: false,
        ),
        11, // base 10 + streak bonus 1 (day 1 of streak)
      );
    });

    test('streak bonus scales with consecutive days', () {
      expect(
        service.pointsForCompletion(
          streakLengthIncludingThis: 5,
          isPerfectDayFinalOccurrence: false,
        ),
        15, // 10 + 5
      );
    });

    test('streak bonus caps at +10 m even for very long streaks', () {
      expect(
        service.pointsForCompletion(
          streakLengthIncludingThis: 50,
          isPerfectDayFinalOccurrence: false,
        ),
        20, // 10 + capped 10
      );
      expect(
        service.pointsForCompletion(
          streakLengthIncludingThis: 11,
          isPerfectDayFinalOccurrence: false,
        ),
        20,
      );
      expect(
        service.pointsForCompletion(
          streakLengthIncludingThis: 10,
          isPerfectDayFinalOccurrence: false,
        ),
        20,
      );
    });

    test('perfect-day bonus of +15 m attaches to the final occurrence', () {
      expect(
        service.pointsForCompletion(
          streakLengthIncludingThis: 3,
          isPerfectDayFinalOccurrence: true,
        ),
        10 + 3 + 15,
      );
    });

    test('perfect-day bonus stacks on top of a capped streak bonus', () {
      expect(
        service.pointsForCompletion(
          streakLengthIncludingThis: 40,
          isPerfectDayFinalOccurrence: true,
        ),
        10 + 10 + 15,
      );
    });
  });

  group('totalAltitude', () {
    test('sums points across completions', () {
      expect(service.totalAltitude([11, 15, 25, 0]), 51);
    });

    test('empty history sums to zero', () {
      expect(service.totalAltitude(const []), 0);
    });
  });

  group('rankFor boundaries', () {
    test('149 m is still Pebble', () {
      expect(service.rankFor(149).tier, RankTier.pebble);
    });

    test('150 m is exactly Cairn', () {
      expect(service.rankFor(150).tier, RankTier.cairn);
    });

    test('449 m is Cairn, 450 m is Ridge', () {
      expect(service.rankFor(449).tier, RankTier.cairn);
      expect(service.rankFor(450).tier, RankTier.ridge);
    });

    test('1099 m is Ridge, 1100 m is Crag', () {
      expect(service.rankFor(1099).tier, RankTier.ridge);
      expect(service.rankFor(1100).tier, RankTier.crag);
    });

    test('2399 m is Crag, 2400 m is Bluff', () {
      expect(service.rankFor(2399).tier, RankTier.crag);
      expect(service.rankFor(2400).tier, RankTier.bluff);
    });

    test('4999 m is Bluff, 5000 m is Peak', () {
      expect(service.rankFor(4999).tier, RankTier.bluff);
      expect(service.rankFor(5000).tier, RankTier.peak);
    });

    test('8849 m is exactly Summit, and stays Summit beyond', () {
      expect(service.rankFor(8849).tier, RankTier.summit);
      expect(service.rankFor(20000).tier, RankTier.summit);
    });

    test('0 m is Pebble', () {
      expect(service.rankFor(0).tier, RankTier.pebble);
    });
  });

  group('metresToNext', () {
    test('reports remaining metres to the next tier', () {
      expect(service.rankFor(100).metresToNext, 50); // → Cairn at 150
      expect(service.rankFor(150).metresToNext, 300); // → Ridge at 450
    });

    test('is null at the top tier (Summit)', () {
      expect(service.rankFor(8849).metresToNext, isNull);
      expect(service.rankFor(50000).metresToNext, isNull);
    });
  });
}
