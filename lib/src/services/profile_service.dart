import '../db/database.dart';
import '../repo/completion_repository.dart';
import 'points_service.dart';

/// Everything the Profile ("You") screen shows, computed fresh from the
/// repositories - see `Cairn Profile.dc.html`.
class ProfileSnapshot {
  /// [CompletionRepository.totalAltitude]: verified, non-tombstoned metres
  /// only. This is the number the rank tier/progress-to-next are derived
  /// from - a pending completion's metres never count here (see
  /// [pendingAltitude]'s doc comment on `CompletionRepository.totalAltitude`
  /// for why rank must never move backwards).
  final int totalAltitude;

  /// [CompletionRepository.pendingAltitude]: metres awaiting a verdict.
  /// Shown as a subordinate "+N m awaiting verification" line, never folded
  /// into [totalAltitude].
  final int pendingAltitude;

  /// The tier resolved from [totalAltitude] via [PointsService.rankFor],
  /// and how far (if anywhere) to the next tier.
  final Rank rank;

  const ProfileSnapshot({
    required this.totalAltitude,
    required this.pendingAltitude,
    required this.rank,
  });
}

/// Assembles [ProfileSnapshot] from [CompletionRepository] and keeps it
/// live: [watchProfile] re-emits a freshly-recomputed snapshot whenever the
/// completions table changes (a completion recorded elsewhere, or a pending
/// proof resolving in the background via `ProofRetryTrigger`), so the
/// Profile screen never needs a manual refresh - same reactivity recipe as
/// `HomeService.watchToday` (see that method's doc comment for the
/// rationale behind watching a trigger query rather than hand-combining
/// typed streams).
class ProfileService {
  final AppDatabase _db;
  final CompletionRepository _completionRepo;
  final PointsService _points;

  const ProfileService(this._db, this._completionRepo, this._points);

  Stream<ProfileSnapshot> watchProfile() {
    return _db
        .customSelect('SELECT 1', readsFrom: {_db.completions})
        .watch()
        .asyncMap((_) => _buildSnapshot());
  }

  /// One-shot equivalent of [watchProfile], for callers that don't need
  /// reactivity (e.g. tests asserting a single snapshot).
  Future<ProfileSnapshot> buildSnapshot() => _buildSnapshot();

  Future<ProfileSnapshot> _buildSnapshot() async {
    final total = await _completionRepo.totalAltitude();
    final pending = await _completionRepo.pendingAltitude();
    return ProfileSnapshot(
      totalAltitude: total,
      pendingAltitude: pending,
      rank: _points.rankFor(total),
    );
  }
}
