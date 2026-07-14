import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/ui/proof/camera_capture_screen.dart';
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
            FakePhotoCapture(takenAtMillis: clock.nowEpochMillis()),
          ),
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
      'degrades to the gallery-only fallback when the camera is unavailable',
      (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession(initializeResult: false);
    await pumpScreen(tester, task, session: session);

    expect(
      find.text('Camera unavailable. Choose a photo from your gallery instead.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('camera-flip')), findsNothing);
    expect(find.byKey(const ValueKey('camera-shutter')), findsNothing);
    expect(find.byKey(const ValueKey('camera-gallery')), findsOneWidget);
  });

  testWidgets('flip camera calls CameraSession.switchCamera', (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession();
    await pumpScreen(tester, task, session: session);

    await tester.tap(find.byKey(const ValueKey('camera-flip')));
    await tester.pumpAndSettle();

    expect(session.switchCameraCalls, 1);
  });

  testWidgets(
      'tapping the shutter captures via the session, submits the proof, '
      'and routes to Verify Result on a pass', (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession();
    await pumpScreen(tester, task, session: session, verifierMode: DebugVerifierMode.pass);

    await tester.tap(find.byKey(const ValueKey('camera-shutter')));
    // Deliberately not pumpAndSettle here: the "Verifying…" overlay runs a
    // repeating animation, which never settles.
    await tester.pump();
    expect(find.text('Verifying…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(session.takePictureCalls, 1);
    expect(find.byType(VerifyResultScreen), findsOneWidget);
    expect(find.byType(CameraCaptureScreen), findsNothing);
  });

  testWidgets('a rejected submit with attempts remaining routes to Verify Failed',
      (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession();
    await pumpScreen(tester, task, session: session, verifierMode: DebugVerifierMode.reject);

    await tester.tap(find.byKey(const ValueKey('camera-shutter')));
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyPendingScreen), findsOneWidget);
  });

  testWidgets(
      'the gallery button goes through image_picker and lands in the same '
      'result routing as the shutter', (tester) async {
    final task = await makeTask();
    final session = FakeCameraSession();
    await pumpScreen(tester, task, session: session, verifierMode: DebugVerifierMode.pass);

    await tester.tap(find.byKey(const ValueKey('camera-gallery')));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyResultScreen), findsOneWidget);
    expect(session.takePictureCalls, 0); // never touched the live camera
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
