import 'dart:typed_data';

import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/proof_verdict.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/home_service.dart';
import 'package:cairn/src/services/occurrence_generator.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Builds a local wall-clock instant on this same process/timezone: reading
/// it back later with `DateTime.fromMillisecondsSinceEpoch` (also local,
/// never UTC) round-trips to the same y/m/d/h/m regardless of which
/// timezone the test machine itself is in, since both conversions happen in
/// the same process. See [FixedClock]'s doc comment: its default
/// `nowMillis` is UTC midnight of `today`, which is fine when only the date
/// matters, but these tests care about time-of-day too, so they always pass
/// an explicit `nowMillis` built this way.
int _localMillis(int y, int m, int d, int hh, int mm) =>
    DateTime(y, m, d, hh, mm).millisecondsSinceEpoch;

void main() {
  group('isOccurrenceDueBy', () {
    test('an untimed occurrence is always due', () {
      final now = DateTime(2026, 7, 10, 0, 0);
      expect(isOccurrenceDueBy(null, now), isTrue);
    });

    test('is not due before its due time', () {
      final now = DateTime(2026, 7, 10, 7, 59);
      expect(isOccurrenceDueBy('08:00', now), isFalse);
    });

    test('is due exactly at its due time (inclusive boundary)', () {
      final now = DateTime(2026, 7, 10, 8, 0);
      expect(isOccurrenceDueBy('08:00', now), isTrue);
    });

    test('is due after its due time', () {
      final now = DateTime(2026, 7, 10, 20, 1);
      expect(isOccurrenceDueBy('20:00', now), isTrue);
    });
  });

  group('HomeService', () {
    late AppDatabase db;

    setUp(() {
      db = inMemoryDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    HomeService makeService(Clock clock) {
      return HomeService(
        db,
        TaskRepository(db, clock),
        CompletionRepository(db, clock, verifier: FakeProofVerifier()),
        const OccurrenceGenerator(),
        clock,
      );
    }

    test('no active tasks reports zero everything, no cards', () async {
      final clock = FixedClock(d(2026, 7, 10));
      final service = makeService(clock);

      final snapshot = await service.buildSnapshot();

      expect(snapshot.activeTaskCount, 0);
      expect(snapshot.doneCount, 0);
      expect(snapshot.totalCount, 0);
      expect(snapshot.stonesThisWeek, 0);
      expect(snapshot.cards, isEmpty);
    });

    test('a due (untimed) occurrence with no completion is DUE', () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final snapshot = await makeService(clock).buildSnapshot();

      expect(snapshot.activeTaskCount, 1);
      expect(snapshot.totalCount, 1);
      expect(snapshot.doneCount, 0);
      final card = snapshot.cards.single;
      expect(card.status, HomeCardStatus.due);
      expect(card.dueTime, isNull);
      expect(card.stoneCount, 0);
      expect(card.cairnNumber, 1);
      expect(card.completion, isNull);
    });

    test('a timed occurrence not yet due is SCHEDULED', () async {
      final clock = FixedClock(
        d(2026, 7, 10),
        nowMillis: _localMillis(2026, 7, 10, 7, 0),
      );
      final taskRepo = TaskRepository(db, clock);
      await taskRepo.createTask(
        title: 'Water the plants',
        recurrenceType: RecurrenceType.daily,
        dueTimes: const ['20:00'],
        startDate: d(2026, 7, 1),
      );

      final snapshot = await makeService(clock).buildSnapshot();

      final card = snapshot.cards.single;
      expect(card.status, HomeCardStatus.scheduled);
      expect(card.dueTime, '20:00');
    });

    test('a completed occurrence with a verified completion is VERIFIED',
        () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo =
          CompletionRepository(db, clock, verifier: FakeProofVerifier());
      final task = await taskRepo.createTask(
        title: 'Morning workout',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );

      final snapshot = await makeService(clock).buildSnapshot();

      expect(snapshot.doneCount, 1);
      expect(snapshot.totalCount, 1);
      final card = snapshot.cards.single;
      expect(card.status, HomeCardStatus.verified);
      expect(card.completion, isNotNull);
      expect(card.stoneCount, 1);
    });

    test(
        'a pending completion is AWAITING_VERIFICATION and still counts as '
        'done and toward the stone count', () async {
      final clock = FixedClock(d(2026, 7, 10));
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

      final snapshot = await makeService(clock).buildSnapshot();

      expect(snapshot.doneCount, 1);
      final card = snapshot.cards.single;
      expect(card.status, HomeCardStatus.awaitingVerification);
      expect(card.completion!.verificationStatus, VerificationStatus.pending);
      expect(card.stoneCount, 1);
    });

    test('a task with two due times produces two cards in slot order',
        () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      await taskRepo.createTask(
        title: 'Meds',
        recurrenceType: RecurrenceType.daily,
        dueTimes: const ['08:00', '20:00'],
        startDate: d(2026, 7, 1),
      );

      final snapshot = await makeService(clock).buildSnapshot();

      expect(snapshot.cards, hasLength(2));
      expect(snapshot.cards[0].slot, 0);
      expect(snapshot.cards[0].dueTime, '08:00');
      expect(snapshot.cards[1].slot, 1);
      expect(snapshot.cards[1].dueTime, '20:00');
    });

    test("cards are ordered by the owning task's cairn number", () async {
      final clock = FixedClock(d(2026, 7, 10));
      // Distinct nowMillis per creation (same LocalDate, later wall-clock
      // instant), the way two real user taps a moment apart would land: this
      // is what makes created_at, not the random tail of a same-millisecond
      // UUID v7 id, decide the ordering under test.
      final baseMillis = clock.nowEpochMillis();
      final taskB = await TaskRepository(
        db,
        FixedClock(d(2026, 7, 10), nowMillis: baseMillis),
      ).createTask(
        title: 'B (created first)',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final taskA = await TaskRepository(
        db,
        FixedClock(d(2026, 7, 10), nowMillis: baseMillis + 1000),
      ).createTask(
        title: 'A (created second)',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final snapshot = await makeService(clock).buildSnapshot();

      expect(snapshot.cards, hasLength(2));
      expect(snapshot.cards[0].taskId, taskB.id);
      expect(snapshot.cards[0].cairnNumber, 1);
      expect(snapshot.cards[1].taskId, taskA.id);
      expect(snapshot.cards[1].cairnNumber, 2);
    });

    test('stonesThisWeek reflects completionsCountForWeekOf(today)',
        () async {
      final clock = FixedClock(d(2026, 7, 8)); // a Wednesday
      final taskRepo = TaskRepository(db, clock);
      final completionRepo =
          CompletionRepository(db, clock, verifier: FakeProofVerifier());
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      for (final day in [6, 7, 8]) {
        final dayClock = FixedClock(d(2026, 7, day));
        await CompletionRepository(db, dayClock, verifier: FakeProofVerifier())
            .completeOccurrence(
                taskId: task.id, occurrenceDate: d(2026, 7, day));
      }
      // Sanity check via the repository directly too.
      expect(await completionRepo.completionsCountForWeekOf(d(2026, 7, 8)), 3);

      final snapshot = await makeService(clock).buildSnapshot();
      expect(snapshot.stonesThisWeek, 3);
    });

    test('watchToday emits an initial snapshot and again after a write',
        () async {
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo =
          CompletionRepository(db, clock, verifier: FakeProofVerifier());
      final service = HomeService(
        db,
        taskRepo,
        completionRepo,
        const OccurrenceGenerator(),
        clock,
      );

      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final events = <HomeSnapshot>[];
      final subscription = service.watchToday().listen(events.add);
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      expect(events, hasLength(1));
      expect(events.single.cards.single.status, HomeCardStatus.due);

      await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      await pumpEventQueue();

      expect(events.length, greaterThanOrEqualTo(2));
      expect(events.last.cards.single.status, HomeCardStatus.verified);
      expect(events.last.doneCount, 1);
    });
  });
}
