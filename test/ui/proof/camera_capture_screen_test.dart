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

  group('VerifyingOverlay', () {
    testWidgets('renders title and task-named subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: VerifyingOverlay(taskTitle: 'Read 20 pages'),
          ),
        ),
      );

      expect(find.text('Verifying…'), findsOneWidget);
      expect(
        find.text('Checking your proof for “Read 20 pages”'),
        findsOneWidget,
      );
    });

    testWidgets('lit stone advances over time bottom to top', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: VerifyingOverlay(taskTitle: 'Read 20 pages'),
          ),
        ),
      );

      // Start of cycle (t = 0 ms): Bottom stone (index 0) is lit.
      await tester.pump();
      var glyph = tester.widget<MiniCairnGlyph>(find.byType(MiniCairnGlyph));
      expect(glyph.highlightedIndex, 0);

      // Advance by 800 ms (1/3 of 2400 ms cycle): Middle stone (index 1) is lit.
      await tester.pump(const Duration(milliseconds: 800));
      glyph = tester.widget<MiniCairnGlyph>(find.byType(MiniCairnGlyph));
      expect(glyph.highlightedIndex, 1);

      // Advance by 800 ms (2/3 of 2400 ms cycle): Top stone (index 2) is lit.
      await tester.pump(const Duration(milliseconds: 800));
      glyph = tester.widget<MiniCairnGlyph>(find.byType(MiniCairnGlyph));
      expect(glyph.highlightedIndex, 2);

      // Advance by 800 ms (3/3 of 2400 ms cycle): Loop restarts at Bottom stone (index 0).
      await tester.pump(const Duration(milliseconds: 800));
      glyph = tester.widget<MiniCairnGlyph>(find.byType(MiniCairnGlyph));
      expect(glyph.highlightedIndex, 0);
    });

    testWidgets(
        'renders static state and does not change across pumps when animations are disabled',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: VerifyingOverlay(taskTitle: 'Read 20 pages'),
            ),
          ),
        ),
      );

      await tester.pump();
      var glyph = tester.widget<MiniCairnGlyph>(find.byType(MiniCairnGlyph));
      expect(glyph.highlightedIndex, isNull);

      // Pump time forward - static state remains unchanged with highlightedIndex == null
      await tester.pump(const Duration(milliseconds: 800));
      glyph = tester.widget<MiniCairnGlyph>(find.byType(MiniCairnGlyph));
      expect(glyph.highlightedIndex, isNull);

      await tester.pump(const Duration(milliseconds: 800));
      glyph = tester.widget<MiniCairnGlyph>(find.byType(MiniCairnGlyph));
      expect(glyph.highlightedIndex, isNull);
    });
  });

  group('MiniCairnGlyph highlight falloff', () {
    // Regression guard. The travelling highlight is driven by a raised-cosine
    // falloff whose coefficient controls how many periods fit inside each
    // stone's 1/3-wide window. It shipped at 9.0, which packs three periods
    // in, so a stone went bright -> dark -> BRIGHT AGAIN -> dark on a single
    // pass: a flicker, not a highlight travelling up the stack. The correct
    // 3.0 completes exactly half a period, so each stone peaks once and
    // decays monotonically.
    //
    // The existing tests could not catch it: they assert `highlightedIndex`,
    // which is floor() math and never touches the intensity curve. This reads
    // the opacity actually rendered.
    double bottomStoneOpacity(WidgetTester tester) {
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('verifying-stone-bottom')),
              matching: find.byType(Opacity),
            )
            .first,
      );
      return opacity.opacity;
    }

    testWidgets('the bottom stone fades monotonically as its turn passes',
        (tester) async {
      final samples = <double>[];
      // Sweep from the bottom stone's peak (p = 0) to the edge of its window
      // (p = 1/3), where the middle stone takes over.
      for (var i = 0; i <= 12; i++) {
        final p = (i / 12) * (1 / 3);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: MiniCairnGlyph(progress: p),
          ),
        );
        samples.add(bottomStoneOpacity(tester));
      }

      expect(samples.first, greaterThan(samples.last),
          reason: 'the stone should be brightest at the start of its turn');

      for (var i = 1; i < samples.length; i++) {
        expect(
          samples[i],
          lessThanOrEqualTo(samples[i - 1] + 1e-9),
          reason: 'brightness rose again at sample $i (${samples[i]} after '
              '${samples[i - 1]}) - that is the double-peak flicker',
        );
      }
    });

    testWidgets('every stone renders fully opaque when progress is null',
        (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: MiniCairnGlyph(),
        ),
      );
      expect(bottomStoneOpacity(tester), 1.0);
    });
  });
}
