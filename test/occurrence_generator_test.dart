import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/local_date.dart';
import 'package:cairn/src/services/occurrence_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  const gen = OccurrenceGenerator();

  List<LocalDate> dates(Task task, LocalDate start, LocalDate end) =>
      gen.scheduledDatesFor(task, DateRange(start, end));

  group('once', () {
    test('fires exactly on due_date, only when in range', () {
      final task = makeTask(
        recurrenceType: RecurrenceType.once,
        dueDate: d(2026, 7, 15),
        startDate: d(2026, 7, 1),
      );
      expect(dates(task, d(2026, 7, 1), d(2026, 7, 31)), [d(2026, 7, 15)]);
      expect(dates(task, d(2026, 7, 16), d(2026, 7, 31)), isEmpty);
    });
  });

  group('daily', () {
    test('every date, bounded by start_date and end_date', () {
      final task = makeTask(
        startDate: d(2026, 7, 3),
        endDate: d(2026, 7, 5),
      );
      expect(dates(task, d(2026, 7, 1), d(2026, 7, 31)),
          [d(2026, 7, 3), d(2026, 7, 4), d(2026, 7, 5)]);
    });
  });

  group('monthly day_of_month clamping', () {
    test('task on the 31st: Jan 31, Feb 28, Mar 31, Apr 30', () {
      final task = makeTask(
        recurrenceType: RecurrenceType.monthly,
        monthlyMode: MonthlyMode.dayOfMonth,
        monthDay: 31,
        startDate: d(2026, 1, 1),
      );
      expect(dates(task, d(2026, 1, 1), d(2026, 4, 30)), [
        d(2026, 1, 31),
        d(2026, 2, 28), // 2026 is not a leap year: clamped, not skipped
        d(2026, 3, 31),
        d(2026, 4, 30),
      ]);
    });

    test('task on the 31st fires Feb 29 in leap year 2028', () {
      final task = makeTask(
        recurrenceType: RecurrenceType.monthly,
        monthlyMode: MonthlyMode.dayOfMonth,
        monthDay: 31,
        startDate: d(2028, 1, 1),
      );
      expect(dates(task, d(2028, 2, 1), d(2028, 2, 29)), [d(2028, 2, 29)]);
    });

    test('task on the 30th clamps to Feb 28 / Feb 29', () {
      final task = makeTask(
        recurrenceType: RecurrenceType.monthly,
        monthlyMode: MonthlyMode.dayOfMonth,
        monthDay: 30,
        startDate: d(2026, 1, 1),
      );
      expect(dates(task, d(2026, 2, 1), d(2026, 2, 28)), [d(2026, 2, 28)]);
      expect(dates(task, d(2028, 2, 1), d(2028, 2, 29)), [d(2028, 2, 29)]);
    });

    test('start mid-month: month_day before start_date first fires next month',
        () {
      final task = makeTask(
        recurrenceType: RecurrenceType.monthly,
        monthlyMode: MonthlyMode.dayOfMonth,
        monthDay: 5,
        startDate: d(2026, 7, 20),
      );
      expect(dates(task, d(2026, 7, 1), d(2026, 9, 30)),
          [d(2026, 8, 5), d(2026, 9, 5)]);
    });
  });

  group('monthly nth_weekday', () {
    test('3rd Friday across several months', () {
      final task = makeTask(
        recurrenceType: RecurrenceType.monthly,
        monthlyMode: MonthlyMode.nthWeekday,
        monthNth: 3,
        monthWeekday: DateTime.friday,
        startDate: d(2026, 1, 1),
      );
      expect(dates(task, d(2026, 1, 1), d(2026, 4, 30)), [
        d(2026, 1, 16),
        d(2026, 2, 20),
        d(2026, 3, 20),
        d(2026, 4, 17),
      ]);
    });

    test('Last Friday (month_nth = -1), incl. a month with 5 Fridays', () {
      final task = makeTask(
        recurrenceType: RecurrenceType.monthly,
        monthlyMode: MonthlyMode.nthWeekday,
        monthNth: -1,
        monthWeekday: DateTime.friday,
        startDate: d(2026, 1, 1),
      );
      // May 2026 has five Fridays (1, 8, 15, 22, 29): last is the 5th one.
      expect(dates(task, d(2026, 4, 1), d(2026, 6, 30)), [
        d(2026, 4, 24),
        d(2026, 5, 29),
        d(2026, 6, 26),
      ]);
    });
  });

  group('weekly', () {
    test('BYDAY Mon/Wed/Fri across a DST-style boundary', () {
      // US DST spring-forward was 2026-03-08; the local-date calendar must
      // be unaffected by wall-clock shifts.
      final task = makeTask(
        recurrenceType: RecurrenceType.weekly,
        weeklyDays: [1, 3, 5],
        startDate: d(2026, 3, 2),
      );
      expect(dates(task, d(2026, 3, 2), d(2026, 3, 13)), [
        d(2026, 3, 2), // Mon
        d(2026, 3, 4), // Wed
        d(2026, 3, 6), // Fri
        d(2026, 3, 9), // Mon (day after spring-forward)
        d(2026, 3, 11), // Wed
        d(2026, 3, 13), // Fri
      ]);
    });

    test('week start does not matter: Sunday-only task fires each Sunday', () {
      final task = makeTask(
        recurrenceType: RecurrenceType.weekly,
        weeklyDays: [7],
        startDate: d(2026, 7, 1), // a Wednesday
      );
      expect(dates(task, d(2026, 7, 1), d(2026, 7, 20)),
          [d(2026, 7, 5), d(2026, 7, 12), d(2026, 7, 19)]);
      for (final date in dates(task, d(2026, 7, 1), d(2026, 7, 20))) {
        expect(date.weekday, DateTime.sunday);
      }
    });

    test('start_date that does not match the rule is not emitted', () {
      final task = makeTask(
        recurrenceType: RecurrenceType.weekly,
        weeklyDays: [2], // Tuesdays only
        startDate: d(2026, 7, 1), // a Wednesday
      );
      final result = dates(task, d(2026, 7, 1), d(2026, 7, 14));
      expect(result, [d(2026, 7, 7), d(2026, 7, 14)]);
    });
  });

  group('slot expansion', () {
    test('empty due_times = one untimed slot 0', () {
      final task = makeTask(startDate: d(2026, 7, 1));
      final occs =
          gen.occurrencesFor(task, DateRange(d(2026, 7, 1), d(2026, 7, 1)));
      expect(occs, hasLength(1));
      expect(occs.single.slot, 0);
      expect(occs.single.time, isNull);
    });

    test('two due_times = slots 0 and 1 per scheduled date', () {
      final task = makeTask(
        dueTimes: ['08:00', '20:00'],
        startDate: d(2026, 7, 1),
      );
      final occs =
          gen.occurrencesFor(task, DateRange(d(2026, 7, 1), d(2026, 7, 2)));
      expect(occs, hasLength(4));
      expect(occs.map((o) => (o.date, o.slot, o.time)), [
        (d(2026, 7, 1), 0, '08:00'),
        (d(2026, 7, 1), 1, '20:00'),
        (d(2026, 7, 2), 0, '08:00'),
        (d(2026, 7, 2), 1, '20:00'),
      ]);
    });
  });
}
