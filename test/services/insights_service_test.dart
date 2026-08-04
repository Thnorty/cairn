import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/local_date.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/insights_service.dart';
import 'package:cairn/src/services/occurrence_generator.dart';
import 'package:cairn/src/services/points_service.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = inMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  InsightsService buildService(Clock clock) {
    return InsightsService(
      TaskRepository(db, clock),
      CompletionRepository(db, clock, verifier: FakeProofVerifier()),
      const OccurrenceGenerator(),
      const PointsService(),
      clock,
    );
  }

  /// Inserts a completion row directly, bypassing `CompletionRepository` so
  /// `completedAt`/`pointsAwarded`/`verificationStatus`/tombstone state can
  /// all be hand-picked rather than re-derived through the streak/points
  /// arithmetic (already covered elsewhere - see points_service_test.dart)
  /// - same rationale profile_screen_test.dart's own `seedAltitude` helper
  /// documents.
  Future<void> seedCompletion(
    AppDatabase db, {
    required String taskId,
    required LocalDate occurrenceDate,
    int slot = 0,
    required int completedAt,
    VerificationStatus status = VerificationStatus.verified,
    int points = 10,
    bool tombstoned = false,
  }) async {
    await db.into(db.completions).insert(
          CompletionsCompanion.insert(
            id: const Uuid().v7(),
            taskId: taskId,
            occurrenceDate: occurrenceDate,
            slot: Value(slot),
            completedAt: completedAt,
            verificationStatus: Value(status),
            pointsAwarded: Value(points),
            updatedAt: completedAt,
            deletedAt: tombstoned ? Value(completedAt) : const Value.absent(),
          ),
        );
  }

  /// Epoch millis for [date] at [hour]:00 in the machine's own local
  /// timezone - a local->millis->local round trip (mirroring
  /// `InsightsService.bestTimeOfDay`'s own `DateTime.fromMillisecondsSinceEpoch`
  /// conversion), so the test is deterministic regardless of which
  /// timezone the test runner happens to be in.
  int localMillisAt(LocalDate date, int hour) =>
      DateTime(date.year, date.month, date.day, hour).millisecondsSinceEpoch;

  group('consistency', () {
    test('an empty database returns 8 weeks of zero/null figures and a '
        'null overall rate', () async {
      final service = buildService(FixedClock(d(2026, 7, 20)));

      final snapshot = await service.consistency();

      expect(snapshot.weeks, hasLength(InsightsService.consistencyWindowWeeks));
      for (final week in snapshot.weeks) {
        expect(week.scheduled, 0);
        expect(week.completed, 0);
        expect(week.rate, isNull);
      }
      expect(snapshot.overallRate, isNull);
    });

    test('week boundaries follow the same Monday-start convention as '
        'StatsService, and isPartial is true only for the week containing '
        'today', () async {
      final today = d(2026, 7, 20);
      // Same expression stats_service_test.dart's own week-bar test uses.
      final currentWeekStart = today.addDays(-(today.weekday - 1));
      final oldestWeekStart =
          currentWeekStart.addDays(-7 * (InsightsService.consistencyWindowWeeks - 1));

      final service = buildService(FixedClock(today));
      final snapshot = await service.consistency();

      expect(snapshot.weeks.first.weekStart, oldestWeekStart);
      expect(snapshot.weeks.last.weekStart, currentWeekStart);
      for (var i = 0; i < snapshot.weeks.length; i++) {
        expect(snapshot.weeks[i].weekStart, oldestWeekStart.addDays(7 * i));
        expect(
          snapshot.weeks[i].isPartial,
          i == snapshot.weeks.length - 1,
          reason: 'week $i isPartial',
        );
      }
    });

    test('a Monday with nothing elapsed yet has a null rate and is '
        'excluded from the overall rate, even though it already has a '
        'completion', () async {
      final today = d(2026, 7, 20);
      final currentWeekStart = today.addDays(-(today.weekday - 1));
      expect(today, currentWeekStart); // sanity: today really is this week's Monday
      final clock = FixedClock(today);

      final taskRepo = TaskRepository(db, clock);
      // Starts exactly at the current week's Monday: every one of the 7
      // prior weeks in the window has nothing scheduled at all, and the
      // current week itself has no ELAPSED scheduled occurrences yet either
      // - today is the week's first day, so nothing in it is before today.
      final task = await taskRepo.createTask(
        title: 'New habit',
        recurrenceType: RecurrenceType.daily,
        startDate: currentWeekStart,
      );
      await CompletionRepository(db, clock, verifier: FakeProofVerifier())
          .completeOccurrence(taskId: task.id, occurrenceDate: today);

      final service = buildService(clock);
      final snapshot = await service.consistency();

      for (var i = 0; i < snapshot.weeks.length - 1; i++) {
        final week = snapshot.weeks[i];
        expect(week.scheduled, 0, reason: 'week $i scheduled');
        expect(week.completed, 0, reason: 'week $i completed');
        expect(week.rate, isNull, reason: 'week $i rate');
      }

      final currentWeek = snapshot.weeks.last;
      // scheduled excludes today (nothing in this week has elapsed yet),
      // but completed still counts today's own stone (a completion can
      // only ever exist for today or earlier, never back-filled).
      expect(currentWeek.scheduled, 0);
      expect(currentWeek.completed, 1);
      expect(currentWeek.rate, isNull);
      expect(currentWeek.isPartial, isTrue);

      // No week in the window had anything SCHEDULED - the current week's
      // one completion doesn't change that, per the null-rate exclusion.
      expect(snapshot.overallRate, isNull);
    });

    test('a past week is unaffected by the elapsed-only rule, and the '
        'current week counts only its elapsed days toward scheduled', () async {
      final today = d(2026, 7, 23); // a Thursday: Mon/Tue/Wed have elapsed
      final currentWeekStart = today.addDays(-(today.weekday - 1)); // Monday
      final oldestWeekStart =
          currentWeekStart.addDays(-7 * (InsightsService.consistencyWindowWeeks - 1));

      final seedClock = FixedClock(oldestWeekStart);
      final taskRepo = TaskRepository(db, seedClock);
      final task = await taskRepo.createTask(
        title: 'Daily habit',
        recurrenceType: RecurrenceType.daily,
        startDate: oldestWeekStart.addDays(-30), // well before the window
      );

      // Skip exactly 2 days, both inside the 4th week (index 3) of the
      // window - a fully-past week, so unaffected by the elapsed-only rule
      // either way. Complete every other day up to and including
      // YESTERDAY (Wednesday) - deliberately NOT today, so this test's
      // current-week numbers land cleanly on 3/3 with no clamping; a
      // completion landing on today itself (and the clamp that can result)
      // is covered by the next, dedicated test.
      final skipped = {oldestWeekStart.addDays(7 * 3 + 1), oldestWeekStart.addDays(7 * 3 + 4)};
      final loopEnd = today.addDays(-1);
      var date = oldestWeekStart;
      while (!date.isAfter(loopEnd)) {
        if (!skipped.contains(date)) {
          await CompletionRepository(db, FixedClock(date), verifier: FakeProofVerifier())
              .completeOccurrence(taskId: task.id, occurrenceDate: date);
        }
        date = date.addDays(1);
      }

      final service = buildService(FixedClock(today));
      final snapshot = await service.consistency();

      // Every past week (index 0..6) is untouched by the fix: every one of
      // its dates was already elapsed, so scheduled still counts the whole
      // 7-day week exactly as before.
      for (var i = 0; i < 7; i++) {
        final week = snapshot.weeks[i];
        expect(week.scheduled, 7, reason: 'week $i scheduled');
        expect(week.isPartial, isFalse, reason: 'week $i isPartial');
        if (i == 3) {
          expect(week.completed, 5, reason: 'week $i completed');
          expect(week.rate, 5 / 7, reason: 'week $i rate');
        } else {
          expect(week.completed, 7, reason: 'week $i completed');
          expect(week.rate, 1.0, reason: 'week $i rate');
        }
      }

      // Current week (Mon..Sun): only Mon/Tue/Wed have elapsed (today is
      // Thursday), so scheduled counts 3, not 7 - and all 3 were completed,
      // so completed matches scheduled exactly.
      final currentWeek = snapshot.weeks.last;
      expect(currentWeek.scheduled, 3);
      expect(currentWeek.completed, 3);
      expect(currentWeek.rate, 1.0);
      expect(currentWeek.isPartial, isTrue);

      const pastScheduled = 7 * 7;
      const pastCompleted = pastScheduled - 2;
      final totalScheduled = pastScheduled + currentWeek.scheduled;
      final totalCompleted = pastCompleted + currentWeek.completed;
      expect(snapshot.overallRate, totalCompleted / totalScheduled);
    });

    test("a rate that would exceed 1.0 is clamped to exactly 1.0 - here "
        "because today's own completion is counted in completed while "
        'today is excluded from scheduled', () async {
      final today = d(2026, 7, 23); // a Thursday: Mon/Tue/Wed have elapsed
      final currentWeekStart = today.addDays(-(today.weekday - 1));
      final clock = FixedClock(today);
      final taskRepo = TaskRepository(db, FixedClock(currentWeekStart));
      final task = await taskRepo.createTask(
        title: 'Daily habit',
        recurrenceType: RecurrenceType.daily,
        startDate: currentWeekStart,
      );

      // All 4 days so far this week (Mon, Tue, Wed, and today/Thu) are
      // completed: scheduled only counts the 3 elapsed days (Mon-Wed), but
      // completed counts all 4, so the raw ratio (4/3) would exceed 1.0.
      for (var offset = 0; offset <= 3; offset++) {
        final date = currentWeekStart.addDays(offset);
        await CompletionRepository(db, FixedClock(date), verifier: FakeProofVerifier())
            .completeOccurrence(taskId: task.id, occurrenceDate: date);
      }

      final service = buildService(clock);
      final snapshot = await service.consistency();

      final currentWeek = snapshot.weeks.last;
      expect(currentWeek.scheduled, 3); // raw count stays truthful, unclamped
      expect(currentWeek.completed, 4); // raw count stays truthful, unclamped
      expect(currentWeek.rate, 1.0); // 4/3 clamped down to exactly 1.0
    });

    test("completed counts still include an archived task's already-placed "
        'stones, even though scheduled stops counting it once archived', () async {
      // A Thursday, not a Monday: the current week already has elapsed
      // days (Mon-Wed) by the time this runs, so scheduled==0 below is
      // unambiguously caused by archival, not by "nothing has elapsed yet"
      // (the separate cause the Monday test above already covers).
      final today = d(2026, 7, 23);
      final clock = FixedClock(today);
      final taskRepo = TaskRepository(db, clock);
      final task = await taskRepo.createTask(
        title: 'Will be archived',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await CompletionRepository(db, clock, verifier: FakeProofVerifier())
          .completeOccurrence(taskId: task.id, occurrenceDate: today);
      await taskRepo.archiveTask(task.id);

      final service = buildService(clock);
      final snapshot = await service.consistency();

      final currentWeek = snapshot.weeks.last;
      expect(currentWeek.scheduled, 0); // archived: no longer active
      expect(currentWeek.completed, 1); // the stone still counts
    });
  });

  group('bestTimeOfDay', () {
    test('zero completions returns all-zero buckets and a null peak index',
        () async {
      final service = buildService(FixedClock(d(2026, 7, 20)));

      final result = await service.bestTimeOfDay();

      expect(result.bucketCounts, [0, 0, 0, 0, 0, 0]);
      expect(result.total, 0);
      expect(result.peakBucketIndex, isNull);
    });

    test('buckets stones by local hour, counting verified and pending '
        'alike and excluding tombstoned ones', () async {
      final clock = FixedClock(d(2026, 7, 20));
      final taskRepo = TaskRepository(db, clock);
      final task = await taskRepo.createTask(
        title: 'Habit',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      // Bucket 0 ([0,4)): one verified completion at 02:00.
      await seedCompletion(
        db,
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        completedAt: localMillisAt(d(2026, 7, 10), 2),
        status: VerificationStatus.verified,
      );
      // Bucket 2 ([8,12)): one verified at 09:00, one PENDING at 10:00 -
      // pending still counts as a stone.
      await seedCompletion(
        db,
        taskId: task.id,
        occurrenceDate: d(2026, 7, 11),
        completedAt: localMillisAt(d(2026, 7, 11), 9),
        status: VerificationStatus.verified,
      );
      await seedCompletion(
        db,
        taskId: task.id,
        occurrenceDate: d(2026, 7, 12),
        completedAt: localMillisAt(d(2026, 7, 12), 10),
        status: VerificationStatus.pending,
      );
      // Tombstoned: must be excluded entirely.
      await seedCompletion(
        db,
        taskId: task.id,
        occurrenceDate: d(2026, 7, 13),
        completedAt: localMillisAt(d(2026, 7, 13), 22),
        status: VerificationStatus.rejected,
        tombstoned: true,
      );

      final service = buildService(clock);
      final result = await service.bestTimeOfDay();

      expect(result.bucketCounts, [1, 0, 2, 0, 0, 0]);
      expect(result.total, 3);
      expect(result.peakBucketIndex, 2);
    });

    test('a tie between two buckets resolves to the earliest one', () async {
      final clock = FixedClock(d(2026, 7, 20));
      final taskRepo = TaskRepository(db, clock);
      final task = await taskRepo.createTask(
        title: 'Habit',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      // Two stones in bucket 1 ([4,8)) and two in bucket 4 ([16,20)) - a
      // tie; bucket 1, being earlier, must win.
      for (final hour in [5, 6]) {
        await seedCompletion(
          db,
          taskId: task.id,
          occurrenceDate: d(2026, 7, 10),
          slot: hour,
          completedAt: localMillisAt(d(2026, 7, 10), hour),
        );
      }
      for (final hour in [17, 18]) {
        await seedCompletion(
          db,
          taskId: task.id,
          occurrenceDate: d(2026, 7, 11),
          slot: hour,
          completedAt: localMillisAt(d(2026, 7, 11), hour),
        );
      }

      final service = buildService(clock);
      final result = await service.bestTimeOfDay();

      expect(result.bucketCounts[1], 2);
      expect(result.bucketCounts[4], 2);
      expect(result.peakBucketIndex, 1);
    });
  });

  group('rankProjection', () {
    test('zero pace (nothing verified within the trailing window) returns '
        'no projection', () async {
      final today = d(2026, 8, 15);
      final clock = FixedClock(today);
      final taskRepo = TaskRepository(db, clock);
      final task = await taskRepo.createTask(
        title: 'Habit',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 1, 1),
      );

      // Verified, but 40 days ago - outside the 28-day pace window. Still
      // counts toward total altitude (so the user isn't at 0/Summit), just
      // not toward pace.
      final outsideWindow = today.addDays(-40);
      await seedCompletion(
        db,
        taskId: task.id,
        occurrenceDate: outsideWindow,
        completedAt: outsideWindow.toUtcMidnight().millisecondsSinceEpoch,
        points: 100,
      );

      final service = buildService(clock);
      final result = await service.rankProjection();

      expect(result, isNull);
    });

    test('already at Summit returns no projection regardless of pace',
        () async {
      final today = d(2026, 8, 15);
      final clock = FixedClock(today);
      final taskRepo = TaskRepository(db, clock);
      final task = await taskRepo.createTask(
        title: 'Habit',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 1, 1),
      );

      // Comfortably past the Summit threshold (8,849 m), all within the
      // pace window too, so pace itself is clearly positive.
      await seedCompletion(
        db,
        taskId: task.id,
        occurrenceDate: today,
        completedAt: today.toUtcMidnight().millisecondsSinceEpoch,
        points: 9000,
      );

      final service = buildService(clock);
      final result = await service.rankProjection();

      expect(result, isNull);
    });

    test('pending completions never count toward pace', () async {
      final today = d(2026, 8, 15);
      final clock = FixedClock(today);
      final taskRepo = TaskRepository(db, clock);
      final task = await taskRepo.createTask(
        title: 'Habit',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 1, 1),
      );

      // Only a PENDING completion within the window, with a large point
      // value - pace must stay at 0, so there's no projection.
      await seedCompletion(
        db,
        taskId: task.id,
        occurrenceDate: today,
        completedAt: today.toUtcMidnight().millisecondsSinceEpoch,
        status: VerificationStatus.pending,
        points: 500,
      );

      final service = buildService(clock);
      final result = await service.rankProjection();

      expect(result, isNull);
    });

    test('computes nextTier, metresRemaining, metresPerWeek and a '
        'ceil-rounded projected date', () async {
      final today = d(2026, 8, 15);
      final clock = FixedClock(today);
      final taskRepoA = TaskRepository(db, clock);
      final taskA = await taskRepoA.createTask(
        title: 'Outside window',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 1, 1),
      );
      final taskB = await taskRepoA.createTask(
        title: 'Inside window',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 1, 1),
      );

      // 40 days ago: counts toward total altitude but not toward pace.
      final outsideWindow = today.addDays(-40);
      await seedCompletion(
        db,
        taskId: taskA.id,
        occurrenceDate: outsideWindow,
        completedAt: outsideWindow.toUtcMidnight().millisecondsSinceEpoch,
        points: 72,
      );
      // Today: inside the trailing 28-day window.
      await seedCompletion(
        db,
        taskId: taskB.id,
        occurrenceDate: today,
        completedAt: today.toUtcMidnight().millisecondsSinceEpoch,
        points: 28,
      );

      // Total altitude = 72 + 28 = 100 (Pebble tier, next is Cairn @ 150).
      // Pace = 28 points / 28 days = 1.0 m/day = 7.0 m/week exactly.
      final service = buildService(clock);
      final result = await service.rankProjection();

      expect(result, isNotNull);
      expect(result!.nextTier, RankTier.cairn);
      expect(result.metresRemaining, 50); // 150 - 100
      expect(result.metresPerWeek, 7.0);
      expect(result.projectedDate, today.addDays(50)); // ceil(50 / 1.0)
    });
  });
}
