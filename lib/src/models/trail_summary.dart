import '../db/database.dart';
import 'local_date.dart';

/// A stone count and last-climb date for one side of the account-upgrade
/// sign-in chooser (`AccountService.signIn`, WO-A of the Phase 4b account
/// upgrade): "this device's local trail" vs. "the signed-in account's cloud
/// trail". "Stones" matches the app's existing vocabulary: live
/// (non-tombstoned) completions, verified or pending alike.
///
/// [lastClimb] is null iff [stones] is 0.
class TrailSummary {
  final int stones;
  final LocalDate? lastClimb;

  const TrailSummary({required this.stones, this.lastClimb});

  @override
  String toString() => 'TrailSummary(stones: $stones, lastClimb: $lastClimb)';

  @override
  bool operator ==(Object other) =>
      other is TrailSummary &&
      other.stones == stones &&
      other.lastClimb == lastClimb;

  @override
  int get hashCode => Object.hash(stones, lastClimb);
}

/// Reduces a set of live completions to a [TrailSummary]: shared by
/// [CompletionRepository.localTrailSummary] (this device) and
/// [SyncService.remoteTrailSummary] (the signed-in account's cloud data, via
/// a pull) so the two summaries the chooser compares are computed exactly
/// the same way. Callers are responsible for pre-filtering to live
/// (non-tombstoned) rows; this makes no assumption about [liveCompletions]
/// beyond that.
TrailSummary trailSummaryFromCompletions(Iterable<Completion> liveCompletions) {
  final list = liveCompletions.toList();
  if (list.isEmpty) return const TrailSummary(stones: 0);
  final last = list.map((c) => c.occurrenceDate).reduce(LocalDate.max);
  return TrailSummary(stones: list.length, lastClimb: last);
}
