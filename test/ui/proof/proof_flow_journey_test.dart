import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/ui/home/home_screen.dart';
import 'package:cairn/src/ui/proof/camera_capture_screen.dart';
import 'package:cairn/src/ui/proof/verify_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';
import '../../support/fake_camera_session.dart';
import '../../support/fake_proof_pipeline.dart';

/// Wraps [testWidgets] with the same drift + flutter_test fix-up
/// `home_screen_test.dart`'s own `testHomeWidgets` uses: tearing down a
/// widget tree that has [HomeScreen]'s `homeSnapshotProvider` (a drift
/// `.watch()` stream) mounted schedules a zero-duration `Timer` on
/// cancellation, which `flutter_test`'s own end-of-test invariant check
/// trips over unless something pumps once more (with a real, if zero,
/// duration) after the tree is torn down.
void testJourneyWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}

void main() {
  testJourneyWidgets(
      'the whole journey: Prove it -> camera -> shutter -> Verify Result -> '
      'Done returns to a Home that already reflects the new completion',
      (tester) async {
    final clock = FixedClock(d(2026, 7, 10));
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final taskRepo = TaskRepository(db, clock);
    await taskRepo.createTask(
      title: 'Push-ups',
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
          debugVerifierModeProvider.overrideWith((ref) => DebugVerifierMode.pass),
          imageCompressorProvider.overrideWithValue(FakeImageCompressor()),
          proofPhotoStoreProvider.overrideWithValue(FakeProofPhotoStore()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prove it'), findsOneWidget);
    await tester.tap(find.text('Prove it'));
    await tester.pumpAndSettle();

    expect(find.byType(CameraCaptureScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('camera-shutter')));
    // Not pumpAndSettle across the shutter tap: the Verifying… overlay's
    // animation repeats forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyResultScreen), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Back on Home, with no manual refresh: it watches the database
    // directly, so the new completion is already reflected.
    expect(find.byType(VerifyResultScreen), findsNothing);
    expect(find.byType(CameraCaptureScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Prove it'), findsNothing);
    expect(find.textContaining('Verified ·'), findsOneWidget);
    expect(find.text('1 of 1 done'), findsOneWidget);
  });

  testJourneyWidgets(
      'Retake photo reopens the camera, and a second rejection still routes '
      "correctly (the retry loop doesn't reuse a stale screen's context)",
      (tester) async {
    final clock = FixedClock(d(2026, 7, 10));
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final taskRepo = TaskRepository(db, clock);
    await taskRepo.createTask(
      title: 'Push-ups',
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
          debugVerifierModeProvider.overrideWith((ref) => DebugVerifierMode.reject),
          imageCompressorProvider.overrideWithValue(FakeImageCompressor()),
          proofPhotoStoreProvider.overrideWithValue(FakeProofPhotoStore()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Prove it'));
    await tester.pumpAndSettle();
    expect(find.byType(CameraCaptureScreen), findsOneWidget);

    // First attempt: rejected, 2 tries left.
    await tester.tap(find.byKey(const ValueKey('camera-shutter')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text('2 tries left today'), findsOneWidget);

    // Retake reopens a fresh Camera Capture screen (not the disposed one).
    await tester.tap(find.text('Retake photo'));
    await tester.pumpAndSettle();
    expect(find.byType(CameraCaptureScreen), findsOneWidget);

    // Second attempt from the *new* camera screen: also rejected, 1 try
    // left. If the retry loop had captured a stale context/navigator from
    // the first camera screen, this would crash instead of routing.
    await tester.tap(find.byKey(const ValueKey('camera-shutter')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('1 try left today'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(CameraCaptureScreen), findsNothing);
  });
}
