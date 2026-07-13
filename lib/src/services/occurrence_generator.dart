import 'dart:math' as math;

import 'package:rrule/rrule.dart';

import '../db/database.dart';
import '../models/local_date.dart';
import '../models/occurrence.dart';

/// Expands a task's recurrence rule into concrete occurrences.
///
/// All dates are local calendar dates ([LocalDate]). The `rrule` package is
/// used for weekly and monthly-nth-weekday rules only; monthly day-of-month
/// is hand-rolled because RRULE's BYMONTHDAY skips months lacking the day
/// (BYMONTHDAY=31 skips February entirely) while Cairn's rule is clamping:
/// a task set to the 31st fires on Feb 28 (29 in leap years).
class OccurrenceGenerator {
  const OccurrenceGenerator();

  /// All occurrences of [task] within [range] (inclusive), one per slot per
  /// scheduled date, bounded by the task's start_date/end_date.
  List<Occurrence> occurrencesFor(Task task, DateRange range) {
    final times = task.dueTimes;
    return [
      for (final date in scheduledDatesFor(task, range))
        if (times.isEmpty)
          Occurrence(task: task, date: date, slot: 0)
        else
          for (var slot = 0; slot < times.length; slot++)
            Occurrence(task: task, date: date, slot: slot, time: times[slot]),
    ];
  }

  /// The task's scheduled dates within [range], bounded by
  /// start_date/end_date. Slot expansion happens in [occurrencesFor].
  List<LocalDate> scheduledDatesFor(Task task, DateRange range) {
    // Intersect the requested range with the task's own active window.
    final start = LocalDate.max(range.start, task.startDate);
    var end = range.end;
    final taskEnd = task.endDate;
    if (taskEnd != null) end = LocalDate.min(end, taskEnd);
    if (start.isAfter(end)) return const [];
    final window = DateRange(start, end);

    switch (task.recurrenceType) {
      case RecurrenceType.once:
        final due = task.dueDate;
        if (due == null) {
          throw ArgumentError('once task ${task.id} has no due_date');
        }
        return window.contains(due) ? [due] : const [];

      case RecurrenceType.daily:
        return _everyDay(window);

      case RecurrenceType.weekly:
        final days = task.weeklyDays;
        if (days == null || days.isEmpty) {
          throw ArgumentError('weekly task ${task.id} has no weekly_days');
        }
        return _fromRrule(
          task,
          window,
          RecurrenceRule(
            frequency: Frequency.weekly,
            byWeekDays: [for (final d in days) ByWeekDayEntry(d)],
          ),
        );

      case RecurrenceType.monthly:
        switch (task.monthlyMode) {
          case MonthlyMode.nthWeekday:
            final nth = task.monthNth;
            final weekday = task.monthWeekday;
            if (nth == null || weekday == null) {
              throw ArgumentError(
                  'nth_weekday task ${task.id} needs month_nth and month_weekday');
            }
            // FREQ=MONTHLY;BYDAY=3FR style; nth = -1 → BYDAY=-1FR ("Last").
            return _fromRrule(
              task,
              window,
              RecurrenceRule(
                frequency: Frequency.monthly,
                byWeekDays: [ByWeekDayEntry(weekday, nth)],
              ),
            );
          case MonthlyMode.dayOfMonth:
            final monthDay = task.monthDay;
            if (monthDay == null) {
              throw ArgumentError(
                  'day_of_month task ${task.id} needs month_day');
            }
            return _clampedMonthly(task, window, monthDay);
          case null:
            throw ArgumentError('monthly task ${task.id} has no monthly_mode');
        }
    }
  }

  List<LocalDate> _everyDay(DateRange window) {
    final result = <LocalDate>[];
    for (var d = window.start; d <= window.end; d = d.addDays(1)) {
      result.add(d);
    }
    return result;
  }

  /// Evaluates [rule] from the task's start_date and keeps instances inside
  /// [window]. The rrule package requires UTC-flagged DateTimes; we map local
  /// dates to UTC midnight and back, using UTC purely as a calendar carrier.
  List<LocalDate> _fromRrule(Task task, DateRange window, RecurrenceRule rule) {
    final instances = rule.getInstances(
      start: task.startDate.toUtcMidnight(),
      after: window.start.toUtcMidnight(),
      includeAfter: true,
      before: window.end.toUtcMidnight(),
      includeBefore: true,
    );
    return [
      for (final dt in instances)
        if (window.contains(LocalDate.of(dt))) LocalDate.of(dt),
    ];
  }

  /// Hand-rolled monthly day-of-month with clamping: for each month,
  /// day = min(month_day, lastDayOfMonth). Never skips a month.
  List<LocalDate> _clampedMonthly(Task task, DateRange window, int monthDay) {
    final result = <LocalDate>[];
    // Anchor the month walk at the task's start month so every month from
    // start_date onward fires exactly once.
    var year = task.startDate.year;
    var month = task.startDate.month;
    while (true) {
      final day = math.min(monthDay, LocalDate.lastDayOfMonth(year, month));
      final date = LocalDate(year, month, day);
      if (date.isAfter(window.end)) break;
      // The occurrence still belongs to the start month only if it's on or
      // after start_date itself (a task created on the 20th with month_day 5
      // first fires next month).
      if (date >= task.startDate && window.contains(date)) result.add(date);
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
    return result;
  }
}
