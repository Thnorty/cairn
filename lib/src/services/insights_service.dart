import '../clock.dart';
import '../db/database.dart';
import '../models/local_date.dart';
import '../repo/completion_repository.dart';
import '../repo/task_repository.dart';
import 'occurrence_generator.dart';
import 'points_service.dart';

/// One Monday..Sunday week in [ConsistencySnapshot.weeks].
class WeeklyConsistency {
  /// The Monday this week starts on (local calendar date).
  final LocalDate weekStart;

  /// Sum, across every active task, of that week's scheduled occurrences on
  /// dates that are strictly BEFORE today - i.e. fully elapsed, the same
  /// "today-pending doesn't count either way yet" rule AGENTS.md's streak
  /// definition uses ("a date counts iff every slot that date is complete
  /// ... only a fully-elapsed incomplete scheduled date [breaks it]"). For
  /// every week except the one containing today this is identical to
  /// counting the whole week (all its dates are already elapsed by
  /// definition); for the current week it excludes today itself (and any
  /// later date in the same week), which is what keeps this week's [rate]
  /// directly comparable to every other week in [ConsistencySnapshot.weeks]
  /// instead of being systematically depressed while the week is still in
  /// progress (see [isPartial]).
  final int scheduled;

  /// Live (non-tombstoned, verified or pending) completions recorded across
  /// that week, any task - including one since archived (same population
  /// `StatsService.stonesPlaced` counts: an already-placed stone keeps
  /// counting even after its task is archived, even though an archived
  /// task no longer contributes to [scheduled] - see
  /// [InsightsService.consistency]'s doc comment). Unlike [scheduled], this
  /// is NOT restricted to elapsed dates: a completion can only ever exist
  /// for today or earlier (no back-filling, per AGENTS.md), so today's own
  /// completions land here even though today itself is excluded from
  /// [scheduled] for the current week.
  final int completed;

  /// `completed / scheduled`, clamped to the closed range `0.0..1.0`, or
  /// null when [scheduled] is 0: a week with nothing scheduled has no rate
  /// to report and is not a failure, so it is never coerced to 0.
  ///
  /// The clamp exists because [completed] and [scheduled] are drawn from
  /// two different populations, so `completed` can legitimately exceed
  /// `scheduled` and push the raw ratio above 1.0:
  ///  1. [scheduled] sums only currently-ACTIVE tasks, while [completed]
  ///     counts live completions across ALL tasks including ones since
  ///     archived - an already-placed stone keeps counting after its task
  ///     is archived (see [completed]'s own doc comment), so archiving a
  ///     task with past completions can leave a week's `completed` counting
  ///     more than its now-shrunken `scheduled`.
  ///  2. For the current (possibly [isPartial]) week, [scheduled] excludes
  ///     today (only fully-elapsed dates count), but [completed] does not -
  ///     today's own completions still land in `completed`, so a
  ///     perfectly-on-track user's partial week can read as "more completed
  ///     than scheduled" purely because today hasn't finished yet.
  ///
  /// Only this derived rate is clamped; [scheduled] and [completed]
  /// themselves are left exactly as counted so the underlying numbers stay
  /// truthful (the same "keep already-placed stones counted after archive"
  /// choice `StatsService.stonesPlaced`/`cairnsBuilt` deliberately make).
  final double? rate;

  /// True for the one week in [ConsistencySnapshot.weeks] that contains
  /// today - i.e. `weekStart == the current Monday`. Lets the UI mark that
  /// week's point as still in progress (e.g. early in the week [scheduled]
  /// may be 0, or the [rate] may simply be based on fewer elapsed days than
  /// a completed week), the same role `StatsWeekdayBar.isFuture` plays for
  /// the Stats screen's own per-day chart.
  final bool isPartial;

  const WeeklyConsistency({
    required this.weekStart,
    required this.scheduled,
    required this.completed,
    required this.rate,
    required this.isPartial,
  });
}

