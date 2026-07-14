import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/ui/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  Widget wrap(Widget home) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  group('AppShell', () {
    testWidgets('renders all four tabs', (tester) async {
      await tester.pumpWidget(wrap(const AppShell()));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Trail'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('starts on the Today placeholder body', (tester) async {
      await tester.pumpWidget(wrap(const AppShell()));
      await tester.pumpAndSettle();

      expect(find.text('Today - coming soon'), findsOneWidget);
      expect(find.text('Trail - coming soon'), findsNothing);
    });

    testWidgets('switching tabs changes the visible body', (tester) async {
      await tester.pumpWidget(wrap(const AppShell()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trail'));
      await tester.pumpAndSettle();
      expect(find.text('Trail - coming soon'), findsOneWidget);

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();
      expect(find.text('Stats - coming soon'), findsOneWidget);

      await tester.tap(find.text('You'));
      await tester.pumpAndSettle();
      expect(find.text('You - coming soon'), findsOneWidget);
    });

    testWidgets('long-pressing the wordmark opens the debug screen', (
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
          child: wrap(const AppShell()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Cairn'));
      await tester.pumpAndSettle();

      expect(find.text('No active tasks. Tap + to add one.'), findsOneWidget);
    });
  });
}
