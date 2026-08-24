import 'dart:typed_data';

import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/local_date.dart';
import 'package:cairn/src/models/proof_verdict.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/home_service.dart';
import 'package:cairn/src/services/occurrence_generator.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/services/streak_service.dart';
import 'package:cairn/src/widgets/widget_snapshot.dart';
import 'package:cairn/src/widgets/widget_trigger.dart';
import 'package:cairn/src/widgets/widget_updater.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late TaskRepository taskRepo;
  late CompletionRepository completionRepo;
  late HomeService homeService;
  late StreakService streakService;
  late FakeWidgetUpdater updater;
  late WidgetTrigger trigger;

  const testToday = LocalDate(2026, 8, 24);

  setUp(() {
    db = inMemoryDatabase();
    clock = FixedClock(testToday);
    taskRepo = TaskRepository(db, clock);
    completionRepo =
        CompletionRepository(db, clock, verifier: FakeProofVerifier());
    homeService = HomeService(
      db,
      taskRepo,
      completionRepo,
      const OccurrenceGenerator(),
      clock,
    );
    streakService = const StreakService();
    updater = FakeWidgetUpdater();

    trigger = WidgetTrigger(
      updater: updater,
      homeService: homeService,
      completionRepo: completionRepo,
      streakService: streakService,
      taskRepo: taskRepo,
      clock: clock,
    );
  });

  tearDown(() async {
    trigger.dispose();
    updater.dispose();
    await db.close();
  });

  group('WidgetSnapshot', () {
    test('serializes to Map correctly', () {
      const snapshot = WidgetSnapshot(
        remainingCount: 2,
        totalCount: 3,
        activeStreak: 5,
        altitude: 150,
        nextTaskId: 'task-1',
        nextTaskTitle: 'Read 20 pages',
        nextTaskSlot: 0,
        nextTaskDueTime: '09:00',
        nextTaskCairnLabel: 'Cairn 1 · 2 stones',
        isAllCompleted: false,
      );

      final map = snapshot.toWidgetData();
      expect(map['remaining_count'], 2);
      expect(map['total_count'], 3);
      expect(map['active_streak'], 5);
      expect(map['altitude'], 150);
      expect(map['next_task_id'], 'task-1');
      expect(map['next_task_title'], 'Read 20 pages');
      expect(map['next_task_slot'], 0);
      expect(map['next_task_due_time'], '09:00');
      expect(map['next_task_cairn_label'], 'Cairn 1 · 2 stones');
      expect(map['is_all_completed'], false);
    });

    test('equality and hashCode match identical fields', () {
      const s1 = WidgetSnapshot(
        remainingCount: 1,
        totalCount: 1,
        activeStreak: 3,
        altitude: 50,
      );
      const s2 = WidgetSnapshot(
        remainingCount: 1,
        totalCount: 1,
        activeStreak: 3,
        altitude: 50,
      );
      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
    });
  });

  group('WidgetTrigger', () {
    test('updates snapshot when tasks exist and completes', () async {
      trigger.start();

      // Create a daily task
      await taskRepo.createTask(
        title: 'Morning Yoga',
        recurrenceType: RecurrenceType.daily,
        startDate: testToday,
        dueTimes: ['07:00'],
      );

      // Wait for stream event to propagate
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(updater.snapshots.isNotEmpty, isTrue);
      final latest = updater.latestSnapshot!;
      expect(latest.totalCount, 1);
      expect(latest.remainingCount, 1);
      expect(latest.isAllCompleted, false);
      expect(latest.nextTaskTitle, 'Morning Yoga');
      expect(latest.nextTaskDueTime, '07:00');
    });

    test('reflects completed state and altitude when habit is proven',
        () async {
      trigger.start();

      final task = await taskRepo.createTask(
        title: 'Drink Water',
        recurrenceType: RecurrenceType.daily,
        startDate: testToday,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(updater.latestSnapshot?.remainingCount, 1);
      expect(updater.latestSnapshot?.isAllCompleted, false);

      // Complete the task
      final proof = ProofData(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        photoPath: '/tmp/photo.jpg',
        source: ProofSource.camera,
        photoTakenAt: clock.nowEpochMillis(),
      );
      await completionRepo.completeWithProof(
        taskId: task.id,
        occurrenceDate: testToday,
        proof: proof,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final updated = updater.latestSnapshot!;
      expect(updated.totalCount, 1);
      expect(updated.remainingCount, 0);
      expect(updated.isAllCompleted, isTrue);
      expect(updated.altitude, greaterThan(0));
    });
  });
}
