import 'package:cairn/src/l10n/date_number_formatting.dart';
import 'package:cairn/src/ui/new_habit/new_habit_times_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  // formatTimeOfDay (via DateFormat.jm) needs a locale's date symbol data
  // loaded before first use, or it throws LocaleDataException. In the
  // running app this is a side effect of GlobalMaterialLocalizations
  // loading; these tests pump a bare MaterialApp with no
  // localizationsDelegates, so they need the same one-time setup directly -
  // see date_number_formatting_test.dart's identical setUpAll.
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  group('addDueTime', () {
    test('appends and sorts ascending', () {
      expect(addDueTime(const [], '08:00'), ['08:00']);
      expect(addDueTime(const ['20:00'], '08:00'), ['08:00', '20:00']);
      expect(addDueTime(const ['08:00'], '20:00'), ['08:00', '20:00']);
    });

    test('is a no-op when the time is already present', () {
      final times = ['08:00', '20:00'];
      expect(addDueTime(times, '08:00'), ['08:00', '20:00']);
    });

    test('keeps three-plus times sorted regardless of insertion order', () {
      var times = <String>[];
      times = addDueTime(times, '20:00');
      times = addDueTime(times, '07:30');
      times = addDueTime(times, '13:15');
      expect(times, ['07:30', '13:15', '20:00']);
    });
  });

  group('NewHabitTimesEditor', () {
    Widget wrap(Widget child) => MaterialApp(home: child);

    testWidgets('shows the add row when canAddMore is true', (tester) async {
      await tester.pumpWidget(wrap(NewHabitTimesEditor(
        sectionLabel: 'TIMES OF DAY',
        helperText: 'help',
        times: const [],
        canAddMore: true,
        addTimeLabel: 'Add a time',
        onAddTime: () {},
        onRemoveTime: (_) {},
        locale: const Locale('en'),
      )));

      expect(find.text('Add a time'), findsOneWidget);
    });

    testWidgets('hides the add row when canAddMore is false (Once, one slot used)', (tester) async {
      await tester.pumpWidget(wrap(NewHabitTimesEditor(
        sectionLabel: 'TIME OF DAY',
        helperText: 'help',
        times: const ['09:00'],
        canAddMore: false,
        addTimeLabel: 'Add a time',
        onAddTime: () {},
        onRemoveTime: (_) {},
        locale: const Locale('en'),
      )));

      expect(find.text('Add a time'), findsNothing);
    });

    testWidgets('renders one formatted row per configured time slot', (tester) async {
      await tester.pumpWidget(wrap(NewHabitTimesEditor(
        sectionLabel: 'TIMES OF DAY',
        helperText: 'help',
        times: const ['08:00', '20:00'],
        canAddMore: true,
        addTimeLabel: 'Add a time',
        onAddTime: () {},
        onRemoveTime: (_) {},
        locale: const Locale('en'),
      )));

      expect(
        find.text(formatTimeOfDay(timeOfDayFromHHmm('08:00'), const Locale('en'))),
        findsOneWidget,
      );
      expect(
        find.text(formatTimeOfDay(timeOfDayFromHHmm('20:00'), const Locale('en'))),
        findsOneWidget,
      );
    });

    testWidgets('tapping a slot\'s remove control reports its index', (tester) async {
      final removed = <int>[];
      await tester.pumpWidget(wrap(NewHabitTimesEditor(
        sectionLabel: 'TIMES OF DAY',
        helperText: 'help',
        times: const ['08:00', '20:00'],
        canAddMore: true,
        addTimeLabel: 'Add a time',
        onAddTime: () {},
        onRemoveTime: removed.add,
        locale: const Locale('en'),
      )));

      // Two slot rows are keyed 'time-slot-0' and 'time-slot-1'; tap the
      // second row's remove control.
      final secondRow = find.byKey(const ValueKey('time-slot-1'));
      expect(secondRow, findsOneWidget);
      await tester.tap(find.descendant(
        of: secondRow,
        matching: find.byType(GestureDetector),
      ));
      await tester.pump();

      expect(removed, [1]);
    });
  });
}
