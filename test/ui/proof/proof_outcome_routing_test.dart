import 'dart:typed_data';

import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/proof_verdict.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/ui/proof/cairn_complete_screen.dart';
import 'package:cairn/src/ui/proof/camera_capture_screen.dart';
import 'package:cairn/src/ui/proof/daily_limit_screen.dart';
import 'package:cairn/src/ui/proof/proof_outcome_routing.dart';
import 'package:cairn/src/ui/proof/verify_failed_screen.dart';
import 'package:cairn/src/ui/proof/verify_pending_screen.dart';
import 'package:cairn/src/ui/proof/verify_result_screen.dart';
import 'package:cairn/src/ui/proof/verify_too_old_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';
import '../../support/fake_proof_pipeline.dart';

/// Exercises [routeToProofOutcome] directly - the single routing function
/// shared by Home's "Prove it" precheck short-circuit and
/// [CameraCaptureScreen]'s post-submit routing - against every
/// [CompleteOccurrenceResult] variant it handles. A trigger button in a
/// minimal harness app calls it with a result built by each test (either a
/// real repository call, so the test also proves the underlying data is
/// right, or a hand-built result for the cases that need one).
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late TaskRepository taskRepo;
  late CompletionRepository completionRepo;

  setUp(() {
    db = inMemoryDatabase();
    clock = FixedClock(d(2026, 7, 10));
    taskRepo = TaskRepository(db, clock);
    completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());
  });

  tearDown(() async {
    await db.close();
  });

  Future<Task> makeTask() => taskRepo.createTask(
        title: 'Read 20 pages',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

  Future<void> pumpHarness(
    WidgetTester tester,
    CompleteOccurrenceResult Function() resultBuilder, {
    required String taskId,
    Uint8List? imageBytes,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => ElevatedButton(
              onPressed: () => routeToProofOutcome(
                context,
                ref,
                result: resultBuilder(),
                taskId: taskId,
                taskTitle: 'Read 20 pages',
                occurrenceDate: d(2026, 7, 10),
                slot: 0,
                imageBytes: imageBytes,
              ),
              child: const Text('trigger'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('CompletionRecorded routes to VerifyResultScreen', (tester) async {
    final task = await makeTask();
    final result = await completionRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: ProofData(imageBytes: Uint8List.fromList([1, 2, 3])),
    );
    expect(result, isA<CompletionRecorded>());

    await pumpHarness(
      tester,
      () => result,
      taskId: task.id,
      imageBytes: kFakeImageBytes,
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyResultScreen), findsOneWidget);
    expect(find.byType(CameraCaptureScreen), findsNothing);
  });

  testWidgets(
      'a completion that caps the cairn (its 10th live stone) shows "Cairn '
      'N · 10 stones · new stone placed", the current cairn re-read AFTER '
      'the stone was recorded', (tester) async {
    final task = await makeTask();
    // 9 prior verified stones, then a 10th via completeWithProof (a pass):
    // the same stone-caps-the-cairn scenario CLAUDE.md's per-task-cairns
    // rule and completion_repository_test.dart's "cairn cap bonus" group
    // both cover, exercised here through the routing this run unifies.
    for (var day = 1; day <= 9; day++) {
      final repo = CompletionRepository(db, FixedClock(d(2026, 7, day)),
          verifier: FakeProofVerifier());
      await repo.completeOccurrence(
          taskId: task.id, occurrenceDate: d(2026, 7, day));
    }
    final tenthRepo =
        CompletionRepository(db, clock, verifier: FakeProofVerifier());
    final result = await tenthRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: ProofData(imageBytes: Uint8List.fromList([1, 2, 3])),
    );
    expect(result, isA<CompletionRecorded>());

    await pumpHarness(
      tester,
      () => result,
      taskId: task.id,
      imageBytes: kFakeImageBytes,
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyResultScreen), findsOneWidget);
    expect(find.text('Cairn 1 · 10 stones · new stone placed'), findsOneWidget);
  });

  testWidgets(
      'a completion that caps the cairn: tapping VerifyResultScreen\'s Done '
      'pushes CairnCompleteScreen (not straight back to Home), and that '
      "screen's own Done pops the whole outcome stack back to Home in one "
      'go', (tester) async {
    final task = await makeTask();
    for (var day = 1; day <= 9; day++) {
      final repo = CompletionRepository(db, FixedClock(d(2026, 7, day)),
          verifier: FakeProofVerifier());
      await repo.completeOccurrence(
          taskId: task.id, occurrenceDate: d(2026, 7, day));
    }
    final tenthRepo =
        CompletionRepository(db, clock, verifier: FakeProofVerifier());
    final result = await tenthRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: ProofData(imageBytes: Uint8List.fromList([1, 2, 3])),
    );
    expect(result, isA<CompletionRecorded>());

    await pumpHarness(
      tester,
      () => result,
      taskId: task.id,
      imageBytes: kFakeImageBytes,
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    expect(find.byType(VerifyResultScreen), findsOneWidget);
    expect(find.byType(CairnCompleteScreen), findsNothing);

    // VerifyResultScreen's own Done, tapped while it's the only screen with
    // a "Done" button on screen.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(CairnCompleteScreen), findsOneWidget);
    expect(find.text('Cairn 1 complete'), findsOneWidget);

    // Scoped to CairnCompleteScreen: VerifyResultScreen may still be
    // mounted (just covered) underneath it in the Navigator stack, so an
    // unscoped find.text('Done') here would be ambiguous.
    await tester.tap(find.descendant(
      of: find.byType(CairnCompleteScreen),
      matching: find.text('Done'),
    ));
    await tester.pumpAndSettle();

    // Back to Home (the harness's own trigger screen) in one go: neither
    // outcome screen remains in the stack.
    expect(find.text('trigger'), findsOneWidget);
    expect(find.byType(CairnCompleteScreen), findsNothing);
    expect(find.byType(VerifyResultScreen), findsNothing);
  });

  testWidgets(
      'a non-capping CompletionRecorded: tapping Done pops straight to Home '
      'and CairnCompleteScreen is never shown', (tester) async {
    final task = await makeTask();
    final result = await completionRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: ProofData(imageBytes: Uint8List.fromList([1, 2, 3])),
    );
    expect(result, isA<CompletionRecorded>());

    await pumpHarness(
      tester,
      () => result,
      taskId: task.id,
      imageBytes: kFakeImageBytes,
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    expect(find.byType(VerifyResultScreen), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(CairnCompleteScreen), findsNothing);
    expect(find.text('trigger'), findsOneWidget);
  });

  testWidgets(
      'a rejected verdict with attempts remaining routes to Verify Failed, '
      "showing the verifier's own reason", (tester) async {
    final task = await makeTask();
    const verdict = ProofVerdict(
      taskShown: false,
      confidence: 0.1,
      isScreenshotOrScreen: false,
      reason: 'No book visible in frame.',
    );
    const result = CompletionRejectedByVerifier(verdict, 2);

    await pumpHarness(
      tester,
      () => result,
      taskId: task.id,
      imageBytes: kFakeImageBytes,
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyFailedScreen), findsOneWidget);
    expect(find.text('No book visible in frame.'), findsOneWidget);
    expect(find.text('2 tries left today'), findsOneWidget);
    // No stone was placed on a rejection: the caption reflects the task's
    // unchanged current cairn (a brand-new task, still Cairn 1 with 0
    // stones), not some stale or lifetime-total figure.
    expect(find.text('Cairn 1 · 0 stones · no stone placed'), findsOneWidget);
  });

  testWidgets(
      'a rejected verdict with zero attempts remaining routes to the No '
      'Retries variant, not the verifier reason', (tester) async {
    final task = await makeTask();
    const verdict = ProofVerdict(
      taskShown: false,
      confidence: 0.1,
      isScreenshotOrScreen: true,
      reason: 'Looks like a screenshot.',
    );
    const result = CompletionRejectedByVerifier(verdict, 0);

    await pumpHarness(
      tester,
      () => result,
      taskId: task.id,
      imageBytes: kFakeImageBytes,
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyFailedScreen), findsOneWidget);
    expect(
      find.textContaining("You've used all 3 attempts"),
      findsOneWidget,
    );
    expect(find.text('Looks like a screenshot.'), findsNothing);
  });

  testWidgets('CompletionPendingVerification (VerifierUnavailable) routes to '
      'VerifyPendingScreen', (tester) async {
    final task = await makeTask();
    final offlineRepo = CompletionRepository(
      db,
      clock,
      verifier: FakeProofVerifier((_) => const VerifierUnavailable('offline')),
    );
    final result = await offlineRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: ProofData(imageBytes: Uint8List.fromList([1, 2, 3])),
    );
    expect(result, isA<CompletionPendingVerification>());

    await pumpHarness(
      tester,
      () => result,
      taskId: task.id,
      imageBytes: kFakeImageBytes,
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyPendingScreen), findsOneWidget);
  });

  testWidgets(
      'CompletionRejectedDailyCapReached routes to DailyLimitScreen without '
      'ever opening the camera', (tester) async {
    final task = await makeTask();
    const result = CompletionRejectedDailyCapReached();

    await pumpHarness(tester, () => result, taskId: task.id);
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.byType(DailyLimitScreen), findsOneWidget);
    expect(find.byType(CameraCaptureScreen), findsNothing);
  });

  testWidgets(
      'CompletionRejectedAttemptsExhausted (precheck, no photo yet) routes '
      'to the No Retries screen without ever opening the camera', (tester) async {
    final task = await makeTask();
    const result = CompletionRejectedAttemptsExhausted();

    // No imageBytes: this is the precheck-only path, before any photo was
    // captured this time.
    await pumpHarness(tester, () => result, taskId: task.id);
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(VerifyFailedScreen), findsOneWidget);
    expect(find.byType(CameraCaptureScreen), findsNothing);
    expect(find.text('Try again tomorrow'), findsOneWidget);
  });

  testWidgets(
      'a stale photo routes to VerifyTooOldScreen (not VerifyFailedScreen), '
      'and does NOT burn an attempt (remaining count is unaffected)', (tester) async {
    final task = await makeTask();
    // Burn exactly one *real* verifier rejection first, so the remaining
    // count starts at 3 - 1 = 2.
    final rejectingRepo = CompletionRepository(
      db,
      clock,
      verifier: FakeProofVerifier((_) => const VerdictReceived(ProofVerdict(
            taskShown: false,
            confidence: 0.1,
            isScreenshotOrScreen: false,
            reason: 'no evidence',
          ))),
    );
    final firstRejection = await rejectingRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: ProofData(imageBytes: Uint8List.fromList([1, 2, 3])),
    );
    expect(firstRejection, isA<CompletionRejectedByVerifier>());
    expect(await completionRepo.attemptsUsedToday(task.id), 1);

    const staleResult = CompletionRejectedStalePhoto(1200000); // 20 min old

    await pumpHarness(
      tester,
      () => staleResult,
      taskId: task.id,
      imageBytes: kFakeImageBytes,
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyTooOldScreen), findsOneWidget);
    expect(find.byType(VerifyFailedScreen), findsNothing);
    // 3 - 1 (the one real rejection above) = 2 left; the stale rejection
    // itself must not have burned a second one, proving it never wrote a
    // verification_attempts row.
    expect(
      find.text("This didn't use a try. You still have 2 left today."),
      findsOneWidget,
    );
    final attemptsRows = await db.select(db.verificationAttempts).get();
    expect(attemptsRows, hasLength(1)); // only the earlier real rejection
  });

  testWidgets(
      'the unreachable rejections (back-fill, not-scheduled, task-not-found, '
      'already-completed) return false and open no screen', (tester) async {
    final task = await makeTask();
    for (final result in const [
      CompletionRejectedBackfill(),
      CompletionRejectedNotScheduled(),
      CompletionRejectedTaskNotFound(),
      CompletionRejectedAlreadyCompleted(),
    ]) {
      await pumpHarness(tester, () => result, taskId: task.id);
      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.byType(VerifyResultScreen), findsNothing);
      expect(find.byType(VerifyFailedScreen), findsNothing);
      expect(find.byType(VerifyPendingScreen), findsNothing);
      expect(find.byType(DailyLimitScreen), findsNothing);
      expect(find.byType(CameraCaptureScreen), findsNothing);
    }
  });
}
