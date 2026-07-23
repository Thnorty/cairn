import '../db/database.dart';

/// A stone count and last-climb timestamp for one side of the account-upgrade
/// sign-in chooser (`AccountService.signIn`, WO-A of the Phase 4b account
/// upgrade): "this device's local trail" vs. "the signed-in account's cloud
/// trail". "Stones" matches the app's existing vocabulary: live
/// (non-tombstoned) completions, verified or pending alike.
///
/// [lastClimbAt] is the local time the most recent stone was recorded (its
/// completion's `completed_at`), null iff [stones] is 0.
class TrailSummary {
  final int stones;
  final DateTime? lastClimbAt;

  const TrailSummary({required this.stones, this.lastClimbAt});

  @override
  String toString() =>
      'TrailSummary(stones: $stones, lastClimbAt: $lastClimbAt)';

  @override
  bool operator ==(Object other) =>
      other is TrailSummary &&
      other.stones == stones &&
      other.lastClimbAt == lastClimbAt;

  @override
  int get hashCode => Object.hash(stones, lastClimbAt);
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
  final maxCompletedAt =
      list.map((c) => c.completedAt).reduce((a, b) => a > b ? a : b);
  return TrailSummary(
    stones: list.length,
    lastClimbAt: DateTime.fromMillisecondsSinceEpoch(maxCompletedAt),
  );
}
