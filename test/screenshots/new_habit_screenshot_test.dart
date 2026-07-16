import 'dart:io';
import 'dart:ui' as ui;

import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/ui/new_habit/new_habit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/load_app_fonts.dart';

/// Dev-only screenshot harness for the New Habit screen's four canonical
/// variants (`Cairn New Habit.dc.html`'s weekly picker, `Cairn New Habit -
/// Monthly.dc.html`, `Cairn New Habit - Monthly 3rd Weekday.dc.html`,
/// `Cairn New Habit - Once.dc.html`) - the same idea as
/// `home_screenshot_test.dart`/`proof_flow_screenshot_test.dart`. No
/// assertions beyond "it rendered without throwing": a human flips between
/// the written PNGs here and the corresponding `.dc.html` file for a visual
/// spot check.
void main() {
  const outputDir = 'test/screenshots/output';

  setUpAll(() async {
    await loadAppFonts();
  });

  Future<void> captureAt392x846(WidgetTester tester, String fileName) async {
    final view = tester.view;
    const pixelRatio = 2.0;
    view.physicalSize = const Size(392, 846) * pixelRatio;
    view.devicePixelRatio = pixelRatio;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    final boundaryFinder = find.byKey(const ValueKey('screenshot-boundary'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final dir = Directory(outputDir);
      await dir.create(recursive: true);
      final file = File('$outputDir/$fileName');
      await file.writeAsBytes(pngBytes);
      // ignore: avoid_print
      print('Wrote screenshot: ${file.absolute.path}');
    });
  }

  Future<AppDatabase> pumpScreen(WidgetTester tester, Clock clock) async {
    final db = inMemoryDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RepaintBoundary(
            key: const ValueKey('screenshot-boundary'),
            child: const NewHabitScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  testWidgets('New Habit: Weekly, matching the base design file', (tester) async {
    final clock = FixedClock(d(2026, 7, 10));
    final db = await pumpScreen(tester, clock);
    addTearDown(db.close);

    await tester.enterText(find.byType(TextField), 'Read 20 pages');
    await tester.pump();
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    // Sun/Tue/Thu selected, matching Cairn New Habit.dc.html's example.
    await tester.tap(find.byKey(const ValueKey('weekday-circle-7')));
    await tester.tap(find.byKey(const ValueKey('weekday-circle-2')));
    await tester.tap(find.byKey(const ValueKey('weekday-circle-4')));
    await tester.pumpAndSettle();
    // Matches the design's populated "8:00 AM" / "8:00 PM" example slots.
    await tester.enterText(find.byType(TextField), 'Read 20 pages');
    await tester.pump();

    await captureAt392x846(tester, 'new_habit_weekly.png');
  });

  testWidgets('New Habit: Monthly (day-of-month), matching the design', (tester) async {
    final clock = FixedClock(d(2026, 7, 10));
    final db = await pumpScreen(tester, clock);
    addTearDown(db.close);

    await tester.enterText(find.byType(TextField), 'Read 20 pages');
    await tester.pump();
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    final day31 = find.byKey(const ValueKey('month-day-circle-31'));
    await tester.ensureVisible(day31);
    await tester.tap(day31);
    await tester.pumpAndSettle();

    await captureAt392x846(tester, 'new_habit_monthly_day_of_month.png');
  });

  testWidgets('New Habit: Monthly (3rd weekday), matching the design', (tester) async {
    final clock = FixedClock(d(2026, 7, 10));
    final db = await pumpScreen(tester, clock);
    addTearDown(db.close);

    await tester.enterText(find.byType(TextField), 'Read 20 pages');
    await tester.pump();
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('monthly-mode-nth-weekday')));
    await tester.pumpAndSettle();
    final thirdChip = find.byKey(const ValueKey('month-nth-chip-3'));
    await tester.ensureVisible(thirdChip);
    await tester.tap(thirdChip);
    await tester.pump();
    final fridayCircle = find.byKey(const ValueKey('month-weekday-circle-5'));
    await tester.ensureVisible(fridayCircle);
    await tester.tap(fridayCircle);
    await tester.pumpAndSettle();

    await captureAt392x846(tester, 'new_habit_monthly_nth_weekday.png');
  });

  testWidgets('New Habit: Once, matching the design', (tester) async {
    final clock = FixedClock(d(2026, 7, 10));
    final db = await pumpScreen(tester, clock);
    addTearDown(db.close);

    await tester.enterText(find.byType(TextField), 'Read 20 pages');
    await tester.pump();
    await tester.tap(find.text('Once'));
    await tester.pumpAndSettle();

    await captureAt392x846(tester, 'new_habit_once.png');
  });
}
