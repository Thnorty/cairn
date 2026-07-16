import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/ui/proof/camera_capture_screen.dart';
import 'package:cairn/src/ui/proof/camera_unavailable_screen.dart';
import 'package:cairn/src/ui/proof/daily_limit_screen.dart';
import 'package:cairn/src/ui/proof/verify_failed_screen.dart';
import 'package:cairn/src/ui/proof/verify_pending_screen.dart';
import 'package:cairn/src/ui/proof/verify_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';
import '../../support/fake_camera_session.dart';
import '../../support/fake_proof_pipeline.dart';
import '../../support/fake_recent_photos.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late TaskRepository taskRepo;

  setUp(() {
    db = inMemoryDatabase();
    clock = FixedClock(d(2026, 7, 10));
    taskRepo = TaskRepository(db, clock);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Task> makeTask() => taskRepo.createTask(
        title: 'Read 20 pages',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

  Future<void> pumpScreen(
    WidgetTester tester,
    Task task, {
    required FakeCameraSession session,
    DebugVerifierMode verifierMode = DebugVerifierMode.pass,
    FakePhotoCapture? photoCapture,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          cameraSessionFactoryProvider.overrideWithValue(() => session),
          debugVerifierModeProvider.overrideWith((ref) => verifierMode),
          imageCompressorProvider.overrideWithValue(FakeImageCompressor()),
          proofPhotoStoreProvider.overrideWithValue(FakeProofPhotoStore()),
          photoCaptureProvider.overrideWithValue(
            photoCapture ?? FakePhotoCapture(takenAtMillis: clock.nowEpochMillis()),
          ),
          // Only exercised by the camera-unavailable-navigation test below,
          // but harmless to override everywhere: keeps every test in this
          // file off the real `photo_manager`/`permission_handler` platform
          // channels, which `flutter test` cannot exercise.
          recentPhotoLibraryProvider.overrideWithValue(FakeRecentPhotoLibrary()),
          appSettingsOpenerProvider.overrideWithValue(FakeAppSettingsOpener()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CameraCaptureScreen(
            taskId: task.id,
            taskTitle: task.title,
            cairnNumber: 1,
            occurrenceDate: d(2026, 7, 10),
            slot: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the live preview chrome once the camera initializes',
      (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession();
    await pumpScreen(tester, task, session: session);

    expect(session.initializeCalls, 1);
    expect(find.text('Read 20 pages'), findsOneWidget);
    expect(find.text('PROVING'), findsOneWidget);
    expect(find.byKey(const ValueKey('camera-gallery')), findsOneWidget);
    expect(find.byKey(const ValueKey('camera-shutter')), findsOneWidget);
    expect(find.byKey(const ValueKey('camera-flip')), findsOneWidget);
  });

  testWidgets(
      'navigates to CameraUnavailableScreen (not an inline fallback) when '
      'the camera cannot be started', (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession(initializeResult: false);
    await pumpScreen(tester, task, session: session);

    expect(find.byType(CameraUnavailableScreen), findsOneWidget);
    expect(find.byType(CameraCaptureScreen), findsNothing);
    expect(find.text('Camera unavailable'), findsOneWidget);
  });

  testWidgets('flip camera selects the other camera, not just calling '
      'switchCamera with no visible effect', (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession();
    await pumpScreen(tester, task, session: session);

    final startingLens = session.currentLens;
    await tester.tap(find.byKey(const ValueKey('camera-flip')));
    await tester.pumpAndSettle();

    expect(session.switchCameraCalls, 1);
    expect(session.currentLens, isNot(startingLens));

    // Flipping again returns to the original lens: a real two-camera device
    // only ever has the one "other" camera to switch to.
    await tester.tap(find.byKey(const ValueKey('camera-flip')));
    await tester.pumpAndSettle();
    expect(session.currentLens, startingLens);
  });

  testWidgets(
      'the flip control is disabled (not a dead-looking active button) '
      'when only one camera is available', (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession(hasMultipleCameras: false);
    await pumpScreen(tester, task, session: session);

    // Still rendered (so its layout slot doesn't jump around), but tapping
    // it does nothing - see _IconLabelButton's dimmed-opacity treatment for
    // a null onTap, matching how this same screen already disables (rather
    // than hides) the shutter/gallery controls while busy.
    expect(find.byKey(const ValueKey('camera-flip')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('camera-flip')));
    await tester.pumpAndSettle();

    expect(session.switchCameraCalls, 0);
  });

  testWidgets(
      'tapping the shutter captures via the session and shows the Photo '
      'Review screen WITHOUT submitting - only "Use this photo" submits and '
      'routes to Verify Result on a pass', (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession();
    await pumpScreen(tester, task, session: session, verifierMode: DebugVerifierMode.pass);

    await tester.tap(find.byKey(const ValueKey('camera-shutter')));
    await tester.pumpAndSettle();

    // Captured, but not yet submitted: the review screen shows, "Verifying…"
    // does not, and nothing was written to the database.
    expect(session.takePictureCalls, 1);
    expect(find.text('Use this photo'), findsOneWidget);
    expect(find.text('Retake'), findsOneWidget);
    expect(find.text('Verifying…'), findsNothing);
    expect(find.byType(VerifyResultScreen), findsNothing);
    expect(await db.select(db.completions).get(), isEmpty);

    await tester.tap(find.byKey(const ValueKey('photo-review-use')));
    // Deliberately not pumpAndSettle here: the "Verifying…" overlay runs a
    // repeating animation, which never settles.
    await tester.pump();
    expect(find.text('Verifying…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyResultScreen), findsOneWidget);
    expect(find.byType(CameraCaptureScreen), findsNothing);
  });

  testWidgets(
      'Retake discards the capture (no submit) and returns to the live '
      'camera', (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession();
    await pumpScreen(tester, task, session: session);

    await tester.tap(find.byKey(const ValueKey('camera-shutter')));
    await tester.pumpAndSettle();
    expect(find.text('Retake'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('photo-review-secondary')));
    await tester.pumpAndSettle();

    // Back to the live viewfinder - not a freshly re-initialized one either.
    expect(find.byKey(const ValueKey('camera-shutter')), findsOneWidget);
    expect(find.text('Retake'), findsNothing);
    expect(session.initializeCalls, 1);
    expect(await db.select(db.completions).get(), isEmpty);
  });

  testWidgets(
      'closing the Photo Review screen (X) backs out without ever '
      'submitting', (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          cameraSessionFactoryProvider.overrideWithValue(() => session),
          imageCompressorProvider.overrideWithValue(FakeImageCompressor()),
          proofPhotoStoreProvider.overrideWithValue(FakeProofPhotoStore()),
          photoCaptureProvider.overrideWithValue(
            FakePhotoCapture(takenAtMillis: clock.nowEpochMillis()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => CameraCaptureScreen(
                  taskId: task.id,
                  taskTitle: task.title,
                  cairnNumber: 1,
                  occurrenceDate: d(2026, 7, 10),
                  slot: 0,
                ),
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

    await tester.tap(find.byKey(const ValueKey('camera-shutter')));
    await tester.pumpAndSettle();
    expect(find.text('Use this photo'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('camera-close')));
    await tester.pumpAndSettle();

    expect(find.byType(CameraCaptureScreen), findsNothing);
    expect(await db.select(db.completions).get(), isEmpty);
  });

  testWidgets('a rejected submit with attempts remaining routes to Verify Failed',
      (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession();
    await pumpScreen(tester, task, session: session, verifierMode: DebugVerifierMode.reject);

    await tester.tap(find.byKey(const ValueKey('camera-shutter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photo-review-use')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyFailedScreen), findsOneWidget);
    expect(find.text('Debug mode: reject'), findsOneWidget);
    expect(find.text('2 tries left today'), findsOneWidget);
  });

  testWidgets(
      'an unreachable verifier routes to Verify Pending, keeping the photo',
      (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession();
    await pumpScreen(tester, task, session: session, verifierMode: DebugVerifierMode.offline);

    await tester.tap(find.byKey(const ValueKey('camera-shutter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photo-review-use')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyPendingScreen), findsOneWidget);
  });

  testWidgets(
      'the gallery button shows the Photo Review screen ("Choose another") '
      'without submitting, and "Use this photo" lands in the same result '
      'routing as the shutter', (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession();
    await pumpScreen(tester, task, session: session, verifierMode: DebugVerifierMode.pass);

    await tester.tap(find.byKey(const ValueKey('camera-gallery')));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyResultScreen), findsNothing);
    expect(find.text('Choose another'), findsOneWidget);
    expect(find.text('Retake'), findsNothing);
    expect(session.takePictureCalls, 0); // never touched the live camera
    expect(await db.select(db.completions).get(), isEmpty);

    await tester.tap(find.byKey(const ValueKey('photo-review-use')));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyResultScreen), findsOneWidget);
    expect(session.takePictureCalls, 0);
  });

  testWidgets(
      '"Choose another" reopens the gallery picker (not a submit) and shows '
      'whatever it returns', (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession();
    final capture = FakePhotoCapture(takenAtMillis: clock.nowEpochMillis());
    await pumpScreen(
      tester,
      task,
      session: session,
      verifierMode: DebugVerifierMode.pass,
      photoCapture: capture,
    );

    await tester.tap(find.byKey(const ValueKey('camera-gallery')));
    await tester.pumpAndSettle();
    expect(capture.callCount, 1);

    await tester.tap(find.byKey(const ValueKey('photo-review-secondary')));
    await tester.pumpAndSettle();

    expect(capture.callCount, 2); // the picker was asked again
    expect(find.byType(VerifyResultScreen), findsNothing);
    expect(find.text('Choose another'), findsOneWidget); // still reviewing
    expect(await db.select(db.completions).get(), isEmpty);
  });

  testWidgets('tapping close pops back without recording anything',
      (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          cameraSessionFactoryProvider.overrideWithValue(() => session),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => CameraCaptureScreen(
                  taskId: task.id,
                  taskTitle: task.title,
                  cairnNumber: 1,
                  occurrenceDate: d(2026, 7, 10),
                  slot: 0,
                ),
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

    expect(find.byType(CameraCaptureScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('camera-close')));
    await tester.pumpAndSettle();

    expect(find.byType(CameraCaptureScreen), findsNothing);
    expect(find.byType(DailyLimitScreen), findsNothing);
    expect(session.takePictureCalls, 0);
    final completions = await db.select(db.completions).get();
    expect(completions, isEmpty);
  });
}
