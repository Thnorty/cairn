import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/l10n/date_number_formatting.dart';
import 'package:cairn/src/models/local_date.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/insights_service.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/ui/premium/premium_screen.dart';
import 'package:cairn/src/ui/stats/stats_screen.dart';
import 'package:cairn/src/ui/theme/app_colors.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

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

  /// Same as [pumpStats], but with [debugPremiumOverrideProvider] forced
  /// true - the entitled-state equivalent, used throughout the "Deeper
  /// insights" group below. Same override style as the existing "when
  /// dailyCap is null (premium)" test above.
  Future<AppDatabase> pumpPremiumStats(
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
          debugPremiumOverrideProvider.overrideWith((ref) => true),
        ],
        child: wrap(const StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  /// Inserts a completion row directly, bypassing `CompletionRepository` so
  /// `completedAt`/`pointsAwarded`/`occurrenceDate` can all be hand-picked
  /// rather than re-derived through the streak/points/no-back-fill rules -
  /// same rationale `profile_screen_test.dart`'s own `seedAltitude` helper
  /// and `insights_service_test.dart`'s own `seedCompletion` helper document.
  Future<void> seedCompletionAt(
    AppDatabase db, {
    required String taskId,
    required LocalDate occurrenceDate,
    required int completedAt,
    int points = 10,
    int slot = 0,
  }) async {
    await db.into(db.completions).insert(
          CompletionsCompanion.insert(
            id: const Uuid().v7(),
            taskId: taskId,
            occurrenceDate: occurrenceDate,
            slot: Value(slot),
            completedAt: completedAt,
            verificationStatus: const Value(VerificationStatus.verified),
            pointsAwarded: Value(points),
            updatedAt: completedAt,
          ),
        );
  }

  /// Epoch millis for [date] at [hour]:00 in the machine's own local
  /// timezone - the same local->millis->local round trip
  /// `insights_service_test.dart`'s own `localMillisAt` uses, so
  /// `BestTimeOfDay`'s bucketing is deterministic regardless of which
  /// timezone the test runner happens to be in.
  int localMillisAt(LocalDate date, int hour) =>
      DateTime(date.year, date.month, date.day, hour).millisecondsSinceEpoch;

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

    testStatsWidgets(
        'when dailyCap is null (premium), the proofs used today card is omitted',
        (tester) async {
      final clock = FixedClock(d(2026, 7, 20));
      final db = inMemoryDatabase();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            clockProvider.overrideWithValue(clock),
            debugPremiumOverrideProvider.overrideWith((ref) => true),
          ],
          child: wrap(const StatsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      addTearDown(db.close);

      expect(find.text('PROOFS USED TODAY'), findsNothing);
      expect(find.byKey(const ValueKey('proof-segment-0')), findsNothing);
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

  group('Deeper insights', () {
    testStatsWidgets(
        'the locked upsell card shows when not entitled, and the unlocked '
        'section does not render', (tester) async {
      final db = await pumpStats(tester, FixedClock(d(2026, 7, 20)), (db) async {});
      addTearDown(db.close);

      expect(find.text('Deeper insights'), findsOneWidget);
      expect(find.text('DEEPER INSIGHTS'), findsNothing);
      expect(find.text('Consistency'), findsNothing);
      expect(find.text('Best time of day'), findsNothing);
      expect(find.text('Rank projection'), findsNothing);
    });

    testStatsWidgets(
        'the unlocked section (label, PREMIUM pill, all three cards) shows '
        'when entitled, and the locked card does not render; with no '
        'history yet, Consistency and Best time of day both fall back to '
        'the empty-state line and Rank projection falls back to its '
        "'not enough pace' line", (tester) async {
      final db = await pumpPremiumStats(tester, FixedClock(d(2026, 7, 20)), (db) async {});
      addTearDown(db.close);

      expect(find.text('DEEPER INSIGHTS'), findsOneWidget);
      expect(find.text('PREMIUM'), findsOneWidget);
      expect(find.text('Deeper insights'), findsNothing); // locked card gone
      expect(
        find.text('Consistency curves, best times of day, rank projections.'),
        findsNothing,
      );

      expect(find.text('Consistency'), findsOneWidget);
      expect(find.text('Best time of day'), findsOneWidget);
      expect(find.text('Rank projection'), findsOneWidget);

      // Consistency (no week in the window had anything scheduled) and Best
      // time of day (zero completions ever) share the exact same empty-state
      // copy, so both cards falling back shows up as two instances of it.
      expect(find.text('Not enough history yet.'), findsNWidgets(2));
      // Below the top rank (0 m) with no pace at all: the "not enough pace"
      // message, not the "already at the top" one.
      expect(
        find.text("Complete a few more stones and we'll project your next rank."),
        findsOneWidget,
      );
      expect(
        find.text("You've reached the top rank. Nothing left to project."),
        findsNothing,
      );
    });

    testStatsWidgets('Consistency card renders populated data', (tester) async {
      final today = d(2026, 7, 23); // a Thursday
      final currentWeekStart = today.addDays(-(today.weekday - 1));
      final oldestWeekStart = currentWeekStart
          .addDays(-7 * (InsightsService.consistencyWindowWeeks - 1));

      final db = await pumpPremiumStats(tester, FixedClock(today), (db) async {
        final taskRepo = TaskRepository(db, FixedClock(oldestWeekStart));
        final task = await taskRepo.createTask(
          title: 'Daily habit',
          recurrenceType: RecurrenceType.daily,
          startDate: oldestWeekStart.addDays(-30),
        );
        // Every elapsed day, up to and including yesterday, completed with
        // no skips: every week (past and the current week's elapsed part
        // alike) lands at exactly 100%.
        var date = oldestWeekStart;
        final loopEnd = today.addDays(-1);
        while (!date.isAfter(loopEnd)) {
          await CompletionRepository(db, FixedClock(date), verifier: FakeProofVerifier())
              .completeOccurrence(taskId: task.id, occurrenceDate: date);
          date = date.addDays(1);
        }
      });
      addTearDown(db.close);

      expect(find.text('Consistency'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(
        find.text('last ${InsightsService.consistencyWindowWeeks} weeks'),
        findsOneWidget,
      );
      expect(
        find.text('${InsightsService.consistencyWindowWeeks} weeks ago'),
        findsOneWidget,
      );
    });

    testStatsWidgets('Best time of day card renders populated data', (tester) async {
      final clock = FixedClock(d(2026, 7, 20));
      late String taskId;
      final db = await pumpPremiumStats(tester, clock, (db) async {
        final taskRepo = TaskRepository(db, clock);
        final task = await taskRepo.createTask(
          title: 'Habit',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );
        taskId = task.id;
        // 3 stones in the [8,12) bucket (the peak), 1 in [0,4) - each on a
        // distinct date so the (task, date, slot) unique index is satisfied.
        for (final entry in [(10, 9), (11, 10), (12, 11)]) {
          await seedCompletionAt(
            db,
            taskId: task.id,
            occurrenceDate: d(2026, 7, entry.$1),
            completedAt: localMillisAt(d(2026, 7, entry.$1), entry.$2),
          );
        }
        await seedCompletionAt(
          db,
          taskId: task.id,
          occurrenceDate: d(2026, 7, 13),
          completedAt: localMillisAt(d(2026, 7, 13), 2),
        );
      });
      addTearDown(db.close);

      expect(find.text('Best time of day'), findsOneWidget);
      expect(find.text('8a to 12p'), findsOneWidget);
      expect(find.text('3 of your 4 stones landed in this window.'), findsOneWidget);

      final peakBar =
          tester.widget<DecoratedBox>(find.byKey(const ValueKey('best-time-bar-fill')).at(2))
              .decoration as BoxDecoration;
      expect(peakBar.gradient, isNotNull);
      final quietBar =
          tester.widget<DecoratedBox>(find.byKey(const ValueKey('best-time-bar-fill')).at(0))
              .decoration as BoxDecoration;
      expect(quietBar.gradient, isNull);
      expect(quietBar.color, AppColors.statsMutedFillBg);

      expect(taskId, isNotEmpty); // sanity: task really was created
    });

    testStatsWidgets(
        'Best time of day falls back to its empty-state line when there are '
        'no completions yet, even though Consistency itself has data',
        (tester) async {
      final clock = FixedClock(d(2026, 7, 20));
      final db = await pumpPremiumStats(tester, clock, (db) async {
        final taskRepo = TaskRepository(db, clock);
        // Scheduled in the past but never completed: Consistency reads a
        // defined (non-null) 0%, while Best time of day - which counts
        // completions, not scheduled occurrences - has nothing at all.
        await taskRepo.createTask(
          title: 'Never done',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 6, 1),
        );
      });
      addTearDown(db.close);

      expect(find.text('Consistency'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);

      expect(find.text('Best time of day'), findsOneWidget);
      expect(find.text('Not enough history yet.'), findsOneWidget);
      expect(find.byKey(const ValueKey('best-time-bar-fill')), findsNothing);
    });

    testStatsWidgets('Rank projection card renders populated data', (tester) async {
      final today = d(2026, 8, 15);
      final clock = FixedClock(today);
      const locale = Locale('en');

      final db = await pumpPremiumStats(tester, clock, (db) async {
        final taskRepo = TaskRepository(db, clock);
        final taskA = await taskRepo.createTask(
          title: 'Outside window',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 1, 1),
        );
        final taskB = await taskRepo.createTask(
          title: 'Inside window',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 1, 1),
        );
        // 40 days ago: counts toward total altitude but not toward pace.
        final outsideWindow = today.addDays(-40);
        await seedCompletionAt(
          db,
          taskId: taskA.id,
          occurrenceDate: outsideWindow,
          completedAt: outsideWindow.toUtcMidnight().millisecondsSinceEpoch,
          points: 72,
        );
        // Today: inside the trailing 28-day pace window.
        await seedCompletionAt(
          db,
          taskId: taskB.id,
          occurrenceDate: today,
          completedAt: today.toUtcMidnight().millisecondsSinceEpoch,
          points: 28,
        );
      });
      addTearDown(db.close);

      // Total altitude 100 m (Pebble tier, next Cairn @ 150 m); pace 28 m /
      // 28 days = 1.0 m/day = 7.0 m/week; 50 m remaining, ceil(50/1.0) = 50
      // days out; weeksOut = round(50 / 7.0) = 7.
      final projectedDate = today.addDays(50);

      expect(find.text('Rank projection'), findsOneWidget);
      expect(
        find.text('Cairn by ${formatShortMonthDay(projectedDate, locale)}'),
        findsOneWidget,
      );
      expect(find.text('At +7 m a week, about 7 weeks out.'), findsOneWidget);
      expect(find.text('100 m'), findsOneWidget);
      expect(find.text('50 m to go'), findsOneWidget);
    });

    testStatsWidgets(
        'Rank projection falls back to the top-rank line once Summit is '
        'reached', (tester) async {
      final clock = FixedClock(d(2026, 7, 20));
      final db = await pumpPremiumStats(tester, clock, (db) async {
        final taskRepo = TaskRepository(db, clock);
        final task = await taskRepo.createTask(
          title: 'Habit',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );
        // 9000 m: comfortably past the Summit threshold (8,849 m).
        await seedCompletionAt(
          db,
          taskId: task.id,
          occurrenceDate: d(2026, 7, 20),
          completedAt: clock.nowEpochMillis(),
          points: 9000,
        );
      });
      addTearDown(db.close);

      expect(find.text('Rank projection'), findsOneWidget);
      expect(
        find.text("You've reached the top rank. Nothing left to project."),
        findsOneWidget,
      );
      expect(
        find.text("Complete a few more stones and we'll project your next rank."),
        findsNothing,
      );
    });
  });
}
