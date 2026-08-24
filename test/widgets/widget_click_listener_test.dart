import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/ui/new_habit/new_habit_screen.dart';
import 'package:cairn/src/ui/premium/premium_screen.dart';
import 'package:cairn/src/ui/proof/camera_capture_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fake_camera_session.dart';
import '../support/fake_recent_photos.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late TaskRepository taskRepo;
  late FakeWidgetUpdater updater;

  setUp(() {
    db = inMemoryDatabase();
    clock = FixedClock(d(2026, 7, 10));
    taskRepo = TaskRepository(db, clock);
    updater = FakeWidgetUpdater();
  });

  tearDown(() async {
    updater.dispose();
    await db.close();
  });

  Future<void> pumpListener(
    WidgetTester tester, {
    FakeWidgetUpdater? customUpdater,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          widgetUpdaterProvider.overrideWithValue(customUpdater ?? updater),
          cameraSessionFactoryProvider
              .overrideWithValue(() => FakeCameraSession()),
          recentPhotoLibraryProvider
              .overrideWithValue(FakeRecentPhotoLibrary()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: WidgetClickListener(
              child: Text('App Shell Placeholder'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('widget click with cairn://prove opens CameraCaptureScreen',
      (tester) async {
    final task = await taskRepo.createTask(
      title: 'Morning Yoga',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    await pumpListener(tester);

    expect(find.byType(CameraCaptureScreen), findsNothing);

    updater.emitClick(Uri.parse('cairn://prove?taskId=${task.id}&slot=0'));
    await tester.pumpAndSettle();

    expect(find.byType(CameraCaptureScreen), findsOneWidget);
  });

  testWidgets('initial launch from widget opens CameraCaptureScreen',
      (tester) async {
    final task = await taskRepo.createTask(
      title: 'Morning Yoga',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    final initialUpdater = FakeWidgetUpdater(
      initialUri: Uri.parse('cairn://prove?taskId=${task.id}&slot=0'),
    );

    await pumpListener(tester, customUpdater: initialUpdater);

    expect(find.byType(CameraCaptureScreen), findsOneWidget);
  });

  testWidgets('widget click with cairn://new_habit opens NewHabitScreen',
      (tester) async {
    await pumpListener(tester);

    updater.emitClick(Uri.parse('cairn://new_habit'));
    await tester.pumpAndSettle();

    expect(find.byType(NewHabitScreen), findsOneWidget);
  });

  testWidgets('widget click with cairn://premium opens PremiumScreen',
      (tester) async {
    await pumpListener(tester);

    updater.emitClick(Uri.parse('cairn://premium'));
    await tester.pumpAndSettle();

    expect(find.byType(PremiumScreen), findsOneWidget);
  });
}
