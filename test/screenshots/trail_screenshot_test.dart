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
import 'package:cairn/src/ui/trail/how_cairns_work_screen.dart';
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

/// Dev-only screenshot harness for the Trail screen (`Cairn Trail.dc.html`)
/// - see `home_screenshot_test.dart`'s doc comment for the full rationale
/// (no pixel-equality assertions; a quick visual spot check against the
/// canonical design, here specifically for the winding-path layout with a
/// capped, a broken and a growing cairn all present at once).
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
      'Trail, one task with a capped + broken + growing cairn history',
      (tester) async {
    final clock = FixedClock(d(2026, 7, 20));
    final db = inMemoryDatabase();
    addTearDown(db.close);

    final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
    final task = await taskRepo.createTask(
      title: 'Read 20 pages',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    // Days 1-10: caps the trailhead cairn (10 stones). Day 11: missed,
    // sealing it. Days 12-14: 3 stones, sealed broken by the day-15 miss.
    // Days 16-19: 4 stones, still growing as of day 20 (today).
    final stoneDays = [
      for (var day = 1; day <= 10; day++) day,
      for (var day = 12; day <= 14; day++) day,
      for (var day = 16; day <= 19; day++) day,
    ];
    for (final day in stoneDays) {
      await CompletionRepository(db, FixedClock(d(2026, 7, day)),
              verifier: FakeProofVerifier())
          .completeOccurrence(taskId: task.id, occurrenceDate: d(2026, 7, day));
    }

    await tester.pumpWidget(appAt(db, clock));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trail'));
    await captureAt392x846(tester, 'trail_history.png');
  });

  testScreenshotWidgets(
      'Trail, a single still-growing cairn that is also the trailhead '
      '(the tallest node this layout renders - see the "WHERE YOU STARTED" '
      'marker-clearance fix)', (tester) async {
    final clock = FixedClock(d(2026, 7, 9));
    final db = inMemoryDatabase();
    addTearDown(db.close);

    final taskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
    final task = await taskRepo.createTask(
      title: 'Read 20 pages',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    // Days 1-9: 9 stones, one short of PointsService.cairnCapStones (10), so
    // this cairn never caps and is still growing as of today (day 9) - the
    // maximum stone count a growing cairn can ever show, and since it's also
    // cairn 1, it's simultaneously the trailhead: badge + a 9-stone stack +
    // title + the trailhead caption, the tallest single node this layout
    // ever has to clear with the "WHERE YOU STARTED" marker below it.
    for (var day = 1; day <= 9; day++) {
      await CompletionRepository(db, FixedClock(d(2026, 7, day)),
              verifier: FakeProofVerifier())
          .completeOccurrence(taskId: task.id, occurrenceDate: d(2026, 7, day));
    }

    await tester.pumpWidget(appAt(db, clock));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trail'));
    await captureAt392x846(tester, 'trail_single_growing_trailhead.png');
  });

  testScreenshotWidgets('How Cairns Work explainer sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RepaintBoundary(
          key: const ValueKey('screenshot-boundary'),
          child: const HowCairnsWorkScreen(),
        ),
      ),
    );
    await captureAt392x846(tester, 'how_cairns_work.png');
  });
}
