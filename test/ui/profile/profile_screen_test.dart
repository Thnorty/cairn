import 'dart:typed_data';

import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/proof_verdict.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/ui/premium/premium_screen.dart';
import 'package:cairn/src/ui/profile/profile_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../../helpers.dart';

/// Wraps [testWidgets] with the same drift-stream-teardown fix-up
/// `home_screen_test.dart` and `app_shell_test.dart` use: cancelling
/// [profileSnapshotProvider]'s `.watch()` subscription when the widget tree
/// is torn down schedules a zero-duration `Timer`, which `flutter_test`'s
/// own invariant check would otherwise flag as still-pending. See those
/// files' identical helper for the full rationale.
void testProfileWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}

/// Directly inserts a completion row with a crafted [points] value, bypassing
/// the streak/perfect-day arithmetic entirely: these tests are about the
/// Profile screen's *display* logic given a real total from
/// `CompletionRepository.totalAltitude()`/`pendingAltitude()` (already
/// covered elsewhere - see points_service_test.dart and
/// pending_altitude_rule_test.dart), not about re-deriving that arithmetic,
/// so a controlled, hand-picked total is more direct than reconstructing a
/// many-day history.
Future<void> seedAltitude(
  AppDatabase db, {
  required String taskId,
  required int points,
  VerificationStatus status = VerificationStatus.verified,
  int slot = 0,
}) async {
  await db.into(db.completions).insert(
        CompletionsCompanion.insert(
          id: const Uuid().v7(),
          taskId: taskId,
          occurrenceDate: d(2026, 7, 10),
          slot: Value(slot),
          completedAt: 0,
          verificationStatus: Value(status),
          pointsAwarded: Value(points),
          updatedAt: 0,
        ),
      );
}

