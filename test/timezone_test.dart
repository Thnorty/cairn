import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/local_date.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'helpers.dart';

void main() {
  setUpAll(() => tz_data.initializeTimeZones());

  group('day boundaries follow local time, never UTC', () {
    test('a UTC instant can fall on the previous local calendar day', () {
      // 2026-07-11T02:00:00Z is still 2026-07-10 in New York (EDT, UTC-4).
      final instant = DateTime.utc(2026, 7, 11, 2);
      final newYork = tz.getLocation('America/New_York');
      final clock = ZonedClock(newYork, nowUtc: () => instant);

      expect(clock.today(), LocalDate(2026, 7, 10));
      // Proves this isn't accidentally using the UTC date.
      expect(clock.today(), isNot(LocalDate.of(instant)));
    });

    test('the same UTC instant yields different local dates on either side '
        'of the date line', () {
      final instant = DateTime.utc(2026, 7, 11, 23);
      final kiritimati = tz.getLocation('Pacific/Kiritimati'); // UTC+14
      final midway = tz.getLocation('Pacific/Midway'); // UTC-11

      final eastClock = ZonedClock(kiritimati, nowUtc: () => instant);
      final westClock = ZonedClock(midway, nowUtc: () => instant);

      expect(eastClock.today(), LocalDate(2026, 7, 12));
      expect(westClock.today(), LocalDate(2026, 7, 11));
    });
  });

  group('repository writes use the clock\'s local date', () {
    test('a completion recorded near local midnight gets the local '
        'occurrence_date, not the UTC one', () async {
      // 2026-07-11T02:00:00Z = 2026-07-10 22:00 local in New York.
      final instant = DateTime.utc(2026, 7, 11, 2);
      final newYork = tz.getLocation('America/New_York');
      final clock = ZonedClock(newYork, nowUtc: () => instant);

      final db = inMemoryDatabase();
      addTearDown(db.close);

      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(db, clock);

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final result = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: LocalDate(2026, 7, 10), // caller passes local "today"
      );

      expect(result, isA<CompletionRecorded>());
      final completion = (result as CompletionRecorded).completion;
      expect(completion.occurrenceDate, LocalDate(2026, 7, 10));

      // The same call with the UTC date instead is correctly rejected as a
      // back-fill, since it doesn't match the clock's local today().
      final wrongDateResult = await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: LocalDate(2026, 7, 11),
      );
      expect(wrongDateResult, isA<CompletionRejectedBackfill>());
    });
  });
}
