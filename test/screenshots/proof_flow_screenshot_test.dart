import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/services/recent_photo_library.dart';
import 'package:cairn/src/ui/proof/camera_capture_screen.dart';
import 'package:cairn/src/ui/proof/camera_unavailable_screen.dart';
import 'package:cairn/src/ui/proof/daily_limit_screen.dart';
import 'package:cairn/src/ui/proof/photo_review_screen.dart';
import 'package:cairn/src/ui/proof/verify_failed_screen.dart';
import 'package:cairn/src/ui/proof/verify_pending_screen.dart';
import 'package:cairn/src/ui/proof/verify_result_screen.dart';
import 'package:cairn/src/ui/proof/verify_too_old_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fake_camera_session.dart';
import '../support/fake_proof_pipeline.dart';
import '../support/fake_recent_photos.dart';
import '../support/load_app_fonts.dart';

/// A [ProofVerifier] whose [verify] call never resolves, so a screenshot of
/// the "Verifying…" overlay can be captured without the screen ever routing
/// away to an outcome screen mid-test.
class _NeverResolvingVerifier implements ProofVerifier {
  @override
  Future<ProofVerifierResponse> verify(ProofRequest request) =>
      Completer<ProofVerifierResponse>().future;
}

/// Dev-only screenshot harness for the six proof-flow screens
/// (`Cairn Camera Capture.dc.html`, `Cairn Verify Result.dc.html`,
/// `Cairn Verify Failed.dc.html`, `Cairn Verify Failed - No Retries.dc.html`,
/// `Cairn Verify Pending.dc.html`, `Cairn Daily Limit.dc.html`) - the
/// same idea as `home_screenshot_test.dart`, extended to this run's screens.
/// No assertions beyond "it rendered without throwing": a human flips
/// between the written PNGs here and the corresponding `.dc.html` file for a
/// visual spot check, which is the whole point (a previous Phase 3 run's
/// four visual defects all passed their test suite and were only visible in
/// the images).
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
    await tester.pump();

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

  Widget boundaryApp(Widget home) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RepaintBoundary(
        key: const ValueKey('screenshot-boundary'),
        child: home,
      ),
    );
  }

  testWidgets('Camera Capture: live preview chrome', (tester) async {
    final clock = FixedClock(d(2026, 7, 10));
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final taskRepo = TaskRepository(db, clock);
    final task = await taskRepo.createTask(
      title: 'Read 20 pages',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );
    final session = FakeCameraSession();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          cameraSessionFactoryProvider.overrideWithValue(() => session),
          imageCompressorProvider.overrideWithValue(FakeImageCompressor()),
          proofPhotoStoreProvider.overrideWithValue(FakeProofPhotoStore()),
        ],
        child: boundaryApp(CameraCaptureScreen(
          taskId: task.id,
          taskTitle: task.title,
          occurrenceDate: d(2026, 7, 10),
          slot: 0,
        )),
      ),
    );
    await tester.pumpAndSettle();
    await captureAt392x846(tester, 'camera_capture_live.png');
  });

  testWidgets('Camera Capture: Verifying overlay', (tester) async {
    final clock = FixedClock(d(2026, 7, 10));
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final taskRepo = TaskRepository(db, clock);
    final task = await taskRepo.createTask(
      title: 'Read 20 pages',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );
    final session = FakeCameraSession();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          cameraSessionFactoryProvider.overrideWithValue(() => session),
          imageCompressorProvider.overrideWithValue(FakeImageCompressor()),
          proofPhotoStoreProvider.overrideWithValue(FakeProofPhotoStore()),
          // Never resolves, so the screen stays on "Verifying…" for exactly
          // as long as this test lets it - long enough to capture a frame
          // of the pulsing overlay without ever routing away from it.
          proofVerifierProvider.overrideWithValue(_NeverResolvingVerifier()),
        ],
        child: boundaryApp(CameraCaptureScreen(
          taskId: task.id,
          taskTitle: task.title,
          occurrenceDate: d(2026, 7, 10),
          slot: 0,
        )),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('camera-shutter')));
    // Deliberately not pumpAndSettle: the overlay's animation repeats
    // forever, and (with the never-resolving verifier below) the screen
    // never routes away either. One pump is enough to reach the
    // "Verifying…" frame.
    await tester.pump();
    await captureAt392x846(tester, 'camera_capture_verifying.png');
  });

  testWidgets('Verify Result', (tester) async {
    await tester.pumpWidget(boundaryApp(VerifyResultScreen(
      taskTitle: 'Read 20 pages',
      completedAtMillis: DateTime(2026, 7, 10, 7, 16).millisecondsSinceEpoch,
      imageBytes: kFakeImageBytes,
      reason: 'An open book with visible printed text, held in natural '
          'light - consistent with a reading session.',
      cairnNumber: 1,
      stoneCount: 5,
      onDone: () {},
    )));
    await tester.pumpAndSettle();
    await captureAt392x846(tester, 'verify_result.png');
  });

  testWidgets('Verify Failed (retries remaining)', (tester) async {
    await tester.pumpWidget(boundaryApp(VerifyFailedScreen(
      taskTitle: 'Read 20 pages',
      atMillis: DateTime(2026, 7, 10, 7, 16).millisecondsSinceEpoch,
      imageBytes: kFakeImageBytes,
      cairnNumber: 1,
      stoneCount: 4,
      attemptsRemaining: 2,
      reason: 'This looks like a screenshot of a screen rather than a live '
          'photo - try capturing the page directly.',
      onRetake: () {},
      onCancel: () {},
    )));
    await tester.pumpAndSettle();
    await captureAt392x846(tester, 'verify_failed.png');
  });

  testWidgets('Verify Failed - No Retries', (tester) async {
    await tester.pumpWidget(boundaryApp(VerifyFailedScreen(
      taskTitle: 'Read 20 pages',
      atMillis: DateTime(2026, 7, 10, 7, 16).millisecondsSinceEpoch,
      imageBytes: kFakeImageBytes,
      cairnNumber: 1,
      stoneCount: 4,
      attemptsRemaining: 0,
      onCancel: () {},
    )));
    await tester.pumpAndSettle();
    await captureAt392x846(tester, 'verify_failed_no_retries.png');
  });

  testWidgets('Verify Pending', (tester) async {
    await tester.pumpWidget(boundaryApp(VerifyPendingScreen(
      taskTitle: 'Meditate 10 min',
      completedAtMillis: DateTime(2026, 7, 10, 7, 16).millisecondsSinceEpoch,
      imageBytes: kFakeImageBytes,
      heldMetres: 13,
      onBackToToday: () {},
    )));
    await tester.pumpAndSettle();
    await captureAt392x846(tester, 'verify_pending.png');
  });

  testWidgets('Daily Limit', (tester) async {
    await tester.pumpWidget(boundaryApp(DailyLimitScreen(
      dailyCap: 5,
      onGoUnlimited: () {},
      onMaybeLater: () {},
    )));
    await tester.pumpAndSettle();
    await captureAt392x846(tester, 'daily_limit.png');
  });

  testWidgets('Verify Too Old', (tester) async {
    await tester.pumpWidget(boundaryApp(VerifyTooOldScreen(
      taskTitle: 'Read 20 pages',
      photoTakenAtMillis: DateTime(2026, 7, 10, 7, 15).millisecondsSinceEpoch,
      ageMinutes: 17,
      imageBytes: kFakeImageBytes,
      attemptsRemaining: 3,
      recencyWindowMinutes: 15,
      onRetake: () {},
      onCancel: () {},
    )));
    await tester.pumpAndSettle();
    await captureAt392x846(tester, 'verify_too_old.png');
  });

  testWidgets('Camera Unavailable', (tester) async {
    final clock = FixedClock(d(2026, 7, 10));
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final taskRepo = TaskRepository(db, clock);
    final task = await taskRepo.createTask(
      title: 'Read 20 pages',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );
    final recentPhotos = FakeRecentPhotoLibrary(
      result: RecentPhotosLoaded([
        for (var i = 0; i < 6; i++)
          RecentPhotoAsset(id: 'a$i', thumbnail: kFakeImageBytes, takenAtMillis: clock.nowEpochMillis()),
      ]),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          recentPhotoLibraryProvider.overrideWithValue(recentPhotos),
          appSettingsOpenerProvider.overrideWithValue(FakeAppSettingsOpener()),
        ],
        child: boundaryApp(CameraUnavailableScreen(
          taskId: task.id,
          taskTitle: task.title,
          occurrenceDate: d(2026, 7, 10),
          slot: 0,
        )),
      ),
    );
    await tester.pumpAndSettle();
    await captureAt392x846(tester, 'camera_unavailable.png');
  });

  // Writes a real temp file with real (decodable) image bytes so
  // PhotoReviewScreen's Image.file genuinely renders the photo rather than
  // its error-fallback fill. Wrapped in `tester.runAsync`: real `dart:io`
  // file I/O does not resolve reliably inside a bare `testWidgets` body
  // (the same reason `captureAt392x846` above already wraps the real
  // image-encoding step this way) - calling it unwrapped previously hung
  // this exact test indefinitely.
  Future<String> writeTempPhoto(WidgetTester tester) async {
    late String path;
    await tester.runAsync(() async {
      final tempDir = await Directory.systemTemp.createTemp('photo_review_screenshot');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {
          // Best-effort only: on Windows, Image.file's decoded-frame cache
          // can still hold this file open briefly after the test body
          // finishes, which fails a delete here - harmless, since the OS
          // temp directory is cleaned up independently regardless.
        }
      });
      final photoFile = File('${tempDir.path}${Platform.pathSeparator}proof.jpg');
      await photoFile.writeAsBytes(kFakeImageBytes);
      path = photoFile.path;
    });
    return path;
  }

  testWidgets('Photo Review (camera path: "Retake")', (tester) async {
    final imagePath = await writeTempPhoto(tester);

    await tester.pumpWidget(boundaryApp(PhotoReviewScreen(
      imagePath: imagePath,
      taskTitle: 'Read 20 pages',
      secondaryLabel: 'Retake',
      onUsePhoto: () {},
      onSecondaryAction: () {},
      onClose: () {},
    )));
    await tester.pumpAndSettle();
    await captureAt392x846(tester, 'photo_review_camera.png');
  });

  testWidgets('Photo Review (gallery path: "Choose another")', (tester) async {
    final imagePath = await writeTempPhoto(tester);

    await tester.pumpWidget(boundaryApp(PhotoReviewScreen(
      imagePath: imagePath,
      taskTitle: 'Read 20 pages',
      secondaryLabel: 'Choose another',
      onUsePhoto: () {},
      onSecondaryAction: () {},
      onClose: () {},
    )));
    await tester.pumpAndSettle();
    await captureAt392x846(tester, 'photo_review_gallery.png');
  });
}
