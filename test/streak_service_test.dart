import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/local_date.dart';
import 'package:cairn/src/services/streak_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A tiny completions fake: a set of (date, slot) pairs that are "done".
class FakeCompletions {
  final Set<(LocalDate, int)> done = {};

  void complete(LocalDate date, [int slot = 0]) => done.add((date, slot));

  bool call(LocalDate date, int slot) => done.contains((date, slot));
}

void main() {
  const service = StreakService();

  group('basic current streak', () {
    test('streak breaks on the first incomplete elapsed scheduled date', () {
      final task = makeTask(startDate: d(2026, 7, 1));
      final c = FakeCompletions();
      c.complete(d(2026, 7, 8));
      c.complete(d(2026, 7, 9));
      c.complete(d(2026, 7, 10));
      // 2026-07-07 left incomplete.
      final today = d(2026, 7, 10);
      expect(service.currentStreak(task, today, c.call), 3);
    });

    test('yesterday incomplete and today still pending yields a zero streak',
        () {
      final task = makeTask(startDate: d(2026, 7, 1));
      final c = FakeCompletions();
      c.complete(d(2026, 7, 8));
      // 2026-07-09 left incomplete; 2026-07-10 (today) also incomplete.
      final today = d(2026, 7, 10);
      expect(service.currentStreak(task, today, c.call), 0);
    });
  });

  group('today-pending', () {
    test('streak preserved when today is not yet done', () {
      final task = makeTask(startDate: d(2026, 7, 1));
      final c = FakeCompletions();
      c.complete(d(2026, 7, 7));
      c.complete(d(2026, 7, 8));
      c.complete(d(2026, 7, 9));
      // 2026-07-10 (today) intentionally left incomplete.
      // 2026-07-06 also left incomplete, to prove the walk stops there.
      final today = d(2026, 7, 10);
      expect(service.currentStreak(task, today, c.call), 3);
    });
  });

  group('non-scheduled skip', () {
    test('Mon/Wed/Fri streak survives Tue/Thu/weekend', () {
      final task = makeTask(
        recurrenceType: RecurrenceType.weekly,
        weeklyDays: [1, 3, 5],
        startDate: d(2026, 7, 6), // Monday
      );
      final c = FakeCompletions();
      c.complete(d(2026, 7, 6)); // Mon
      c.complete(d(2026, 7, 8)); // Wed
      c.complete(d(2026, 7, 10)); // Fri
      c.complete(d(2026, 7, 13)); // Mon
      final today = d(2026, 7, 13);
      expect(service.currentStreak(task, today, c.call), 4);
    });
  });

  group('multi-slot', () {
    test('one slot done out of two = date not complete, breaks next day', () {
      final task = makeTask(
        dueTimes: ['08:00', '20:00'],
        startDate: d(2026, 7, 1),
      );
      final c = FakeCompletions();
      c.complete(d(2026, 7, 8), 0);
      c.complete(d(2026, 7, 8), 1);
      c.complete(d(2026, 7, 9), 0); // only slot 0 — day incomplete
      c.complete(d(2026, 7, 10), 0);
      c.complete(d(2026, 7, 10), 1);
      final today = d(2026, 7, 10);
      expect(service.currentStreak(task, today, c.call), 1);
    });

    test('both slots done on a day counts the day once, not twice', () {
      final task = makeTask(
        dueTimes: ['08:00', '20:00'],
        startDate: d(2026, 7, 1),
      );
      final c = FakeCompletions();
      c.complete(d(2026, 7, 9), 0);
      c.complete(d(2026, 7, 9), 1);
      c.complete(d(2026, 7, 10), 0);
      c.complete(d(2026, 7, 10), 1);
      final today = d(2026, 7, 10);
      expect(service.currentStreak(task, today, c.call), 2);
    });
  });

  group('longestStreak', () {
    test('picks the longest run, independent of the current streak', () {
      final task = makeTask(startDate: d(2026, 7, 1));
      final c = FakeCompletions();
      // Run of 4: Jul 1-4.
      for (final day in [1, 2, 3, 4]) {
        c.complete(d(2026, 7, day));
      }
      // Jul 5 incomplete (gap).
      // Run of 2: Jul 6-7.
      c.complete(d(2026, 7, 6));
      c.complete(d(2026, 7, 7));
      // Jul 8 (today) left incomplete — pending, not a break.
      final today = d(2026, 7, 8);
      expect(service.longestStreak(task, today, c.call), 4);
      // Today is pending so the walk continues into the Jul 6-7 run.
      expect(service.currentStreak(task, today, c.call), 2);
    });

    test('today pending does not truncate an in-progress longest run', () {
      final task = makeTask(startDate: d(2026, 7, 1));
      final c = FakeCompletions();
      c.complete(d(2026, 7, 1));
      c.complete(d(2026, 7, 2));
      c.complete(d(2026, 7, 3));
      // today (Jul 4) left incomplete/pending.
      final today = d(2026, 7, 4);
      expect(service.longestStreak(task, today, c.call), 3);
      expect(service.currentStreak(task, today, c.call), 3);
    });
  });

  group('empty history', () {
    test('no scheduled dates yet returns zero streaks', () {
      final task = makeTask(startDate: d(2026, 8, 1));
      final c = FakeCompletions();
      final today = d(2026, 7, 1);
      expect(service.currentStreak(task, today, c.call), 0);
      expect(service.longestStreak(task, today, c.call), 0);
    });
  });
}