/// The "Consistency, last [InsightsService.consistencyWindowWeeks] weeks"
/// figure (`InsightsService.consistency`): a per-week scheduled/completed/
/// rate series plus an overall rate across the whole window.
class ConsistencySnapshot {
  /// [InsightsService.consistencyWindowWeeks] entries, oldest week first,
  /// ending with the current (possibly still in-progress) week.
  final List<WeeklyConsistency> weeks;

  /// `completed / scheduled` summed over every week in [weeks] that had at
  /// least one scheduled occurrence (a week with nothing scheduled is
  /// excluded rather than counted as a failure - see
  /// [WeeklyConsistency.rate]'s doc comment), clamped to the closed range
  /// `0.0..1.0` for exactly the same two reasons [WeeklyConsistency.rate]'s
  /// own clamp exists (the archived-task population asymmetry between
  /// `scheduled`/`completed`, and today's completions landing in a week
  /// whose `scheduled` excludes today) - summing several weeks' raw counts
  /// does not cancel either effect out, so the aggregate ratio can overshoot
  /// 1.0 exactly like a single week's can. Null when NOT ONE week in the
  /// window had anything scheduled (e.g. a brand-new user with no history).
  final double? overallRate;

  const ConsistencySnapshot({required this.weeks, required this.overallRate});
}

/// The "Best time of day" figure (`InsightsService.bestTimeOfDay`): stone
/// counts bucketed by the LOCAL hour of `Completions.completedAt`, in six
/// four-hour buckets: `[0,4) [4,8) [8,12) [12,16) [16,20) [20,24)`.
class BestTimeOfDay {
  /// Stone counts per bucket, length 6, in the order documented above.
  final List<int> bucketCounts;

  /// Sum of [bucketCounts].
  final int total;

  /// Index (0..5) of the highest-count bucket; the earliest bucket wins a
  /// tie, so this is deterministic. Null when [total] is 0.
  final int? peakBucketIndex;

  const BestTimeOfDay({
    required this.bucketCounts,
    required this.total,
    required this.peakBucketIndex,
  });
}

/// The "Rank projection" figure (`InsightsService.rankProjection`): at the
/// user's recent pace, how long until the next rank tier.
class RankProjection {
  /// The tier immediately above the user's current total altitude.
  final RankTier nextTier;

  /// Metres still needed to reach [nextTier] - the same figure the Profile
  /// rank hero's own progress row shows ([Rank.metresToNext]).
  final int metresRemaining;

  /// Metres per week at the user's recent pace (see
  /// [InsightsService.paceWindowDays]).
  final double metresPerWeek;

  /// `today + ceil(metresRemaining / metresPerDay)`.
  final LocalDate projectedDate;

  const RankProjection({
    required this.nextTier,
    required this.metresRemaining,
    required this.metresPerWeek,
    required this.projectedDate,
  });
}

/// Computes the three "Deeper insights" figures (`Cairn Stats - Deeper
/// Insights.dc.html`): consistency over the last several weeks, the best
/// time of day for proofs, and a rank projection at the user's recent pace.
///
/// Pure read-only logic, no UI and no premium gating here - a later work
/// order builds the Stats screen's "Deeper insights" UI on top of this
/// service and applies the entitlement gate there. Follows [StatsService]'s
/// own structure and dependency style: a handful of injected repositories/
/// services plus a [Clock], no stored state, "today" always read from the
/// clock (never `DateTime.now()` in domain logic, per AGENTS.md).
class InsightsService {
  final TaskRepository _taskRepo;
  final CompletionRepository _completionRepo;
  final OccurrenceGenerator _generator;
  final PointsService _points;
  final Clock _clock;

  /// Number of trailing calendar weeks (Monday..Sunday, ending with the
  /// current week) [consistency] reports. Exposed as a tunable named
  /// constant, the way `ProofPolicy`/[PointsService] expose theirs.
  static const int consistencyWindowWeeks = 8;

  /// Trailing window, in days, ending today, that [rankProjection] samples
  /// verified metres from to compute pace. Same "tunable named constant"
  /// convention as [consistencyWindowWeeks].
  static const int paceWindowDays = 28;

  const InsightsService(
    this._taskRepo,
    this._completionRepo,
    this._generator,
    this._points,
    this._clock,
  );

