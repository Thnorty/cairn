import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = inMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('no back-fill', () {
    test('rejects a completion for yesterday', () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock);

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final result = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 9), // yesterday
      );

      expect(result, isA<CompletionRejectedBackfill>());
      final rows = await db.select(db.completions).get();
      expect(rows, isEmpty);
    });

    test('accepts a completion for today', () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock);

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final result = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );

      expect(result, isA<CompletionRecorded>());
    });
  });

  group('unique constraint', () {
    test('double-completing the same (task, date, slot) fails gracefully',
        () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock);

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final first = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      expect(first, isA<CompletionRecorded>());

      final second = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      expect(second, isA<CompletionRejectedAlreadyCompleted>());

      final rows = await db.select(db.completions).get();
      expect(rows, hasLength(1));
    });

    test('different slots of the same day both succeed', () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock);

      final task = await taskRepo.createTask(
        title: 'Meds',
        recurrenceType: RecurrenceType.daily,
        dueTimes: ['08:00', '20:00'],
        startDate: d(2026, 7, 1),
      );

      final slot0 = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        slot: 0,
      );
      final slot1 = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        slot: 1,
      );

      expect(slot0, isA<CompletionRecorded>());
      expect(slot1, isA<CompletionRecorded>());
    });
  });

  group('not scheduled', () {
    test('rejects a slot that is not part of the task today', () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock);

      final task = await taskRepo.createTask(
        title: 'Meds',
        recurrenceType: RecurrenceType.daily,
        dueTimes: ['08:00'], // only slot 0 exists
        startDate: d(2026, 7, 1),
      );

      final result = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
        slot: 1,
      );

      expect(result, isA<CompletionRejectedNotScheduled>());
    });

    test('rejects a weekly task on a non-scheduled day', () async {
      final clock = FixedClock(d(2026, 7, 8)); // a Wednesday
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock);

      final task = await taskRepo.createTask(
        title: 'Gym',
        recurrenceType: RecurrenceType.weekly,
        weeklyDays: [1], // Mondays only
        startDate: d(2026, 7, 1),
      );

      final result = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 8),
      );

      expect(result, isA<CompletionRejectedNotScheduled>());
    });
  });

  group('points computed at insert time', () {
    test('base + streak on the first-ever completion of a lone task', () async {
      final clock = FixedClock(d(2026, 7, 1));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock);

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final result = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 1),
      );

      final recorded = result as CompletionRecorded;
      // With only one task scheduled today, completing it is inherently the
      // day's final occurrence: base 10 + streak 1 + perfect-day 15.
      expect(recorded.completion.pointsAwarded, 26);
    });

    test('streak bonus grows day over day and caps at +10', () async {
      final taskRepo = TaskRepository(
        db,
        FixedClock(d(2026, 7, 1)),
      );
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      // Simulate completing 12 consecutive days; streak bonus should cap.
      // This is the only task scheduled, so every day is also a perfect day.
      for (var day = 1; day <= 12; day++) {
        final clock = FixedClock(d(2026, 7, day));
        final completionRepo = CompletionRepository(db, clock);
        final result = await completionRepo.completeOccurrence(
          taskId: task.id,
          occurrenceDate: d(2026, 7, day),
        );
        final points = (result as CompletionRecorded).completion.pointsAwarded;
        final expectedStreakBonus = day.clamp(0, 10);
        expect(points, 10 + expectedStreakBonus + 15, reason: 'day $day');
      }
    });

    test('perfect-day bonus attaches to the final occurrence of the day',
        () async {
      final clock = FixedClock(d(2026, 7, 1));
      final taskRepo = TaskRepository(db, clock);

      final taskA = await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final taskB = await taskRepo.createTask(
        title: 'B',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final completionRepo = CompletionRepository(db, clock);

      final firstResult = await completionRepo.completeOccurrence(
        taskId: taskA.id,
        occurrenceDate: d(2026, 7, 1),
      );
      final first = (firstResult as CompletionRecorded).completion;
      expect(first.pointsAwarded, 11); // base 10 + streak 1, no bonus yet

      final secondResult = await completionRepo.completeOccurrence(
        taskId: taskB.id,
        occurrenceDate: d(2026, 7, 1),
      );
      final second = (secondResult as CompletionRecorded).completion;
      // Last remaining occurrence of the day: base 10 + streak 1 + perfect 15.
      expect(second.pointsAwarded, 26);
    });

    test('no perfect-day bonus when another task is still incomplete',
        () async {
      final clock = FixedClock(d(2026, 7, 1));
      final taskRepo = TaskRepository(db, clock);

      final taskA = await taskRepo.createTask(
        title: 'A',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await taskRepo.createTask(
        title: 'B',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final completionRepo = CompletionRepository(db, clock);
      final result = await completionRepo.completeOccurrence(
        taskId: taskA.id,
        occurrenceDate: d(2026, 7, 1),
      );
      final completion = (result as CompletionRecorded).completion;
      expect(completion.pointsAwarded, 11); // no perfect-day bonus
    });
  });

  group('totalAltitude', () {
    test('sums points across non-tombstoned completions', () async {
      final clock = FixedClock(d(2026, 7, 1));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock);

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final result = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 1),
      );
      final completion = (result as CompletionRecorded).completion;

      expect(await completionRepo.totalAltitude(), completion.pointsAwarded);

      await completionRepo.tombstoneDelete(completion.id);
      expect(await completionRepo.totalAltitude(), 0);
    });
  });
}
