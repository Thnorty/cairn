import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../models/local_date.dart';
import '../../models/proof_verdict.dart';
import '../../providers.dart';
import '../../repo/completion_repository.dart';
import 'camera_capture_screen.dart';
import 'daily_limit_screen.dart';
import 'verify_failed_screen.dart';
import 'verify_pending_screen.dart';
import 'verify_result_screen.dart';

/// Routes to the correct outcome screen for a [CompleteOccurrenceResult], or
/// does nothing and returns false for the handful of rejections "not
/// reachable from a correct UI" (back-fill, not-scheduled, task-not-found,
/// already-completed) - the caller surfaces those minimally itself (e.g. a
/// snackbar), per the phase-3 spec.
///
/// Shared by Home's "Prove it" precheck short-circuit (never opens the
/// camera on a doomed attempt - see `home_screen.dart`) and
/// [CameraCaptureScreen]'s post-submit routing, so both paths land on
/// identical screens for identical outcomes - in particular the two cap
/// rejections, which either path can produce (a precheck-time cap, or a
/// race that only surfaces after a fresh submit).
///
/// Every number the outcome screens show (stone counts, tries left, the
/// daily cap) is re-read from the repositories/services here, never
/// computed from the caller's own stale snapshot - see CLAUDE.md's "nothing
/// hardcoded, nothing computed in a widget" rule for this run.
Future<bool> routeToProofOutcome(
  BuildContext context,
  WidgetRef ref, {
  required CompleteOccurrenceResult result,
  required String taskId,
  required String taskTitle,
  required int cairnNumber,
  required LocalDate occurrenceDate,
  required int slot,
  Uint8List? imageBytes,
  bool replace = false,
}) async {
  final completionRepo = ref.read(completionRepositoryProvider);
  final policy = ref.read(proofPolicyProvider);
  final clock = ref.read(clockProvider);

  // Captured once, synchronously, before any `await` below: the NavigatorState
  // itself (not the raw BuildContext) stays valid for the outcome screen's
  // whole lifetime, including callbacks (onDone/onCancel/onRetake) that don't
  // fire until long after this function returns - by then, the *calling*
  // screen's own context (e.g. CameraCaptureScreen's, replaced via
  // pushReplacement the moment `go` below runs) is long since unmounted, and
  // re-deriving `Navigator.of(context)` from it at that point throws a null
  // check failure on the disposed element. The Navigator ancestor's State
  // itself has no such lifetime problem, since it belongs to a widget further
  // up the tree that these navigation calls don't replace.
  final navigator = Navigator.of(context);

  void go(Widget screen) {
    final route = MaterialPageRoute<void>(builder: (_) => screen);
    if (replace) {
      navigator.pushReplacement(route);
    } else {
      navigator.push(route);
    }
  }

  void popToHome() => navigator.pop();

  void retake() {
    navigator.pushReplacement(MaterialPageRoute<void>(
      builder: (_) => CameraCaptureScreen(
        taskId: taskId,
        taskTitle: taskTitle,
        cairnNumber: cairnNumber,
        occurrenceDate: occurrenceDate,
        slot: slot,
      ),
    ));
  }

  switch (result) {
    case CompletionRecorded(:final completion):
      final counts = await completionRepo.liveCompletionCountsByTask();
      if (!context.mounted) return true;
      go(VerifyResultScreen(
        taskTitle: taskTitle,
        completedAtMillis: completion.completedAt,
        imageBytes: imageBytes!,
        reason: _verdictReasonFrom(completion.verificationMeta) ?? '',
        cairnNumber: cairnNumber,
        stoneCount: counts[taskId] ?? 0,
        onDone: popToHome,
      ));
      return true;

    case CompletionPendingVerification(:final completion):
      go(VerifyPendingScreen(
        taskTitle: taskTitle,
        completedAtMillis: completion.completedAt,
        imageBytes: imageBytes!,
        heldMetres: completion.pointsAwarded,
        onBackToToday: popToHome,
      ));
      return true;

    case CompletionRejectedByVerifier(:final verdict, :final attemptsRemaining):
      final counts = await completionRepo.liveCompletionCountsByTask();
      if (!context.mounted) return true;
      go(VerifyFailedScreen(
        taskTitle: taskTitle,
        atMillis: clock.nowEpochMillis(),
        imageBytes: imageBytes,
        cairnNumber: cairnNumber,
        stoneCount: counts[taskId] ?? 0,
        attemptsRemaining: attemptsRemaining,
        reason: attemptsRemaining > 0 ? verdict.reason : null,
        onRetake: attemptsRemaining > 0 ? retake : null,
        onCancel: popToHome,
      ));
      return true;

    case CompletionRejectedStalePhoto():
      final counts = await completionRepo.liveCompletionCountsByTask();
      final attemptsUsed = await completionRepo.attemptsUsedToday(taskId);
      if (!context.mounted) return true;
      final remaining = policy.attemptsPerTaskPerDay - attemptsUsed;
      final l10n = AppLocalizations.of(context)!;
      go(VerifyFailedScreen(
        taskTitle: taskTitle,
        atMillis: clock.nowEpochMillis(),
        imageBytes: imageBytes,
        cairnNumber: cairnNumber,
        stoneCount: counts[taskId] ?? 0,
        attemptsRemaining: remaining < 0 ? 0 : remaining,
        reason: l10n.stalePhotoReason,
        onRetake: retake,
        onCancel: popToHome,
      ));
      return true;

    case CompletionRejectedDailyCapReached():
      go(DailyLimitScreen(
        dailyCap: policy.dailyCap,
        // The Premium screen is a separate, not-yet-built run (same scope
        // decision as Home's own "New habit" button); left inert rather
        // than inventing a destination for it.
        onGoUnlimited: () {},
        onMaybeLater: popToHome,
      ));
      return true;

    case CompletionRejectedAttemptsExhausted():
      final counts = await completionRepo.liveCompletionCountsByTask();
      if (!context.mounted) return true;
      go(VerifyFailedScreen(
        taskTitle: taskTitle,
        atMillis: clock.nowEpochMillis(),
        // Null: reached directly from Home's precheck, before any photo was
        // ever captured this time (the exhausting attempt, if any, happened
        // earlier - see ProofPhotoPebble's placeholder fallback).
        imageBytes: imageBytes,
        cairnNumber: cairnNumber,
        stoneCount: counts[taskId] ?? 0,
        attemptsRemaining: 0,
        onCancel: popToHome,
      ));
      return true;

    case CompletionRejectedBackfill():
    case CompletionRejectedNotScheduled():
    case CompletionRejectedTaskNotFound():
    case CompletionRejectedAlreadyCompleted():
      return false;
  }
}

/// Parses a completion's stored `verification_meta` JSON (see
/// [CompletionRepository]'s `jsonEncode(verdict.toJson())` call sites) back
/// into a [ProofVerdict] and returns its `reason`. Never throws: a null or
/// malformed value (there is none in practice for a `verified` completion,
/// but this stays defensive) simply falls back to no reason text rather
/// than crashing the outcome screen.
String? _verdictReasonFrom(String? verificationMetaJson) {
  if (verificationMetaJson == null) return null;
  try {
    final map = jsonDecode(verificationMetaJson) as Map<String, dynamic>;
    return ProofVerdict.fromJson(map).reason;
  } catch (_) {
    return null;
  }
}
