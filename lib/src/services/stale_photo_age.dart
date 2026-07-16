/// Pure helper for `Cairn Verify Too Old.dc.html`: how old a rejected proof
/// photo's own capture timestamp was, given the [Clock]'s "now" at the
/// moment of rejection.
///
/// Factored out of [VerifyTooOldScreen] (see `verify_too_old_screen.dart`)
/// rather than computed inline, per CLAUDE.md's "no DateTime.now() in
/// domain code" / "nothing computed in a widget" rules: this file has its
/// own unit tests independent of the widget tree, and the widget only ever
/// receives the already-computed minute count.
library;

/// Rounds `(nowMillis - photoTakenAtMillis)` to the nearest whole minute for
/// the "N min old" badge. Ties round up (matching [double.round]'s own
/// behaviour), so e.g. 17 minutes 40 seconds reads as "18 min old" rather
/// than understating the age as "17 min old".
///
/// Both timestamps are epoch millis from the same [Clock] the caller used
/// to build them (see `proof_outcome_routing.dart`'s
/// `CompletionRejectedStalePhoto` handling), never `DateTime.now()`.
int stalePhotoAgeMinutes({
  required int photoTakenAtMillis,
  required int nowMillis,
}) {
  final ageMillis = nowMillis - photoTakenAtMillis;
  return (ageMillis / Duration.millisecondsPerMinute).round();
}
