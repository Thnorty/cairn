import 'package:cairn/src/clock.dart';
import 'package:cairn/src/debug/debug_screen.dart';
import 'package:cairn/src/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('debug screen loads with an empty, in-memory database', (
    tester,
  ) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FixedClock(d(2026, 7, 1))),
        ],
        child: const MaterialApp(home: DebugScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Altitude: 0 m'), findsOneWidget);
    expect(find.textContaining('Pebble'), findsOneWidget);
    expect(find.text('No active tasks. Tap + to add one.'), findsOneWidget);
  });

  testWidgets(
    'creating a daily task via the FAB and completing it updates the altitude',
    (tester) async {
      final db = inMemoryDatabase();
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            clockProvider.overrideWithValue(FixedClock(d(2026, 7, 1))),
          ],
          child: const MaterialApp(home: DebugScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Push-ups');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Push-ups'), findsOneWidget);
      expect(find.text('Altitude: 0 m'), findsOneWidget);

      // Complete today's single untimed occurrence.
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      // Lone task's only occurrence today: base 10 + streak 1 + perfect-day 15.
      expect(find.text('Altitude: 26 m'), findsOneWidget);
      expect(find.textContaining('Cairn'), findsOneWidget);
      expect(find.textContaining('Streak: 1'), findsOneWidget);
    },
  );
}