  /// The Monday..Sunday week start containing [date] (ISO weekday,
  /// 1=Monday). The exact expression [StatsService]'s own "This week" card
  /// and [CompletionRepository.completionsCountForWeekOf] already use,
  /// reused here (not reinvented) so every week-bucketed figure in the app
  /// agrees on where a week begins.
  static LocalDate _weekStart(LocalDate date) => date.addDays(-(date.weekday - 1));

  /// The "Consistency, last [consistencyWindowWeeks] weeks" figure: for
  /// each week, how many occurrences were scheduled versus how many were
  /// completed.
  ///
  /// `scheduled` sums only ACTIVE tasks, over dates strictly BEFORE today -
  /// i.e. fully elapsed (see [WeeklyConsistency.scheduled]'s own doc
  /// comment). This is deliberately NOT [StatsService]'s "This week" card
  /// convention (which counts the whole Monday..Sunday week, future days
  /// included): that convention reads fine for a single "how's this week
  /// going" card, but plotted as a multi-week trend line it systematically
  /// depresses the in-progress week's rate (a perfectly consistent
  /// daily-habit user reads near-0% on a Monday), which is exactly the
  /// point users look at first (the series' final, circled point). Counting
  /// only elapsed dates makes every week in the series directly comparable.
  /// `completed` counts live completions across ALL tasks, archived
  /// included, the same population [StatsService.stonesPlaced] counts, so
  /// an already-placed stone never vanishes from a past week's figure just
  /// because its task was archived later - and, unlike `scheduled`, is NOT
  /// restricted to elapsed dates, so today's own completions still count
  /// toward the current week's total (see [WeeklyConsistency.rate]'s doc
  /// comment on why this can push the rate above 1.0, and why that is
  /// handled with a clamp rather than by changing either population).
  ///
  /// Never divides by zero: a week with nothing scheduled (including the
  /// common case of the current week before anything in it has elapsed yet,
  /// e.g. all day Monday) reports a null [WeeklyConsistency.rate] and is
  /// excluded from [ConsistencySnapshot.overallRate] (see that field's own
  /// doc comment); a database with no history at all returns a well-formed
  /// all-zero/all-null snapshot.
  Future<ConsistencySnapshot> consistency() async {
    final today = _clock.today();
    final currentWeekStart = _weekStart(today);
    final oldestWeekStart = currentWeekStart.addDays(-7 * (consistencyWindowWeeks - 1));
    final windowEnd = currentWeekStart.addDays(6);

    final activeTasks = await _taskRepo.activeTasks();
    final completionsByTask = await _completionRepo.liveCompletionsGroupedByTask();

    final scheduledByDate = <LocalDate, int>{};
    for (final task in activeTasks) {
      for (final occ
          in _generator.occurrencesFor(task, DateRange(oldestWeekStart, windowEnd))) {
        scheduledByDate[occ.date] = (scheduledByDate[occ.date] ?? 0) + 1;
      }
    }

    final completedByDate = <LocalDate, int>{};
    for (final completions in completionsByTask.values) {
      for (final c in completions) {
        if (c.occurrenceDate.isBefore(oldestWeekStart) || c.occurrenceDate.isAfter(windowEnd)) {
          continue;
        }
        completedByDate[c.occurrenceDate] = (completedByDate[c.occurrenceDate] ?? 0) + 1;
      }
    }

    final weeks = <WeeklyConsistency>[];
    var scheduledWithData = 0;
    var completedWithData = 0;
    for (var w = 0; w < consistencyWindowWeeks; w++) {
      final weekStart = oldestWeekStart.addDays(7 * w);
      var scheduled = 0;
      var completed = 0;
      for (var i = 0; i < 7; i++) {
        final date = weekStart.addDays(i);
        // `scheduled` only counts fully-elapsed dates (strictly before
        // today): for every past week every date already satisfies this
        // trivially, but for the current week it excludes today (and any
        // later date in the same week) - see this method's own doc comment
        // on why. `completed` is NOT filtered the same way: a completion
        // can only ever exist for today or earlier (no back-filling), so
        // today's own completions still land here even on the day they
        // happen.
        if (date.isBefore(today)) {
          scheduled += scheduledByDate[date] ?? 0;
        }
        completed += completedByDate[date] ?? 0;
      }
      if (scheduled > 0) {
        scheduledWithData += scheduled;
        completedWithData += completed;
      }
      final rate = scheduled == 0 ? null : (completed / scheduled).clamp(0.0, 1.0);
      weeks.add(WeeklyConsistency(
        weekStart: weekStart,
        scheduled: scheduled,
        completed: completed,
        rate: rate,
        isPartial: weekStart == currentWeekStart,
      ));
    }

    final overallRate = scheduledWithData == 0
        ? null
        : (completedWithData / scheduledWithData).clamp(0.0, 1.0);

    return ConsistencySnapshot(
      weeks: weeks,
      overallRate: overallRate,
    );
  }

