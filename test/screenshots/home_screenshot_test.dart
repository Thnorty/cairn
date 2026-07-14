import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/proof_verdict.dart';
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

/// Wraps [testWidgets] with a fix-up for a drift + flutter_test interaction:
/// cancelling a `.watch()` stream subscription - which happens when the
/// widget tree (and with it Home's `homeSnapshotProvider`) is torn down -
/// schedules a zero-duration `Timer` (see drift's
/// `QueryStream._onCancelOrPause`). In the running app that's harmless (it
/// fires on the very next frame); `flutter_test`'s own `_verifyInvariants`
/// check runs immediately once the test body returns, before any further
/// pump, so without this every test here fails with "A Timer is still
/// pending even after the widget tree was disposed." Replacing the tree
/// with something trivial (unmounting the `ProviderScope`, which schedules
/// the timer) and pumping with an explicit (if zero) duration -
/// `tester.pump()` with no argument never elapses flutter_test's fake
/// clock, so it would never actually fire the timer - runs that disposal
/// while the test can still pump afterward.
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

/// Dev-only screenshot harness: not an assertion suite. It renders the
/// screen at the designs' own logical size (392x846, see every
/// `design/*.dc.html`'s device frame) with the real bundled fonts loaded
/// (via [loadAppFonts], so text is legible rather than `flutter_test`'s
/// default Ahem boxes), and writes a PNG under a gitignored output folder
/// so a human can flip between it and the corresponding `.dc.html` file.
/// No pixel-equality assertions and no golden-file comparison - see this
/// file's own history for why: those are brittle across font-hinting and
/// rendering-backend differences, and the point here is a quick visual
/// spot check across the many screens still to come, not a CI gate.
///
/// Pays for itself starting with the *next* screen: copy one `testWidgets`
/// block, point it at a different seeded scenario, done.
void main() {
  const outputDir = 'test/screenshots/output';

  setUpAll(() async {
    await loadAppFonts();
  });

  Future<void> captureAt392x846(
    WidgetTester tester,
    String fileName,
  ) async {
    final view = tester.view;
    const pixelRatio = 2.0;
    view.physicalSize = const Size(392, 846) * pixelRatio;
    view.devicePixelRatio = pixelRatio;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    final boundaryFinder = find.byKey(const ValueKey('screenshot-boundary'));
    await tester.pumpAndSettle();

    // The image capture *and* the file write both have to run inside
    // runAsync, not just the capture: flutter_test runs the test body in a
    // FakeAsync zone, and real dart:io I/O (Directory.create/
    // File.writeAsBytes) never completes there - its completion relies on
    // the real event loop, which FakeAsync doesn't drive. Doing the file
    // write outside this block (only the image capture inside) hangs the
    // test indefinitely with no error, which is exactly what happened
    // before this comment existed; runAsync briefly steps outside the fake
    // zone into real async, which is what both real I/O operations need.
    await tester.runAsync(() async {
      final boundary = tester
          .renderObject<RenderRepaintBoundary>(boundaryFinder);
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

  testScreenshotWidgets('Home, populated with all four card states', (tester) async {
    final clock = FixedClock(d(2026, 7, 10));
    final db = inMemoryDatabase();
    addTearDown(db.close);

    final taskRepo = TaskRepository(db, clock);
    final completionRepo =
        CompletionRepository(db, clock, verifier: FakeProofVerifier());

    final verifiedTask = await taskRepo.createTask(
      title: 'Morning workout',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );
    await completionRepo.completeOccurrence(
      taskId: verifiedTask.id,
      occurrenceDate: d(2026, 7, 10),
    );

    await taskRepo.createTask(
      title: 'Read 20 pages',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    await taskRepo.createTask(
      title: 'Water the plants',
      recurrenceType: RecurrenceType.daily,
      dueTimes: const ['20:00'],
      startDate: d(2026, 7, 1),
    );

    await tester.pumpWidget(appAt(db, clock));
    await captureAt392x846(tester, 'home_populated.png');
  });

  testScreenshotWidgets('Home, with an awaiting-verification card', (tester) async {
    final clock = FixedClock(d(2026, 7, 10));
    final db = inMemoryDatabase();
    addTearDown(db.close);

    final taskRepo = TaskRepository(db, clock);
    final offlineVerifier =
        FakeProofVerifier((_) => const VerifierUnavailable('offline'));
    final completionRepo =
        CompletionRepository(db, clock, verifier: offlineVerifier);

    final task = await taskRepo.createTask(
      title: 'Meditate 10 min',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );
    await completionRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: ProofData(imageBytes: Uint8List.fromList([1, 2, 3])),
    );

    await taskRepo.createTask(
      title: 'Read 20 pages',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    await tester.pumpWidget(appAt(db, clock));
    await captureAt392x846(tester, 'home_awaiting_verification.png');
  });

  testScreenshotWidgets('Empty Today', (tester) async {
    final clock = FixedClock(d(2026, 7, 10));
    final db = inMemoryDatabase();
    addTearDown(db.close);

    await tester.pumpWidget(appAt(db, clock));
    await captureAt392x846(tester, 'empty_today.png');
  });
}
