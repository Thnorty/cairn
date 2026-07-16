import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/local_date.dart';
import 'package:cairn/src/services/cairn_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Builds a live (non-tombstoned) completion row directly: cairn grouping is
/// pure and only reads occurrenceDate/slot from these, so the rest of the
/// fields are inert placeholders.
Completion stone(String taskId, LocalDate date, {int slot = 0}) {
  return Completion(
    id: 'c-$taskId-${date.toIso()}-$slot',
    taskId: taskId,
    occurrenceDate: date,
    slot: slot,
    completedAt: 0,
    verificationStatus: VerificationStatus.verified,
    pointsAwarded: 0,
    updatedAt: 0,
  );
}

void main() {
  const grouping = CairnGrouping();

  group('cairnsFor', () {
    test('empty history returns an empty list', () {
      final task = makeTask(startDate: d(2026, 7, 1));
      final cairns = grouping.cairnsFor(
        task: task,
        today: d(2026, 7, 1),
        liveCompletions: const [],
      );
      expect(cairns, isEmpty);
    });

    test('a single stone forms one growing, trailhead cairn', () {
      final task = makeTask(startDate: d(2026, 7, 1));
      final cairns = grouping.cairnsFor(
        task: task,
        today: d(2026, 7, 1),
        liveCompletions: [stone(task.id, d(2026, 7, 1))],
      );

      expect(cairns, hasLength(1));
      expect(cairns.single.index, 1);
      expect(cairns.single.isTrailhead, isTrue);
      expect(cairns.single.stoneCount, 1);
      expect(cairns.single.status, CairnStatus.growing);
      expect(cairns.single.firstStoneDate, d(2026, 7, 1));
      expect(cairns.single.lastStoneDate, d(2026, 7, 1));
    });

    test(
        'exactly capStones consecutive stones with an alive streak caps and '
        'starts a fresh empty growing cairn', () {
      final task = makeTask(startDate: d(2026, 7, 1));
      final completions = [
        for (var day = 1; day <= 10; day++) stone(task.id, d(2026, 7, day)),
      ];
      final cairns = grouping.cairnsFor(
        task: task,
        today: d(2026, 7, 10),
        liveCompletions: completions,
      );

      expect(cairns, hasLength(2));
      expect(cairns[0].index, 1);
      expect(cairns[0].isTrailhead, isTrue);
      expect(cairns[0].stoneCount, 10);
      expect(cairns[0].status, CairnStatus.capped);
      expect(cairns[0].firstStoneDate, d(2026, 7, 1));
      expect(cairns[0].lastStoneDate, d(2026, 7, 10));

      expect(cairns[1].index, 2);
      expect(cairns[1].isTrailhead, isFalse);
      expect(cairns[1].stoneCount, 0);
      expect(cairns[1].status, CairnStatus.growing);
      expect(cairns[1].firstStoneDate, isNull);
      expect(cairns[1].lastStoneDate, isNull);
    });

    test(
        'capStones stones then a broken streak yields only the capped '
        'cairn, with no empty broken remnant', () {
      final task = makeTask(startDate: d(2026, 7, 1));
      final completions = [
        for (var day = 1; day <= 10; day++) stone(task.id, d(2026, 7, day)),
      ];
      // Jul 11 is scheduled (daily), elapsed and left incomplete: a break.
      final cairns = grouping.cairnsFor(
        task: task,
        today: d(2026, 7, 12),
        liveCompletions: completions,
      );

      expect(cairns, hasLength(1));
      expect(cairns.single.index, 1);
      expect(cairns.single.isTrailhead, isTrue);
      expect(cairns.single.stoneCount, 10);
      expect(cairns.single.status, CairnStatus.capped);
      expect(cairns.single.firstStoneDate, d(2026, 7, 1));
      expect(cairns.single.lastStoneDate, d(2026, 7, 10));
    });

    test('13 stones with an alive streak yields capped 10 + growing 3', () {
      final task = makeTask(startDate: d(2026, 7, 1));
      final completions = [
        for (var day = 1; day <= 13; day++) stone(task.id, d(2026, 7, day)),
      ];
      final cairns = grouping.cairnsFor(
        task: task,
        today: d(2026, 7, 13),
        liveCompletions: completions,
      );

      expect(cairns, hasLength(2));
      expect(cairns[0].stoneCount, 10);
      expect(cairns[0].status, CairnStatus.capped);
      expect(cairns[0].isTrailhead, isTrue);
      expect(cairns[1].stoneCount, 3);
      expect(cairns[1].status, CairnStatus.growing);
      expect(cairns[1].firstStoneDate, d(2026, 7, 11));
      expect(cairns[1].lastStoneDate, d(2026, 7, 13));
    });

    test('13 stones then a broken streak yields capped 10 + broken 3', () {
      final task = makeTask(startDate: d(2026, 7, 1));
      final completions = [
        for (var day = 1; day <= 13; day++) stone(task.id, d(2026, 7, day)),
      ];
      // Jul 14 is scheduled, elapsed and left incomplete: a break.
      final cairns = grouping.cairnsFor(
        task: task,
        today: d(2026, 7, 15),
        liveCompletions: completions,
      );

      expect(cairns, hasLength(2));
      expect(cairns[0].stoneCount, 10);
      expect(cairns[0].status, CairnStatus.capped);
      expect(cairns[1].stoneCount, 3);
      expect(cairns[1].status, CairnStatus.broken);
      expect(cairns[1].firstStoneDate, d(2026, 7, 11));
      expect(cairns[1].lastStoneDate, d(2026, 7, 13));
    });

    test(
        'two runs separated by a break produce capped/broken/growing in '
        'order, with correct 1..N indices and the trailhead flag only on 1',
        () {
      final task = makeTask(startDate: d(2026, 7, 1));
      // Run 1: Jul 1-4 (4 stones). Jul 5 elapsed and incomplete: a break.
      // Run 2: Jul 6 (1 stone), today, streak still alive.
      final completions = [
        for (var day = 1; day <= 4; day++) stone(task.id, d(2026, 7, day)),
        stone(task.id, d(2026, 7, 6)),
      ];
      final cairns = grouping.cairnsFor(
        task: task,
        today: d(2026, 7, 6),
        liveCompletions: completions,
        capStones: 3,
      );

      expect(cairns, hasLength(3));

      expect(cairns[0].index, 1);
      expect(cairns[0].isTrailhead, isTrue);
      expect(cairns[0].stoneCount, 3);
      expect(cairns[0].status, CairnStatus.capped);
      expect(cairns[0].firstStoneDate, d(2026, 7, 1));
      expect(cairns[0].lastStoneDate, d(2026, 7, 3));

      expect(cairns[1].index, 2);
      expect(cairns[1].isTrailhead, isFalse);
      expect(cairns[1].stoneCount, 1);
      expect(cairns[1].status, CairnStatus.broken);
      expect(cairns[1].firstStoneDate, d(2026, 7, 4));
      expect(cairns[1].lastStoneDate, d(2026, 7, 4));

      expect(cairns[2].index, 3);
      expect(cairns[2].isTrailhead, isFalse);
      expect(cairns[2].stoneCount, 1);
      expect(cairns[2].status, CairnStatus.growing);
      expect(cairns[2].firstStoneDate, d(2026, 7, 6));
      expect(cairns[2].lastStoneDate, d(2026, 7, 6));
    });

    test(
        'a multi-slot partial day (one slot done, one missed, fully '
        'elapsed) is a break, and its lone stone stays in the run the '
        'break terminates', () {
      final task = makeTask(
        dueTimes: const ['08:00', '20:00'],
        startDate: d(2026, 7, 1),
      );
      // Jul 1: both slots done. Jul 2: only slot 0 done (partial, a break
      // once elapsed). No stone after Jul 2.
      final completions = [
        stone(task.id, d(2026, 7, 1), slot: 0),
        stone(task.id, d(2026, 7, 1), slot: 1),
        stone(task.id, d(2026, 7, 2), slot: 0),
      ];
      final cairns = grouping.cairnsFor(
        task: task,
        today: d(2026, 7, 3),
        liveCompletions: completions,
        capStones: 3,
      );

      // If the Jul-2 stone were wrongly bumped into a new run instead of
      // staying in the run the break terminates, this would come back as
      // broken(2) + growing(1) instead of a single capped(3) + growing(0).
      expect(cairns, hasLength(2));
      expect(cairns[0].stoneCount, 3);
      expect(cairns[0].status, CairnStatus.capped);
      expect(cairns[0].firstStoneDate, d(2026, 7, 1));
      expect(cairns[0].lastStoneDate, d(2026, 7, 2));
      expect(cairns[1].stoneCount, 0);
      expect(cairns[1].status, CairnStatus.growing);
    });

    test('non-scheduled dates between stones are not breaks', () {
      // Mon/Wed/Fri task: Tue/Thu/weekend are never scheduled, so they can
      // never register as a break even though they sit between stones.
      final task = makeTask(
        recurrenceType: RecurrenceType.weekly,
        weeklyDays: const [1, 3, 5],
        startDate: d(2026, 7, 6), // Monday
      );
      final completions = [
        stone(task.id, d(2026, 7, 6)), // Mon
        stone(task.id, d(2026, 7, 8)), // Wed
        stone(task.id, d(2026, 7, 10)), // Fri
      ];
      final cairns = grouping.cairnsFor(
        task: task,
        today: d(2026, 7, 10),
        liveCompletions: completions,
      );

      expect(cairns, hasLength(1));
      expect(cairns.single.stoneCount, 3);
      expect(cairns.single.status, CairnStatus.growing);
      expect(cairns.single.isTrailhead, isTrue);
      expect(cairns.single.firstStoneDate, d(2026, 7, 6));
      expect(cairns.single.lastStoneDate, d(2026, 7, 10));
    });
  });

  group('growingCairnStoneCount', () {
    test('zero for an empty history', () {
      final task = makeTask(startDate: d(2026, 7, 1));
      expect(
        grouping.growingCairnStoneCount(
          task: task,
          today: d(2026, 7, 1),
          liveCompletions: const [],
        ),
        0,
      );
    });

    test('reflects the in-progress cairn while the streak is alive', () {
      final task = makeTask(startDate: d(2026, 7, 1));
      final completions = [
        for (var day = 1; day <= 3; day++) stone(task.id, d(2026, 7, day)),
      ];
      expect(
        grouping.growingCairnStoneCount(
          task: task,
          today: d(2026, 7, 3),
          liveCompletions: completions,
        ),
        3,
      );
    });

    test('zero right after a cairn caps (streak alive, fresh cairn empty)',
        () {
      final task = makeTask(startDate: d(2026, 7, 1));
      final completions = [
        for (var day = 1; day <= 10; day++) stone(task.id, d(2026, 7, day)),
      ];
      expect(
        grouping.growingCairnStoneCount(
          task: task,
          today: d(2026, 7, 10),
          liveCompletions: completions,
        ),
        0,
      );
    });

    test('zero once the streak has broken (no growing cairn at all)', () {
      final task = makeTask(startDate: d(2026, 7, 1));
      final completions = [
        for (var day = 1; day <= 3; day++) stone(task.id, d(2026, 7, day)),
      ];
      // Jul 4 elapsed and incomplete: the streak is broken.
      expect(
        grouping.growingCairnStoneCount(
          task: task,
          today: d(2026, 7, 5),
          liveCompletions: completions,
        ),
        0,
      );
    });
  });
}
