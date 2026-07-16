import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/recent_photo_library.dart';
import 'package:cairn/src/ui/proof/camera_unavailable_screen.dart';
import 'package:cairn/src/ui/proof/verify_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';
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
    required FakeRecentPhotoLibrary recentPhotos,
    FakeAppSettingsOpener? settingsOpener,
    DebugVerifierMode verifierMode = DebugVerifierMode.pass,
    FakePhotoCapture? photoCapture,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          debugVerifierModeProvider.overrideWith((ref) => verifierMode),
          imageCompressorProvider.overrideWithValue(FakeImageCompressor()),
          proofPhotoStoreProvider.overrideWithValue(FakeProofPhotoStore()),
          photoCaptureProvider.overrideWithValue(
            photoCapture ?? FakePhotoCapture(takenAtMillis: clock.nowEpochMillis()),
          ),
          recentPhotoLibraryProvider.overrideWithValue(recentPhotos),
          appSettingsOpenerProvider.overrideWithValue(settingsOpener ?? FakeAppSettingsOpener()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CameraUnavailableScreen(
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

  testWidgets('renders the recent-photos grid from a fake provider, naming '
      'the task in the body copy', (tester) async {
    final task = await makeTask();
    final recentPhotos = FakeRecentPhotoLibrary(
      result: RecentPhotosLoaded([
        RecentPhotoAsset(id: 'a1', thumbnail: kFakeImageBytes, takenAtMillis: clock.nowEpochMillis()),
        RecentPhotoAsset(id: 'a2', thumbnail: kFakeImageBytes, takenAtMillis: clock.nowEpochMillis()),
        RecentPhotoAsset(id: 'a3', thumbnail: kFakeImageBytes, takenAtMillis: clock.nowEpochMillis()),
      ]),
    );

    await pumpScreen(tester, task, recentPhotos: recentPhotos);

    expect(find.text('Camera unavailable'), findsOneWidget);
    expect(find.textContaining('Read 20 pages'), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-photos-grid')), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-photo-a1')), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-photo-a2')), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-photo-a3')), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-photos-fallback-button')), findsNothing);
  });

  testWidgets(
      'renders recent photos in exactly the order the library returns them '
      '(newest first) rather than re-sorting or reversing them itself',
      (tester) async {
    final task = await makeTask();
    // Real-device regression: the fix for "recent photos aren't recent"
    // belongs entirely in PhotoManagerRecentPhotoLibrary.loadRecent (ordering
    // by createDate desc) - this pins the seam on this side, that the grid
    // is a pure pass-through and never reorders what the library gives it.
    final recentPhotos = FakeRecentPhotoLibrary(
      result: RecentPhotosLoaded([
        RecentPhotoAsset(id: 'newest', thumbnail: kFakeImageBytes, takenAtMillis: clock.nowEpochMillis()),
        RecentPhotoAsset(
          id: 'older',
          thumbnail: kFakeImageBytes,
          takenAtMillis: clock.nowEpochMillis() - 60000,
        ),
        RecentPhotoAsset(
          id: 'oldest',
          thumbnail: kFakeImageBytes,
          takenAtMillis: clock.nowEpochMillis() - 120000,
        ),
      ]),
    );

    await pumpScreen(tester, task, recentPhotos: recentPhotos);

    final newestX = tester.getTopLeft(find.byKey(const ValueKey('recent-photo-newest'))).dx;
    final olderX = tester.getTopLeft(find.byKey(const ValueKey('recent-photo-older'))).dx;
    final oldestX = tester.getTopLeft(find.byKey(const ValueKey('recent-photo-oldest'))).dx;
    expect(newestX, lessThan(olderX));
    expect(olderX, lessThan(oldestX));
  });

  testWidgets(
      'tapping a thumbnail shows the Photo Review screen ("Choose another") '
      'WITHOUT submitting - only "Use this photo" submits through the proof '
      'pipeline and lands on the matching outcome screen', (tester) async {
    final task = await makeTask();
    final recentPhotos = FakeRecentPhotoLibrary(
      result: RecentPhotosLoaded([
        RecentPhotoAsset(id: 'a1', thumbnail: kFakeImageBytes, takenAtMillis: clock.nowEpochMillis()),
      ]),
      filePaths: {'a1': '/fake/library/a1.jpg'},
    );

    await pumpScreen(tester, task, recentPhotos: recentPhotos);

    await tester.tap(find.byKey(const ValueKey('recent-photo-a1')));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyResultScreen), findsNothing);
    expect(find.text('Choose another'), findsOneWidget);
    expect(find.text('Use this photo'), findsOneWidget);
    expect(await db.select(db.completions).get(), isEmpty);

    await tester.tap(find.byKey(const ValueKey('photo-review-use')));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyResultScreen), findsOneWidget);
    expect(find.byType(CameraUnavailableScreen), findsNothing);
    expect(recentPhotos.filePathForCalls, 1);

    final completions = await db.select(db.completions).get();
    expect(completions, hasLength(1));
    expect(completions.single.proofSource, ProofSource.gallery);
  });

  testWidgets(
      'closing the Photo Review screen (X) after a thumbnail tap backs out '
      'without ever submitting', (tester) async {
    final task = await makeTask();
    final recentPhotos = FakeRecentPhotoLibrary(
      result: RecentPhotosLoaded([
        RecentPhotoAsset(id: 'a1', thumbnail: kFakeImageBytes, takenAtMillis: clock.nowEpochMillis()),
      ]),
      filePaths: {'a1': '/fake/library/a1.jpg'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          imageCompressorProvider.overrideWithValue(FakeImageCompressor()),
          proofPhotoStoreProvider.overrideWithValue(FakeProofPhotoStore()),
          photoCaptureProvider.overrideWithValue(
            FakePhotoCapture(takenAtMillis: clock.nowEpochMillis()),
          ),
          recentPhotoLibraryProvider.overrideWithValue(recentPhotos),
          appSettingsOpenerProvider.overrideWithValue(FakeAppSettingsOpener()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => CameraUnavailableScreen(
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

    await tester.tap(find.byKey(const ValueKey('recent-photo-a1')));
    await tester.pumpAndSettle();
    expect(find.text('Use this photo'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('camera-close')));
    await tester.pumpAndSettle();

    expect(find.byType(CameraUnavailableScreen), findsNothing);
    expect(await db.select(db.completions).get(), isEmpty);
  });

  testWidgets('a rejected thumbnail submission routes to Verify Failed, same '
      'as any other proof source', (tester) async {
    final task = await makeTask();
    final recentPhotos = FakeRecentPhotoLibrary(
      result: RecentPhotosLoaded([
        RecentPhotoAsset(id: 'a1', thumbnail: kFakeImageBytes, takenAtMillis: clock.nowEpochMillis()),
      ]),
      filePaths: {'a1': '/fake/library/a1.jpg'},
    );

    await pumpScreen(tester, task, recentPhotos: recentPhotos, verifierMode: DebugVerifierMode.reject);

    await tester.tap(find.byKey(const ValueKey('recent-photo-a1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photo-review-use')));
    await tester.pumpAndSettle();

    expect(find.text('Debug mode: reject'), findsOneWidget);
  });

  testWidgets('with no photo-library access, a single fallback button shows '
      'in place of an empty grid', (tester) async {
    final task = await makeTask();
    final recentPhotos = FakeRecentPhotoLibrary(result: const RecentPhotosUnavailable());

    await pumpScreen(tester, task, recentPhotos: recentPhotos);

    expect(find.byKey(const ValueKey('recent-photos-grid')), findsNothing);
    expect(find.byKey(const ValueKey('recent-photos-fallback-button')), findsOneWidget);
    expect(find.text('RECENT PHOTOS'), findsNothing);
  });

  testWidgets('a readable library with zero photos also falls back to the '
      'single button, not an empty grid', (tester) async {
    final task = await makeTask();
    final recentPhotos = FakeRecentPhotoLibrary(result: const RecentPhotosLoaded([]));

    await pumpScreen(tester, task, recentPhotos: recentPhotos);

    expect(find.byKey(const ValueKey('recent-photos-grid')), findsNothing);
    expect(find.byKey(const ValueKey('recent-photos-fallback-button')), findsOneWidget);
  });

  testWidgets(
      'the fallback button shows the Photo Review screen, and "Use this '
      'photo" opens the standard gallery picker path through to submit',
      (tester) async {
    final task = await makeTask();
    final recentPhotos = FakeRecentPhotoLibrary(result: const RecentPhotosUnavailable());

    await pumpScreen(tester, task, recentPhotos: recentPhotos);

    await tester.tap(find.byKey(const ValueKey('recent-photos-fallback-button')));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyResultScreen), findsNothing);
    expect(find.text('Choose another'), findsOneWidget);
    expect(await db.select(db.completions).get(), isEmpty);

    await tester.tap(find.byKey(const ValueKey('photo-review-use')));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyResultScreen), findsOneWidget);
  });

  testWidgets(
      '"Choose another" reopens the gallery picker (not a submit), including '
      'right after a recent-photo thumbnail tap', (tester) async {
    final task = await makeTask();
    final recentPhotos = FakeRecentPhotoLibrary(
      result: RecentPhotosLoaded([
        RecentPhotoAsset(id: 'a1', thumbnail: kFakeImageBytes, takenAtMillis: clock.nowEpochMillis()),
      ]),
      filePaths: {'a1': '/fake/library/a1.jpg'},
    );
    final capture = FakePhotoCapture(takenAtMillis: clock.nowEpochMillis());

    await pumpScreen(tester, task, recentPhotos: recentPhotos, photoCapture: capture);

    await tester.tap(find.byKey(const ValueKey('recent-photo-a1')));
    await tester.pumpAndSettle();
    expect(capture.callCount, 0); // no image_picker call yet - just the grid

    await tester.tap(find.byKey(const ValueKey('photo-review-secondary')));
    await tester.pumpAndSettle();

    expect(capture.callCount, 1); // the gallery picker was opened
    expect(find.byType(VerifyResultScreen), findsNothing);
    expect(find.text('Choose another'), findsOneWidget); // still reviewing
    expect(await db.select(db.completions).get(), isEmpty);
  });

  testWidgets("Open camera settings' calls the injected AppSettingsOpener",
      (tester) async {
    final task = await makeTask();
    final recentPhotos = FakeRecentPhotoLibrary(result: const RecentPhotosUnavailable());
    final settingsOpener = FakeAppSettingsOpener();

    await pumpScreen(tester, task, recentPhotos: recentPhotos, settingsOpener: settingsOpener);

    await tester.tap(find.text('Open camera settings'));
    await tester.pumpAndSettle();

    expect(settingsOpener.openCalls, 1);
  });
}
