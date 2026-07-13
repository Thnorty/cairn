/// Rank tiers by cumulative metres climbed.
enum RankTier {
  pebble(0, 'Pebble'),
  cairn(150, 'Cairn'),
  ridge(450, 'Ridge'),
  crag(1100, 'Crag'),
  bluff(2400, 'Bluff'),
  peak(5000, 'Peak'),
  summit(8849, 'Summit');

  final int thresholdMetres;
  final String label;

  const RankTier(this.thresholdMetres, this.label);
}

/// A resolved rank: which tier, and how far to the next one.
class Rank {
  final RankTier tier;
  final int metres;

  const Rank(this.tier, this.metres);

  /// Metres still needed to reach the next tier, or null at Summit (the top).
  int? get metresToNext {
    final next = _nextTier();
    if (next == null) return null;
    return next.thresholdMetres - metres;
  }

  RankTier? _nextTier() {
    final tiers = RankTier.values;
    final i = tiers.indexOf(tier);
    return i + 1 < tiers.length ? tiers[i + 1] : null;
  }

  @override
  String toString() => '${tier.label} ($metres m)';
}

/// Points/rank rules:
/// - Base 10 m per verified completion.
/// - Per-task streak bonus: +1 m per consecutive day of that task's current
///   streak (the streak *after* this completion), capped at +10 m.
/// - Perfect-day bonus: +15 m attached to the day's final scheduled
///   occurrence (across all tasks) when it completes.
class PointsService {
  static const int basePoints = 10;
  static const int maxStreakBonus = 10;
  static const int perfectDayBonus = 15;

  const PointsService();

  /// Points for a single completion, given the task's streak length
  /// *including* this completion, and whether it was the day's final
  /// scheduled occurrence to complete.
  int pointsForCompletion({
    required int streakLengthIncludingThis,
    required bool isPerfectDayFinalOccurrence,
  }) {
    final streakBonus =
        streakLengthIncludingThis.clamp(0, maxStreakBonus);
    var points = basePoints + streakBonus;
    if (isPerfectDayFinalOccurrence) points += perfectDayBonus;
    return points;
  }

  /// Total altitude: sum of points_awarded over non-tombstoned completions.
  /// Callers pass the already-filtered list.
  int totalAltitude(Iterable<int> pointsAwarded) =>
      pointsAwarded.fold(0, (sum, p) => sum + p);

  /// Resolves the rank tier for [metres] and how far to the next tier.
  Rank rankFor(int metres) {
    var tier = RankTier.pebble;
    for (final t in RankTier.values) {
      if (metres >= t.thresholdMetres) {
        tier = t;
      } else {
        break;
      }
    }
    return Rank(tier, metres);
  }
}
