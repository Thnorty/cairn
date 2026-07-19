import 'dart:io';
import 'dart:ui' as ui;

import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/ui/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/load_app_fonts.dart';

/// See `home_screenshot_test.dart`'s identical helper for the full
/// rationale (a drift `.watch()` subscription's teardown timer needs an
/// extra pump after the widget tree is replaced).
void testScreenshotWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}

/// Dev-only screenshot harness for the Stats screen (`Cairn Stats.dc.html`)
/// - see `home_screenshot_test.dart`'s doc comment for the full rationale
/// (no pixel-equality assertions; a quick visual spot check against the
/// canonical design).
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

  Widget appAt(AppDatabase db, Clock clock) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RepaintBoundary(
          key: const ValueKey('screenshot-boundary'),
          child: const AppShell(),
        ),
      ),
    );
  }

  testScreenshotWidgets(
      'Stats, a few tasks with completions spread across the current week, '
      'one past 10 stones (a capped cairn) and a couple of live streaks',
      (tester) async {
    // 2026-07-20 is a Monday, so "today" is deliberately set mid-week
    // (Thursday the 23rd) rather than on day 20 itself: with today on the
    // week's own first day, every completion dated before it (days 1-19)
    // falls in the *previous* Mon-Sun week and "This week" would show a
    // single filled Monday bar with the rest at zero - technically correct
    // but a poor spot check for the chart's own visual range. Thursday
    // instead lands 4 of the 7 week bars in the past/today (with varying
    // fills) and leaves 3 genuinely in the future (the faint low bars),
    // matching the canonical design's own mostly-filled-plus-one-faded-bar
    // look.
    final clock = FixedClock(d(2026, 7, 23));
    final db = inMemoryDatabase();
    addTearDown(db.close);

    final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));

    final workout = await taskRepo.createTask(
      title: 'Morning workout',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );
    // Days 1-10 cap the trailhead cairn. Day 11 is missed (sealing it), then
    // days 12-23 (12 more stones) auto-splits into a second capped cairn
    // (12-21) plus a still-growing one (22-23), with a live 12-day streak as
    // of today (day 23).
    final workoutDays = [
      for (var day = 1; day <= 10; day++) day,
      for (var day = 12; day <= 23; day++) day,
    ];
    for (final day in workoutDays) {
      await CompletionRepository(db, FixedClock(d(2026, 7, day)),
              verifier: FakeProofVerifier())
          .completeOccurrence(taskId: workout.id, occurrenceDate: d(2026, 7, day));
    }

    final reading = await taskRepo.createTask(
      title: 'Read 20 pages',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );
    // A shorter, still-live 2-day streak, well short of capping a cairn -
    // and, falling on the week's Wed/Thu, gives two of this week's bars a
    // taller (2-of-2) fill than the Mon/Tue bars (1-of-2, workout only).
    for (final day in [22, 23]) {
      await CompletionRepository(db, FixedClock(d(2026, 7, day)),
              verifier: FakeProofVerifier())
          .completeOccurrence(taskId: reading.id, occurrenceDate: d(2026, 7, day));
    }

    await tester.pumpWidget(appAt(db, clock));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stats'));
    await captureAt392x846(tester, 'stats_populated.png');
  });
}
