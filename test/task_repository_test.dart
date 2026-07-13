import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late TaskRepository repo;
  final clock = FixedClock(d(2026, 7, 10));

  setUp(() {
    db = inMemoryDatabase();
    repo = TaskRepository(db, clock);
  });

  tearDown(() async {
    await db.close();
  });

  group('createTask validation rejections', () {
    test('weekly with null weeklyDays throws', () {
      expect(
        () => repo.createTask(
          title: 'Gym',
          recurrenceType: RecurrenceType.weekly,
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });

    test('weekly with empty weeklyDays throws', () {
      expect(
        () => repo.createTask(
          title: 'Gym',
          recurrenceType: RecurrenceType.weekly,
          weeklyDays: const [],
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });

    test('weekly with a weekday outside 1..7 throws', () {
      expect(
        () => repo.createTask(
          title: 'Gym',
          recurrenceType: RecurrenceType.weekly,
          weeklyDays: const [0],
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.createTask(
          title: 'Gym',
          recurrenceType: RecurrenceType.weekly,
          weeklyDays: const [8],
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });

    test('weekly with duplicate weekdays throws', () {
      expect(
        () => repo.createTask(
          title: 'Gym',
          recurrenceType: RecurrenceType.weekly,
          weeklyDays: const [1, 1],
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });

    test('monthly with null monthlyMode throws', () {
      expect(
        () => repo.createTask(
          title: 'Rent',
          recurrenceType: RecurrenceType.monthly,
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });

    test('monthly day_of_month with null monthDay throws', () {
      expect(
        () => repo.createTask(
          title: 'Rent',
          recurrenceType: RecurrenceType.monthly,
          monthlyMode: MonthlyMode.dayOfMonth,
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });

    test('monthly day_of_month with monthDay outside 1..31 throws', () {
      expect(
        () => repo.createTask(
          title: 'Rent',
          recurrenceType: RecurrenceType.monthly,
          monthlyMode: MonthlyMode.dayOfMonth,
          monthDay: 0,
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.createTask(
          title: 'Rent',
          recurrenceType: RecurrenceType.monthly,
          monthlyMode: MonthlyMode.dayOfMonth,
          monthDay: 32,
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });

    test(
        'monthly nth_weekday with monthNth not in {1,2,3,4,-1} throws',
        () {
      expect(
        () => repo.createTask(
          title: 'Book club',
          recurrenceType: RecurrenceType.monthly,
          monthlyMode: MonthlyMode.nthWeekday,
          monthNth: 5,
          monthWeekday: DateTime.friday,
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });

    test('monthly nth_weekday with null monthWeekday throws', () {
      expect(
        () => repo.createTask(
          title: 'Book club',
          recurrenceType: RecurrenceType.monthly,
          monthlyMode: MonthlyMode.nthWeekday,
          monthNth: 1,
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });

    test('monthly nth_weekday with monthWeekday outside 1..7 throws', () {
      expect(
        () => repo.createTask(
          title: 'Book club',
          recurrenceType: RecurrenceType.monthly,
          monthlyMode: MonthlyMode.nthWeekday,
          monthNth: 1,
          monthWeekday: 8,
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });

    test('once with null dueDate throws', () {
      expect(
        () => repo.createTask(
          title: 'Passport renewal',
          recurrenceType: RecurrenceType.once,
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });

    test('once with dueDate before startDate throws', () {
      expect(
        () => repo.createTask(
          title: 'Passport renewal',
          recurrenceType: RecurrenceType.once,
          dueDate: d(2026, 6, 30),
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });

    test('once with dueDate after endDate throws', () {
      expect(
        () => repo.createTask(
          title: 'Passport renewal',
          recurrenceType: RecurrenceType.once,
          dueDate: d(2026, 8, 1),
          startDate: d(2026, 7, 1),
          endDate: d(2026, 7, 31),
        ),
        throwsArgumentError,
      );
    });

    test('endDate before startDate throws regardless of recurrenceType', () {
      expect(
        () => repo.createTask(
          title: 'Push-ups',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 10),
          endDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });

    test('dueTimes entry not matching HH:mm throws', () {
      expect(
        () => repo.createTask(
          title: 'Meds',
          recurrenceType: RecurrenceType.daily,
          dueTimes: const ['8:00'],
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.createTask(
          title: 'Meds',
          recurrenceType: RecurrenceType.daily,
          dueTimes: const ['24:00'],
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.createTask(
          title: 'Meds',
          recurrenceType: RecurrenceType.daily,
          dueTimes: const ['12:60'],
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });

    test('duplicate dueTimes entries throw', () {
      expect(
        () => repo.createTask(
          title: 'Meds',
          recurrenceType: RecurrenceType.daily,
          dueTimes: const ['08:00', '08:00'],
          startDate: d(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('createTask happy paths', () {
    test('daily task is created', () async {
      final task = await repo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      expect(task.recurrenceType, RecurrenceType.daily);
    });

    test('weekly task is created', () async {
      final task = await repo.createTask(
        title: 'Gym',
        recurrenceType: RecurrenceType.weekly,
        weeklyDays: const [1, 3, 5],
        startDate: d(2026, 7, 1),
      );
      expect(task.weeklyDays, [1, 3, 5]);
    });

    test('monthly day_of_month task is created', () async {
      final task = await repo.createTask(
        title: 'Rent',
        recurrenceType: RecurrenceType.monthly,
        monthlyMode: MonthlyMode.dayOfMonth,
        monthDay: 31,
        startDate: d(2026, 7, 1),
      );
      expect(task.monthDay, 31);
    });

    test('monthly nth_weekday task is created', () async {
      final task = await repo.createTask(
        title: 'Book club',
        recurrenceType: RecurrenceType.monthly,
        monthlyMode: MonthlyMode.nthWeekday,
        monthNth: -1,
        monthWeekday: DateTime.friday,
        startDate: d(2026, 7, 1),
      );
      expect(task.monthNth, -1);
      expect(task.monthWeekday, DateTime.friday);
    });

    test('once task is created', () async {
      final task = await repo.createTask(
        title: 'Passport renewal',
        recurrenceType: RecurrenceType.once,
        dueDate: d(2026, 7, 15),
        startDate: d(2026, 7, 1),
      );
      expect(task.dueDate, d(2026, 7, 15));
    });
  });

  group('editTask', () {
    test('nonexistent task throws', () async {
      expect(
        () => repo.editTask(
          'no-such-id',
          const TasksCompanion(title: Value('New title')),
        ),
        throwsArgumentError,
      );
    });

    test('tombstoned task throws', () async {
      final task = await repo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await repo.tombstoneDelete(task.id);

      expect(
        () => repo.editTask(
          task.id,
          const TasksCompanion(title: Value('New title')),
        ),
        throwsArgumentError,
      );
    });

    test('an invalid merge is rejected and the row is left unchanged',
        () async {
      final task = await repo.createTask(
        title: 'Gym',
        recurrenceType: RecurrenceType.weekly,
        weeklyDays: const [1, 3, 5],
        startDate: d(2026, 7, 1),
      );

      // Merging weeklyDays: [0] onto the existing weekly task is invalid.
      await expectLater(
        () => repo.editTask(
          task.id,
          const TasksCompanion(weeklyDays: Value([0])),
        ),
        throwsArgumentError,
      );

      final reloaded =
          await (db.select(db.tasks)..where((t) => t.id.equals(task.id)))
              .getSingle();
      expect(reloaded.weeklyDays, [1, 3, 5]);
      expect(reloaded.updatedAt, task.updatedAt);
    });

    test('a valid partial edit succeeds and bumps updated_at', () async {
      final task = await repo.createTask(
        title: 'Gym',
        recurrenceType: RecurrenceType.weekly,
        weeklyDays: const [1, 3, 5],
        startDate: d(2026, 7, 1),
      );

      final laterClock = FixedClock(d(2026, 7, 11));
      final laterRepo = TaskRepository(db, laterClock);

      await laterRepo.editTask(
        task.id,
        const TasksCompanion(title: Value('Gym (updated)')),
      );

      final reloaded =
          await (db.select(db.tasks)..where((t) => t.id.equals(task.id)))
              .getSingle();
      expect(reloaded.title, 'Gym (updated)');
      expect(reloaded.weeklyDays, [1, 3, 5]); // untouched fields preserved
      expect(reloaded.updatedAt, greaterThan(task.updatedAt));
    });
  });
}
