import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/local_date.dart';
import '../../providers.dart';
import '../../repo/completion_repository.dart';
import '../widgets/message_snack_bar.dart';
import 'camera_capture_screen.dart';
import 'proof_outcome_routing.dart';

/// The single way into the proof flow for one occurrence, shared by Home's
/// "Prove it" button and a notification tap
/// (`lib/src/ui/shell/notification_tap_listener.dart`).
///
/// Always runs [CompletionRepository.precheckProof] *first*, so a doomed
/// attempt (daily cap, attempts exhausted, or any other guard-chain
/// rejection) never opens the camera - see `proof_outcome_routing.dart`'s doc
/// comment. Only a clear precheck (`null`) opens [CameraCaptureScreen];
/// everything from there on (capture, verify, and routing to the outcome
/// screens) happens on that screen.
///
/// Extracted from what used to be `HomeScreen._handleProveIt`'s body when
/// notifications gained a tap-to-camera route: two entry points running
/// slightly different versions of the guard chain is exactly the drift that
/// lets one of them bypass a cap, so both go through this.
///
/// Callers are responsible for their own re-entrancy guard (Home keeps a set
/// of in-flight occurrence keys so a double-tap can't open the picker twice).
Future<void> startProofFlow(
  BuildContext context,
  WidgetRef ref, {
  required String taskId,
  required String taskTitle,
  required LocalDate occurrenceDate,
  required int slot,
}) async {
  final rejection = await ref.read(completionRepositoryProvider).precheckProof(
        taskId: taskId,
        occurrenceDate: occurrenceDate,
        slot: slot,
      );
  if (!context.mounted) return;

  if (rejection == null) {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CameraCaptureScreen(
        taskId: taskId,
        taskTitle: taskTitle,
        occurrenceDate: occurrenceDate,
        slot: slot,
      ),
    ));
    return;
  }

  // Daily-cap/attempts-exhausted precheck rejections route to the exact same
  // outcome screens a post-submit rejection would (shared with
  // CameraCaptureScreen via routeToProofOutcome, so both paths agree); the
  // remaining rejection types have no dedicated screen by design (they're
  // not reachable from a correctly-behaving UI) and fall back to a minimal
  // snackbar below.
  final handled = await routeToProofOutcome(
    context,
    ref,
    result: rejection,
    taskId: taskId,
    taskTitle: taskTitle,
    occurrenceDate: occurrenceDate,
    slot: slot,
  );
  if (!handled && context.mounted) {
    _showUnreachableRejection(context, rejection);
  }
}

/// Minimal fallback for the handful of rejections [routeToProofOutcome]
/// deliberately builds no screen for (back-fill, not-scheduled,
/// task-not-found, already-completed): none of these are reachable from a
/// correctly-behaving UI (precheckProof already blocked the tap that could
/// cause them), so this stays a plain, untranslated safety net rather than
/// polished product copy - the same scope decision the Phase 1 debug screen
/// already makes for these exact rejection types.
void _showUnreachableRejection(
  BuildContext context,
  CompleteOccurrenceResult result,
) {
  final message = switch (result) {
    CompletionRejectedBackfill() => 'Cannot complete a past date',
    CompletionRejectedNotScheduled() => 'Not scheduled for this slot today',
    CompletionRejectedTaskNotFound() => 'Task not found',
    CompletionRejectedAlreadyCompleted() => 'Already completed',
    _ => 'Something went wrong',
  };
  context.showMessageSnackBar(message);
}