void main() {
  Widget wrap(Widget home) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  Future<AppDatabase> pumpProfile(
    WidgetTester tester, {
    required FixedClock clock,
    required Future<void> Function(AppDatabase db, TaskRepository taskRepo) seed,
  }) async {
    final db = inMemoryDatabase();
    final taskRepo = TaskRepository(db, clock);
    await seed(db, taskRepo);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
        ],
        child: wrap(const ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  group('rank hero', () {
    testProfileWidgets(
        'zero altitude renders Pebble, "0 m gained", no pending line, and '
        'progress to Cairn', (tester) async {
      final db = await pumpProfile(
        tester,
        clock: FixedClock(d(2026, 7, 10)),
        seed: (db, taskRepo) async {},
      );
      addTearDown(db.close);

      expect(find.text('CURRENT RANK'), findsOneWidget);
      expect(find.text('Pebble'), findsWidgets); // hero title + ladder row
      expect(find.text('0 m gained'), findsOneWidget);
      expect(find.textContaining('awaiting verification'), findsNothing);
      expect(find.text('150 m to Cairn'), findsOneWidget);
    });

    testProfileWidgets(
        'a nonzero total renders the correct tier/total and no pending line '
        'when pendingAltitude is 0', (tester) async {
      late String taskId;
      final db = await pumpProfile(
        tester,
        clock: FixedClock(d(2026, 7, 10)),
        seed: (db, taskRepo) async {
          final task = await taskRepo.createTask(
            title: 'Habit',
            recurrenceType: RecurrenceType.daily,
            startDate: d(2026, 7, 1),
          );
          taskId = task.id;
          await seedAltitude(db, taskId: taskId, points: 171); // -> Cairn tier
        },
      );
      addTearDown(db.close);

      expect(find.text('171 m gained'), findsOneWidget);
      expect(find.textContaining('awaiting verification'), findsNothing);
      expect(taskId, isNotEmpty); // sanity: task really was created
    });

    testProfileWidgets(
        'the withheld-metres line appears only while '
        'pendingAltitude() > 0', (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = inMemoryDatabase();
      addTearDown(db.close);

      final taskRepo = TaskRepository(db, clock);
      final offlineVerifier =
          FakeProofVerifier((_) => const VerifierUnavailable('offline'));
      final completionRepo = CompletionRepository(db, clock, verifier: offlineVerifier);

      final task = await taskRepo.createTask(
        title: 'Meditate 10 min',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await completionRepo.completeWithProof(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        proof: ProofData(imageBytes: Uint8List.fromList([1, 2, 3])),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            clockProvider.overrideWithValue(clock),
          ],
          child: wrap(const ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // First-ever completion, sole occurrence today: base 10 + streak 1 +
      // perfect-day 15 = 26, but withheld until verified (same arithmetic
      // home_screen_test.dart's identical scenario hand-computes).
      expect(find.text('+26 m awaiting verification'), findsOneWidget);
      expect(find.text('0 m gained'), findsOneWidget); // not counted yet
    });
  });

  group('rank ladder', () {
    testProfileWidgets(
        'marks the correct tier "You\'re here" and shows "N m to next" for '
        'the immediate-next tier only', (tester) async {
      final db = await pumpProfile(
        tester,
        clock: FixedClock(d(2026, 7, 10)),
        seed: (db, taskRepo) async {
          final task = await taskRepo.createTask(
            title: 'Habit',
            recurrenceType: RecurrenceType.daily,
            startDate: d(2026, 7, 1),
          );
          await seedAltitude(db, taskId: task.id, points: 171); // Cairn tier
        },
      );
      addTearDown(db.close);

      expect(find.text("You're here"), findsOneWidget);
      // Ridge (the immediate-next tier) shows its own absolute threshold
      // plus " · next", matching the design's own "1,100 m · next" example -
      // not a delta from the current total.
      expect(find.text('450 m · next'), findsOneWidget);
      // Pebble (already passed) shows its plain threshold, no "next" suffix.
      expect(find.text('0 m'), findsOneWidget);
      // Tiers beyond the immediate next show their plain threshold too.
      expect(find.text('2,400 m'), findsOneWidget); // Bluff
      expect(find.text('5,000 m'), findsOneWidget); // Peak
      expect(find.text('8,849 m'), findsOneWidget); // Summit
      // The rank hero's own progress row uses a *delta* to the next tier
      // (450 - 171 = 279), distinct from the ladder row's absolute
      // threshold above - both are exercised here.
      expect(find.text('279 m to Ridge'), findsOneWidget);
    });

    testProfileWidgets('at Summit there is no "m to next"', (tester) async {
      final db = await pumpProfile(
        tester,
        clock: FixedClock(d(2026, 7, 10)),
        seed: (db, taskRepo) async {
          final task = await taskRepo.createTask(
            title: 'Habit',
            recurrenceType: RecurrenceType.daily,
            startDate: d(2026, 7, 1),
          );
          await seedAltitude(db, taskId: task.id, points: 9000); // > Summit
        },
      );
      addTearDown(db.close);

      expect(find.text('9,000 m gained'), findsOneWidget);
      expect(find.textContaining('m to '), findsNothing);
      expect(find.textContaining(' · next'), findsNothing);
      // The ladder still marks Summit as "You're here".
      expect(find.text("You're here"), findsOneWidget);
    });
  });

  group('account status, premium, and settings rows', () {
    testProfileWidgets(
        'renders the anonymous-account row and tapping Create shows a '
        'coming-soon snackbar rather than navigating anywhere', (tester) async {
      final db = await pumpProfile(
        tester,
        clock: FixedClock(d(2026, 7, 10)),
        seed: (db, taskRepo) async {},
      );
      addTearDown(db.close);

      expect(find.text('Climbing anonymously'), findsOneWidget);
      expect(find.text('Create an account so your trail is never lost.'), findsOneWidget);

      // The account-status row sits below the fold in the default test
      // viewport (Profile's body is a real scrollable, unlike Home's mostly
      // fixed layout), so this must scroll it into view first - otherwise
      // the tap's derived offset falls outside the render tree entirely and
      // silently misses.
      await tester.ensureVisible(find.text('Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Coming soon'), findsOneWidget);
      // Still on the same screen - no navigation happened.
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Climbing anonymously'), findsOneWidget);
    });

    testProfileWidgets(
        'renders the Cairn Premium row and tapping it navigates to the '
        'Premium screen', (tester) async {
      final db = await pumpProfile(
        tester,
        clock: FixedClock(d(2026, 7, 10)),
        seed: (db, taskRepo) async {},
      );
      addTearDown(db.close);

      expect(find.text('Cairn Premium'), findsOneWidget);
      expect(find.text('Unlimited proofs, backup, deeper insights.'), findsOneWidget);

      await tester.ensureVisible(find.text('Cairn Premium'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cairn Premium'));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumScreen), findsOneWidget);
    });

    testProfileWidgets(
        'renders the settings rows and tapping each is a safe no-op (no '
        'snackbar, no navigation)', (tester) async {
      final db = await pumpProfile(
        tester,
        clock: FixedClock(d(2026, 7, 10)),
        seed: (db, taskRepo) async {},
      );
      addTearDown(db.close);

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Restore purchase'), findsOneWidget);

      await tester.ensureVisible(find.text('Notifications'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Coming soon'), findsNothing);

      await tester.ensureVisible(find.text('Privacy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Privacy'));
      await tester.pumpAndSettle();
      expect(find.text('Coming soon'), findsNothing);

      await tester.ensureVisible(find.text('Restore purchase'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore purchase'));
      await tester.pumpAndSettle();
      expect(find.text('Coming soon'), findsNothing);
    });
  });

  group('reactivity', () {
    testProfileWidgets(
        'reflects an updated total after a completion is added underneath it',
        (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      late TaskRepository taskRepo;
      late CompletionRepository completionRepo;
      late Task task;

      final db = await pumpProfile(
        tester,
        clock: clock,
        seed: (db, repo) async {
          taskRepo = repo;
          completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());
          task = await taskRepo.createTask(
            title: 'Push-ups',
            recurrenceType: RecurrenceType.daily,
            startDate: d(2026, 7, 1),
          );
        },
      );
      addTearDown(db.close);

      expect(find.text('0 m gained'), findsOneWidget);

      // Simulate a completion recorded elsewhere (e.g. from the Home tab),
      // not via any tap on this screen.
      await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 m gained'), findsNothing);
      expect(find.textContaining('m gained'), findsOneWidget);
    });
  });
}
