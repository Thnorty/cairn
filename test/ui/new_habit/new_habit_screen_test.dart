import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/ui/home/home_screen.dart';
import 'package:cairn/src/ui/new_habit/new_habit_screen.dart';
import 'package:cairn/src/ui/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// Wraps [testWidgets] with the same drift + flutter_test teardown fix-up
/// `home_screen_test.dart`'s own `testHomeWidgets` uses: cancelling a
/// `.watch()` stream subscription (which `HomeScreen`'s
/// `homeSnapshotProvider` holds) schedules a zero-duration `Timer` on
/// widget-tree teardown, which flutter_test's own invariant check trips
/// over unless something pumps once more afterward. Only strictly needed
/// by the tests that pump `HomeScreen` itself (the end-to-end group
/// below), but reusing one wrapper for the whole file is simpler than
/// splitting it in two and is harmless for the rest.
void testNewHabitWidgets(
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
  // Pumps NewHabitScreen pushed on top of a placeholder base route (an
  // "open" button), the same pattern camera_capture_screen_test.dart uses:
  // popping the sole/first route in a Navigator bubbles to "close the app"
  // rather than actually removing it (Route.popDisposition), so a test
  // that needs Navigator.pop() to genuinely take effect must give
  // NewHabitScreen a real previous route to reveal.
  Future<void> pumpPushed(WidgetTester tester, AppDatabase db, Clock clock) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const NewHabitScreen(),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('recurrence variants swap controls', () {
    testNewHabitWidgets('defaults to Daily with no extra recurrence panel', (tester) async {
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await pumpPushed(tester, db, FixedClock(d(2026, 7, 10)));

      expect(find.text('New habit'), findsOneWidget);
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('On these days'), findsNothing);
      expect(find.text('Day of the month'), findsNothing);
      expect(find.text('On this date'), findsNothing);
      expect(find.text('TIMES OF DAY'), findsOneWidget);
      expect(find.text('TIME OF DAY'), findsNothing);
    });

    testNewHabitWidgets('switching to Weekly shows the day-of-week picker only', (tester) async {
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await pumpPushed(tester, db, FixedClock(d(2026, 7, 10)));

      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();

      expect(find.text('On these days'), findsOneWidget);
      expect(find.text('Day of the month'), findsNothing);
      expect(find.text('On this date'), findsNothing);
    });

    testNewHabitWidgets('switching to Monthly shows the day-of-month grid by default', (tester) async {
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await pumpPushed(tester, db, FixedClock(d(2026, 7, 10)));

      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();

      expect(find.text('Day of the month'), findsOneWidget);
      expect(find.text('Which week'), findsNothing);
      expect(find.text('Which day'), findsNothing);
    });

    testNewHabitWidgets(
        'the monthly mode toggle swaps to the nth-weekday controls and back',
        (tester) async {
      final db = inMemoryDatabase();
      addTearDown(db.close);
      // 2026-07-10 is a Friday (see date_number_formatting_test.dart's
      // fixture: 2026-07-15 is a Wednesday), so the default monthWeekday
      // (today.weekday) is Friday and the default monthNth is 1st.
      await pumpPushed(tester, db, FixedClock(d(2026, 7, 10)));

      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();

      expect(find.text('On the 10th'), findsOneWidget);
      expect(find.text('On the 1st Friday'), findsOneWidget);

      final nthToggle = find.byKey(const ValueKey('monthly-mode-nth-weekday'));
      await tester.ensureVisible(nthToggle);
      await tester.tap(nthToggle);
      await tester.pumpAndSettle();

      expect(find.text('Which week'), findsOneWidget);
      expect(find.text('Which day'), findsOneWidget);
      expect(find.text('Day of the month'), findsNothing);

      final dayToggle = find.byKey(const ValueKey('monthly-mode-day'));
      await tester.ensureVisible(dayToggle);
      await tester.tap(dayToggle);
      await tester.pumpAndSettle();

      expect(find.text('Day of the month'), findsOneWidget);
      expect(find.text('Which week'), findsNothing);
    });

    testNewHabitWidgets('switching to Once shows the date panel and singular time label', (tester) async {
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await pumpPushed(tester, db, FixedClock(d(2026, 7, 10)));

      await tester.tap(find.text('Once'));
      await tester.pumpAndSettle();

      expect(find.text('On this date'), findsOneWidget);
      expect(find.text('Fri, Jul 10'), findsOneWidget);
      expect(find.text('TIME OF DAY'), findsOneWidget);
      expect(find.text('TIMES OF DAY'), findsNothing);
      expect(find.text('Add a time'), findsOneWidget);
    });

    testNewHabitWidgets('switching types never stacks more than one recurrence panel', (tester) async {
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await pumpPushed(tester, db, FixedClock(d(2026, 7, 10)));

      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();

      expect(find.text('On these days'), findsNothing);
      expect(find.text('Day of the month'), findsOneWidget);
    });
  });

  group('valid submissions call TaskRepository.createTask correctly', () {
    testNewHabitWidgets('Daily: title + startDate = today, no recurrence fields', (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await pumpPushed(tester, db, clock);

      await tester.enterText(find.byType(TextField), 'Meditate 10 min');
      await tester.pump();
      await tester.tap(find.text('Create habit'));
      await tester.pumpAndSettle();

      expect(find.byType(NewHabitScreen), findsNothing); // popped back

      final tasks = await TaskRepository(db, clock).activeTasks();
      expect(tasks, hasLength(1));
      final task = tasks.single;
      expect(task.title, 'Meditate 10 min');
      expect(task.recurrenceType, RecurrenceType.daily);
      expect(task.startDate, d(2026, 7, 10));
      expect(task.weeklyDays, isNull);
      expect(task.monthlyMode, isNull);
      expect(task.dueDate, isNull);
      expect(task.dueTimes, isEmpty);
    });

    testNewHabitWidgets('Weekly: submits the selected ISO weekdays, sorted', (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await pumpPushed(tester, db, clock);

      await tester.enterText(find.byType(TextField), 'Gym');
      await tester.pump();
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      // Tap Thursday (ISO 4) then Tuesday (ISO 2), out of order, to prove
      // the submitted list is sorted rather than insertion-ordered.
      final thu = find.byKey(const ValueKey('weekday-circle-4'));
      await tester.ensureVisible(thu);
      await tester.tap(thu);
      await tester.pump();
      final tue = find.byKey(const ValueKey('weekday-circle-2'));
      await tester.ensureVisible(tue);
      await tester.tap(tue);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create habit'));
      await tester.pumpAndSettle();

      final tasks = await TaskRepository(db, clock).activeTasks();
      expect(tasks.single.recurrenceType, RecurrenceType.weekly);
      expect(tasks.single.weeklyDays, [2, 4]);
    });

    testNewHabitWidgets('Monthly (day-of-month): submits the picked day', (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await pumpPushed(tester, db, clock);

      await tester.enterText(find.byType(TextField), 'Pay rent');
      await tester.pump();
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      final day31 = find.byKey(const ValueKey('month-day-circle-31'));
      await tester.ensureVisible(day31);
      await tester.tap(day31);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create habit'));
      await tester.pumpAndSettle();

      final tasks = await TaskRepository(db, clock).activeTasks();
      expect(tasks.single.recurrenceType, RecurrenceType.monthly);
      expect(tasks.single.monthlyMode, MonthlyMode.dayOfMonth);
      expect(tasks.single.monthDay, 31);
      expect(tasks.single.monthNth, isNull);
      expect(tasks.single.monthWeekday, isNull);
    });

    testNewHabitWidgets('Monthly (nth-weekday): submits the picked ordinal and weekday', (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await pumpPushed(tester, db, clock);

      await tester.enterText(find.byType(TextField), 'Team retro');
      await tester.pump();
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      final nthToggle = find.byKey(const ValueKey('monthly-mode-nth-weekday'));
      await tester.ensureVisible(nthToggle);
      await tester.tap(nthToggle);
      await tester.pumpAndSettle();
      final lastChip = find.byKey(const ValueKey('month-nth-chip--1')); // Last
      await tester.ensureVisible(lastChip);
      await tester.tap(lastChip);
      await tester.pump();
      final fridayCircle = find.byKey(const ValueKey('month-weekday-circle-5')); // Friday
      await tester.ensureVisible(fridayCircle);
      await tester.tap(fridayCircle);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create habit'));
      await tester.pumpAndSettle();

      final tasks = await TaskRepository(db, clock).activeTasks();
      expect(tasks.single.recurrenceType, RecurrenceType.monthly);
      expect(tasks.single.monthlyMode, MonthlyMode.nthWeekday);
      expect(tasks.single.monthNth, -1);
      expect(tasks.single.monthWeekday, 5);
      expect(tasks.single.monthDay, isNull);
    });

    testNewHabitWidgets('Once: startDate and dueDate both default to today', (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await pumpPushed(tester, db, clock);

      await tester.enterText(find.byType(TextField), 'Passport renewal');
      await tester.pump();
      await tester.tap(find.text('Once'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create habit'));
      await tester.pumpAndSettle();

      final tasks = await TaskRepository(db, clock).activeTasks();
      expect(tasks.single.recurrenceType, RecurrenceType.once);
      expect(tasks.single.dueDate, d(2026, 7, 10));
      expect(tasks.single.startDate, d(2026, 7, 10));
    });
  });

  group('invalid input is hard to express', () {
    testNewHabitWidgets('an empty title disables Create and creates nothing', (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await pumpPushed(tester, db, clock);

      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.onPressed, isNull);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.byType(NewHabitScreen), findsOneWidget); // still here
      expect(await TaskRepository(db, clock).activeTasks(), isEmpty);
    });

    testNewHabitWidgets('Weekly with no day selected disables Create and creates nothing', (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await pumpPushed(tester, db, clock);

      await tester.enterText(find.byType(TextField), 'Gym');
      await tester.pump();
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();

      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.onPressed, isNull);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.byType(NewHabitScreen), findsOneWidget);
      expect(await TaskRepository(db, clock).activeTasks(), isEmpty);
    });

    testNewHabitWidgets('Create re-enables once a title is entered and a weekday is picked', (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await pumpPushed(tester, db, clock);

      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Gym');
      await tester.pump();
      expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed, isNull);

      final monday = find.byKey(const ValueKey('weekday-circle-1'));
      await tester.ensureVisible(monday);
      await tester.tap(monday);
      await tester.pump();
      expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed, isNotNull);
    });
  });

  group('navigation', () {
    testNewHabitWidgets('the back button pops without creating anything', (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await pumpPushed(tester, db, clock);

      await tester.enterText(find.byType(TextField), 'Whatever');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('back-button')));
      await tester.pumpAndSettle();

      expect(find.byType(NewHabitScreen), findsNothing);
      expect(await TaskRepository(db, clock).activeTasks(), isEmpty);
    });
  });

  group('end to end from Home', () {
    testNewHabitWidgets(
        'the New habit header pill opens the screen, and a created task appears on Home immediately',
        (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = inMemoryDatabase();
      addTearDown(db.close);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      // Starting from an empty database, "New habit" appears twice (the
      // header pill and the Empty Today CTA); tap the header one.
      await tester.tap(find.text('New habit').first);
      await tester.pumpAndSettle();

      expect(find.byType(NewHabitScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Read 20 pages');
      await tester.pump();
      await tester.tap(find.text('Create habit'));
      await tester.pumpAndSettle();

      expect(find.byType(NewHabitScreen), findsNothing);
      expect(find.text('Read 20 pages'), findsOneWidget);
      expect(find.text('Prove it'), findsOneWidget);
    });

    testNewHabitWidgets('the Empty Today CTA also opens the New Habit screen', (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = inMemoryDatabase();
      addTearDown(db.close);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Your first stone is waiting'), findsOneWidget);

      await tester.tap(find.text('New habit').last);
      await tester.pumpAndSettle();

      expect(find.byType(NewHabitScreen), findsOneWidget);
    });
  });
}
