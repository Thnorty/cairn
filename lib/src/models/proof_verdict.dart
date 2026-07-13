import 'dart:typed_data';

import '../db/database.dart';

/// Structured verdict returned by a proof verifier (the Supabase Edge
/// Function's JSON schema in the real implementation). Keys are snake_case
/// to match the wire format.
class ProofVerdict {
  /// Whether the photo shows the task being done.
  final bool taskShown;

  /// Verifier confidence in [taskShown], 0..1.
  final double confidence;

  /// Whether the photo is a screenshot or a photo of a screen.
  final bool isScreenshotOrScreen;

  /// Whether screen content is plausible evidence for this specific task
  /// (e.g. a step-counter app for a walking task).
  final bool screenIsPlausibleProof;

  /// Human-readable explanation from the verifier.
  final String reason;

  const ProofVerdict({
    required this.taskShown,
    required this.confidence,
    required this.isScreenshotOrScreen,
    required this.screenIsPlausibleProof,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'task_shown': taskShown,
        'confidence': confidence,
        'is_screenshot_or_screen': isScreenshotOrScreen,
        'screen_is_plausible_proof': screenIsPlausibleProof,
        'reason': reason,
      };

  factory ProofVerdict.fromJson(Map<String, dynamic> json) => ProofVerdict(
        taskShown: json['task_shown'] as bool,
        confidence: (json['confidence'] as num).toDouble(),
        isScreenshotOrScreen: json['is_screenshot_or_screen'] as bool,
        screenIsPlausibleProof: json['screen_is_plausible_proof'] as bool,
        reason: json['reason'] as String,
      );
}

/// Policy knobs for proof verification and its daily/per-task limits.
///
/// Screens are a cheat vector: a fresh screenshot of an old photo defeats the
/// recency check. But tasks whose natural evidence *is* a screen (a step
/// counter, a language-learning app) must stay verifiable, so screen content
/// is allowed when the verifier judges a screen plausible proof for the task
/// text.
class ProofPolicy {
  /// Minimum verifier confidence for a proof to count.
  final double confidenceThreshold;

  /// Maximum successful (verified or pending) completions per local day,
  /// across all tasks. Rejections do not burn this cap.
  final int dailyCap;

  /// Maximum rejected verification attempts per task per local day, shared
  /// across slots.
  final int attemptsPerTaskPerDay;

  /// Recency pre-filter window: how old a proof photo's own capture
  /// timestamp (from asset metadata, not in-file EXIF) may be before the
  /// photo is rejected as stale without ever reaching the verifier.
  final Duration recencyWindow;

  /// Whether a photo with an unknown capture timestamp counts as recent.
  /// Defaults to true (fail open): recency is only a cheap pre-filter ahead
  /// of the real gate (Gemini judges the actual photo content), and
  /// photo_manager lookups legitimately fail on limited-permission photo
  /// libraries or cloud-only assets that haven't downloaded yet, so treating
  /// "unknown" as "stale" would reject perfectly legitimate proofs.
  final bool allowUnknownPhotoTime;

  const ProofPolicy({
    this.confidenceThreshold = 0.6,
    this.dailyCap = 5,
    this.attemptsPerTaskPerDay = 3,
    this.recencyWindow = const Duration(minutes: 15),
    this.allowUnknownPhotoTime = true,
  });

  /// Whether [v] passes as a verified proof under this policy.
  bool isVerified(ProofVerdict v) =>
      v.taskShown &&
      v.confidence >= confidenceThreshold &&
      (!v.isScreenshotOrScreen || v.screenIsPlausibleProof);

  /// Whether a photo whose capture time (per asset metadata) was
  /// [photoTakenAtMillis] epoch millis counts as recent as of [nowMillis].
  ///
  /// - A null timestamp falls back to [allowUnknownPhotoTime]: see its doc
  ///   comment for why failing open is deliberate.
  /// - A timestamp exactly [recencyWindow] old is still recent (inclusive
  ///   boundary); one millisecond older is not.
  /// - A timestamp in the future (device clock skew) always counts as
  ///   recent: there's no cheating advantage to a photo claiming to be
  ///   *newer* than now, only to one claiming to be older than it is.
  bool isRecent(int? photoTakenAtMillis, int nowMillis) {
    if (photoTakenAtMillis == null) return allowUnknownPhotoTime;
    final ageMillis = nowMillis - photoTakenAtMillis;
    return ageMillis <= recencyWindow.inMilliseconds;
  }
}

/// The proof payload a caller submits with a completion attempt.
class ProofData {
  /// The (compressed) image to send to the verifier.
  final Uint8List imageBytes;

  /// Local path the proof photo is stored at, if persisted.
  final String? photoPath;

  /// Where the photo came from (camera or gallery).
  final ProofSource? source;

  /// Capture time from asset metadata (epoch millis), for the recency check.
  final int? photoTakenAt;

  const ProofData({
    required this.imageBytes,
    this.photoPath,
    this.source,
    this.photoTakenAt,
  });
}