  /// The "Best time of day" figure: every live (non-tombstoned, verified or
  /// pending) completion's `completedAt` bucketed by its LOCAL hour into six
  /// four-hour windows: `[0,4) [4,8) [8,12) [12,16) [16,20) [20,24)`.
  /// `DateTime.fromMillisecondsSinceEpoch` (no `isUtc: true`) is the same
  /// epoch-millis-to-local-time conversion the proof-outcome screens already
  /// use to render a completion's time of day.
  Future<BestTimeOfDay> bestTimeOfDay() async {
    final completionsByTask = await _completionRepo.liveCompletionsGroupedByTask();

    final bucketCounts = List<int>.filled(6, 0);
    var total = 0;
    for (final completions in completionsByTask.values) {
      for (final c in completions) {
        final localHour = DateTime.fromMillisecondsSinceEpoch(c.completedAt).hour;
        bucketCounts[localHour ~/ 4]++;
        total++;
      }
    }

    // Earliest bucket wins a tie: strict `>` only advances peakBucketIndex
    // on a NEW high, so the first (lowest-index) bucket reaching the max
    // count is the one that sticks.
    int? peakBucketIndex;
    if (total > 0) {
      var peakCount = -1;
      for (var i = 0; i < bucketCounts.length; i++) {
        if (bucketCounts[i] > peakCount) {
          peakCount = bucketCounts[i];
          peakBucketIndex = i;
        }
      }
    }

    return BestTimeOfDay(bucketCounts: bucketCounts, total: total, peakBucketIndex: peakBucketIndex);
  }

  /// The "Rank projection" figure: at the user's recent pace (VERIFIED
  /// completions' `pointsAwarded` over the trailing [paceWindowDays] days
  /// ending today), how long until the next rank tier.
  ///
  /// Returns null - never a divide-by-zero, never an infinite projection -
  /// when the user is already at the top tier (Summit), or when recent pace
  /// is zero (or, defensively, negative, though `pointsAwarded` is never
  /// negative in practice).
  Future<RankProjection?> rankProjection() async {
    final today = _clock.today();

    final totalAltitude = await _completionRepo.totalAltitude();
    final rank = _points.rankFor(totalAltitude);
    final nextTier = rank.nextTier;
    final metresRemaining = rank.metresToNext;
    if (nextTier == null || metresRemaining == null) {
      return null; // already at Summit
    }

    final windowStart = today.addDays(-(paceWindowDays - 1));
    final completionsByTask = await _completionRepo.liveCompletionsGroupedByTask();

    var pointsInWindow = 0;
    for (final completions in completionsByTask.values) {
      for (final c in completions) {
        if (c.verificationStatus != VerificationStatus.verified) continue;
        if (c.occurrenceDate.isBefore(windowStart) || c.occurrenceDate.isAfter(today)) continue;
        pointsInWindow += c.pointsAwarded;
      }
    }

    final metresPerDay = pointsInWindow / paceWindowDays;
    if (metresPerDay <= 0) return null;

    final daysToNext = (metresRemaining / metresPerDay).ceil();

    return RankProjection(
      nextTier: nextTier,
      metresRemaining: metresRemaining,
      metresPerWeek: metresPerDay * 7,
      projectedDate: today.addDays(daysToNext),
    );
  }
}
