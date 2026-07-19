import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/ui/premium/premium_screen.dart';
import 'package:cairn/src/ui/stats/stats_screen.dart';
import 'package:cairn/src/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// Wraps [testWidgets] with the same drift-stream-teardown fix-up
/// `home_screen_test.dart`/`profile_screen_test.dart`/`trail_screen_test.dart`
/// use: cancelling [statsSnapshotProvider]'s `.watch()` subscription when the
/// widget tree is torn down schedules a zero-duration `Timer`, which
/// `flutter_test`'s own invariant check would otherwise flag as still
/// pending. See those files' identical helper for the full rationale.
void testStatsWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}

void main() {
  Widget wrap(Widget home) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  Future<AppDatabase> pumpStats(
    WidgetTester tester,
    FixedClock clock,
    Future<void> Function(AppDatabase db) seed,
  ) async {
    final db = inMemoryDatabase();
    await seed(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
        ],
        child: wrap(const StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  BoxDecoration decorationOf(WidgetTester tester, Key key) {
    return tester.widget<Container>(find.byKey(key)).decoration as BoxDecoration;
  }

  group('header', () {
    testStatsWidgets('shows the YOUR GROUND eyebrow and the Stats title',
        (tester) async {
      final db = await pumpStats(tester, FixedClock(d(2026, 7, 20)), (db) async {});
      addTearDown(db.close);

      expect(find.text('YOUR GROUND'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
    });
  });

  group('top stat tiles', () {
    testStatsWidgets(
        'Stones placed and Cairns built show the right numbers', (tester) async {
      final clock = FixedClock(d(2026, 7, 20));
      late String taskId;
      final db = await pumpStats(tester, clock, (db) async {
        final taskRepo = TaskRepository(db, clock);
        final task = await taskRepo.createTask(
          title: 'Read 20 pages',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );
        taskId = task.id;
        // 10 consecutive days: 10 stones placed, 1 capped cairn.
        for (var day = 1; day <= 10; day++) {
          await CompletionRepository(db, FixedClock(d(2026, 7, day)),
                  verifier: FakeProofVerifier())
              .completeOccurrence(taskId: task.id, occurrenceDate: d(2026, 7, day));
        }
      });
      addTearDown(db.close);

      expect(find.text('10'), findsOneWidget); // stones placed
      expect(find.text('1'), findsOneWidget); // cairns built
      expect(find.text('Stones placed'), findsOneWidget);
      expect(find.text('Cairns built'), findsOneWidget);
      expect(taskId, isNotEmpty); // sanity: task really was created
    });
  });

  group('proofs used today', () {
    testStatsWidgets(
        'the segment bar fills exactly proofsUsedToday segments sage and '
        'leaves the rest muted', (tester) async {
      final clock = FixedClock(d(2026, 7, 20));
      final db = await pumpStats(tester, clock, (db) async {
        final taskRepo = TaskRepository(db, clock);
        final task = await taskRepo.createTask(
          title: 'A',
          recurrenceType: RecurrenceType.daily,
          dueTimes: const ['08:00', '20:00'],
          startDate: d(2026, 7, 1),
        );
        await CompletionRepository(db, clock, verifier: FakeProofVerifier())
            .completeOccurrence(taskId: task.id, occurrenceDate: d(2026, 7, 20), slot: 0);
      });
      addTearDown(db.close);

      expect(find.text('1 of 5'), findsOneWidget);

      final segment0 = decorationOf(tester, const ValueKey('proof-segment-0'));
      expect(segment0.color, AppColors.sage);
      for (var i = 1; i < 5; i++) {
        final segment = decorationOf(tester, ValueKey('proof-segment-$i'));
        expect(segment.color, AppColors.statsMutedFillBg, reason: 'segment $i');
      }
    });
  });

  group('weekly chart', () {
    testStatsWidgets(
        'renders 7 bars with relative fills and a faint fill for a future '
        'day', (tester) async {
      final today = d(2026, 7, 20);
      final weekStart = today.addDays(-(today.weekday - 1));
      // `today` sits mid-week (3 days after weekStart) so both past/today
      // days and future days are exercised in the same run.
      final clock = FixedClock(weekStart.addDays(3));

      final db = await pumpStats(tester, clock, (db) async {
        final taskRepo = TaskRepository(db, FixedClock(weekStart));
        final task = await taskRepo.createTask(
          title: 'Daily habit',
          recurrenceType: RecurrenceType.daily,
          startDate: weekStart,
        );
        // Completed on day offsets 0 and 3 (today); offsets 1,2,4,5,6 stay
        // undone (2 is a past miss, 4-6 are still in the future).
        for (final offset in [0, 3]) {
          final date = weekStart.addDays(offset);
          await CompletionRepository(db, FixedClock(date), verifier: FakeProofVerifier())
              .completeOccurrence(taskId: task.id, occurrenceDate: date);
        }
      });
      addTearDown(db.close);

      Finder fillFinder(int i) => find.descendant(
            of: find.byKey(ValueKey('week-bar-$i')),
            matching: find.byKey(const ValueKey('week-bar-fill')),
          );

      // 7 bars total.
      for (var i = 0; i < 7; i++) {
        expect(fillFinder(i), findsOneWidget, reason: 'bar $i');
      }

      // Day 0 (done): sage gradient fill, not the faint future colour.
      final day0 = tester.widget<DecoratedBox>(fillFinder(0)).decoration as BoxDecoration;
      expect(day0.gradient, isNotNull);
      expect(day0.color, isNull);

      // Day 2 (past, missed): no gradient/colour distinguishing it from
      // "done" by fill alone, but it must not use the future's faint fill.
      final day2 = tester.widget<DecoratedBox>(fillFinder(2)).decoration as BoxDecoration;
      expect(day2.color, isNull);

      // Days 4-6 (future): the faint muted colour, no sage gradient.
      for (var i = 4; i < 7; i++) {
        final future =
            tester.widget<DecoratedBox>(fillFinder(i)).decoration as BoxDecoration;
        expect(future.gradient, isNull, reason: 'bar $i');
        expect(future.color, AppColors.statsFutureBarBg, reason: 'bar $i');
      }
    });
  });

  group('current streaks', () {
    testStatsWidgets('the empty-streaks state shows a calm message', (tester) async {
      final db = await pumpStats(tester, FixedClock(d(2026, 7, 20)), (db) async {});
      addTearDown(db.close);

      expect(find.text('CURRENT STREAKS'), findsOneWidget);
      expect(find.text('No active streaks yet'), findsOneWidget);
    });

    testStatsWidgets(
        'renders one row per active task with a live streak, in cairn '
        '(creation) order', (tester) async {
      final clock = FixedClock(d(2026, 7, 20));
      final db = await pumpStats(tester, clock, (db) async {
        final taskRepo = TaskRepository(db, clock);
        final taskA = await taskRepo.createTask(
          title: 'Read 20 pages',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );
        final laterTaskRepo = TaskRepository(
          db,
          FixedClock(d(2026, 7, 20), nowMillis: clock.nowEpochMillis() + 1000),
        );
        final taskB = await laterTaskRepo.createTask(
          title: 'Morning workout',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );
        // No streak for a third task ("No streak habit"): excluded below.
        await laterTaskRepo.createTask(
          title: 'No streak habit',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );

        for (var day = 18; day <= 20; day++) {
          await CompletionRepository(db, FixedClock(d(2026, 7, day)),
                  verifier: FakeProofVerifier())
              .completeOccurrence(taskId: taskA.id, occurrenceDate: d(2026, 7, day));
        }
        await CompletionRepository(db, clock, verifier: FakeProofVerifier())
            .completeOccurrence(taskId: taskB.id, occurrenceDate: d(2026, 7, 20));
      });
      addTearDown(db.close);

      expect(find.text('No active streaks yet'), findsNothing);
      expect(find.text('Read 20 pages'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
      expect(find.text('Morning workout'), findsOneWidget);
      expect(find.text('1 day'), findsOneWidget);
      expect(find.text('No streak habit'), findsNothing);

      // Row order matches creation order (A before B): A's title sits above
      // B's in the render tree.
      final aY = tester.getTopLeft(find.text('Read 20 pages')).dy;
      final bY = tester.getTopLeft(find.text('Morning workout')).dy;
      expect(aY, lessThan(bY));
    });
  });

  group('Premium affordances', () {
    testStatsWidgets('"Go unlimited" navigates to the Premium screen',
        (tester) async {
      final db = await pumpStats(tester, FixedClock(d(2026, 7, 20)), (db) async {});
      addTearDown(db.close);

      await tester.tap(find.text('Go unlimited'));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumScreen), findsOneWidget);
    });

    testStatsWidgets(
        'the "Deeper insights" card navigates to the Premium screen',
        (tester) async {
      final db = await pumpStats(tester, FixedClock(d(2026, 7, 20)), (db) async {});
      addTearDown(db.close);

      expect(find.text('Deeper insights'), findsOneWidget);
      expect(
        find.text('Consistency curves, best times of day, rank projections.'),
        findsOneWidget,
      );
      expect(find.text('PREMIUM'), findsOneWidget);

      await tester.tap(find.text('Deeper insights'));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumScreen), findsOneWidget);
    });
  });
}
