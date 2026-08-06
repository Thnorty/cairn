import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/local_date.dart';
import 'package:cairn/src/notifications/notification_scheduler.dart';
import 'package:cairn/src/notifications/pending_notification.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/ui/proof/camera_capture_screen.dart';
import 'package:cairn/src/ui/shell/notification_tap_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';
import '../../support/fake_camera_session.dart';
import '../../support/fake_notification_scheduler.dart';
import '../../support/fake_recent_photos.dart';

/// Tests for the tap-to-camera route promised by
/// `Cairn Onboarding Notifications.dc.html` ("Tap it to go straight to the
/// camera").
///
/// Uses a plain placeholder child rather than the real `AppShell`, so these
/// assert only on the routing decision: which taps open the camera and which
/// are dropped. Everything past `CameraCaptureScreen` is
/// `camera_capture_screen_test.dart`'s territory.
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late TaskRepository taskRepo;
  late FakeNotificationScheduler scheduler;

  setUp(() {
    db = inMemoryDatabase();
    clock = FixedClock(d(2026, 7, 10));
    taskRepo = TaskRepository(db, clock);
    scheduler = FakeNotificationScheduler();
  });

  tearDown(() async {
    await scheduler.dispose();
    await db.close();
  });

  Future<Task> makeTask() => taskRepo.createTask(
        title: 'Read 20 pages',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

  Future<void> pumpListener(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          notificationSchedulerProvider.overrideWithValue(scheduler),
          // The camera screen the route lands on is plugin-backed; a fake
          // session keeps this test off `camera`'s platform channel.
          cameraSessionFactoryProvider
              .overrideWithValue(() => FakeCameraSession()),
          recentPhotoLibraryProvider.overrideWithValue(FakeRecentPhotoLibrary()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NotificationTapListener(
            child: Scaffold(body: Text('shell')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The drift `.watch()` subscriptions this tree opens leave a pending
  /// zero-duration timer when disposed; see
  /// `test/ui/settings/notifications_screen_test.dart`'s identical helper.
  Future<void> drain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  testWidgets('a tap for one of today\'s occurrences opens the camera for it',
      (tester) async {
    final task = await makeTask();
    await pumpListener(tester);
    expect(find.byType(CameraCaptureScreen), findsNothing);

    scheduler.emitTap(NotificationPayload(
      taskId: task.id,
      occurrenceDate: clock.today(),
      slot: 0,
    ));
    await tester.pumpAndSettle();

    final screen = tester.widget<CameraCaptureScreen>(
      find.byType(CameraCaptureScreen),
    );
    expect(screen.taskId, task.id);
    expect(screen.taskTitle, 'Read 20 pages');
    expect(screen.slot, 0);
    expect(screen.occurrenceDate, clock.today());

    await drain(tester);
  });

  testWidgets(
      'a tap that cold-started the app is replayed to the listener and routes '
      'the same way', (tester) async {
    final task = await makeTask();
    // Set BEFORE the listener subscribes, exactly as the real scheduler
    // observes a launch tap during its own initialization.
    scheduler.presetLaunchTap(NotificationPayload(
      taskId: task.id,
      occurrenceDate: clock.today(),
      slot: 0,
    ));

    await pumpListener(tester);

    expect(find.byType(CameraCaptureScreen), findsOneWidget);

    await drain(tester);
  });

  testWidgets(
      'a tap naming a past occurrence is dropped silently, never surfacing '
      'the untranslated back-fill safety net', (tester) async {
    final task = await makeTask();
    await pumpListener(tester);

    // Yesterday: the phone was on silent overnight and the reminder was only
    // tapped this morning. Back-filling is forbidden, so there is nothing
    // honest to open.
    scheduler.emitTap(NotificationPayload(
      taskId: task.id,
      occurrenceDate: const LocalDate(2026, 7, 9),
      slot: 0,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(CameraCaptureScreen), findsNothing);
    expect(find.text('Cannot complete a past date'), findsNothing);
    expect(find.text('shell'), findsOneWidget);

    await drain(tester);
  });

  testWidgets('a tap for a task deleted since it was scheduled is dropped',
      (tester) async {
    final task = await makeTask();
    await taskRepo.tombstoneDelete(task.id);
    await pumpListener(tester);

    scheduler.emitTap(NotificationPayload(
      taskId: task.id,
      occurrenceDate: clock.today(),
      slot: 0,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(CameraCaptureScreen), findsNothing);
    expect(find.text('Task not found'), findsNothing);

    await drain(tester);
  });

  testWidgets('an archived task\'s reminder is dropped too', (tester) async {
    final task = await makeTask();
    await taskRepo.archiveTask(task.id);
    await pumpListener(tester);

    scheduler.emitTap(NotificationPayload(
      taskId: task.id,
      occurrenceDate: clock.today(),
      slot: 0,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(CameraCaptureScreen), findsNothing);

    await drain(tester);
  });

  test('UnconfiguredNotificationScheduler yields no taps, so the listener is '
      'inert on platforms without notification support', () async {
    const inert = UnconfiguredNotificationScheduler();
    expect(await inert.taps.toList(), isEmpty);
  });
}
