import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/ui/new_habit/new_habit_screen.dart';
import 'package:cairn/src/ui/theme/app_text_styles.dart';
import 'package:cairn/src/ui/trail/trail_screen.dart';
import 'package:cairn/src/ui/widgets/cairn_stack.dart';
import 'package:cairn/src/ui/widgets/ghost_cairn.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// Wraps [testWidgets] with the same drift-stream-teardown fix-up
/// `home_screen_test.dart`/`profile_screen_test.dart` use: cancelling
/// [trailSnapshotProvider]'s `.watch()` subscription when the widget tree is
/// torn down schedules a zero-duration `Timer`, which `flutter_test`'s own
/// invariant check would otherwise flag as still-pending. See those files'
/// identical helper for the full rationale.
void testTrailWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}

/// True iff a [Text] widget with exactly [data] and [style] exists -
/// disambiguates same-string Text widgets that appear in different roles on
/// this screen (e.g. a selected task's title shows up both as the header
/// title and as its own chip label, each with a different style).
Finder findStyledText(String data, TextStyle style) {
  return find.byWidgetPredicate(
    (widget) => widget is Text && widget.data == data && widget.style == style,
  );
}

void main() {
  Widget wrap(Widget home) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  Future<AppDatabase> pumpTrail(
    WidgetTester tester,
    FixedClock clock,
    Future<void> Function(AppDatabase db) seed,
  ) async {
    final db = inMemoryDatabase();
    await seed(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
        ],
        child: wrap(const TrailScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  group('empty states', () {
    testTrailWidgets(
        'no active tasks at all shows the calm empty state with a New '
        'habit CTA', (tester) async {
      final db = await pumpTrail(tester, FixedClock(d(2026, 7, 20)), (db) async {});
      addTearDown(db.close);

      expect(find.text('Your first stone is waiting'), findsOneWidget);
      expect(
        find.text('Add a habit, prove it once, and watch your cairn begin to rise.'),
        findsOneWidget,
      );
      expect(find.text('New habit'), findsOneWidget);
      // No header/chips without any tasks.
      expect(find.text('TRAIL OF'), findsNothing);
    });

    testTrailWidgets(
        'a task with zero completions shows the gentle empty-trail state '
        'with a ghost cairn and the WHERE YOU STARTED marker', (tester) async {
      final clock = FixedClock(d(2026, 7, 20));
      final db = await pumpTrail(tester, clock, (db) async {
        final taskRepo = TaskRepository(db, clock);
        await taskRepo.createTask(
          title: 'Brand new habit',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );
      });
      addTearDown(db.close);

      expect(find.text('TRAIL OF'), findsOneWidget);
      expect(find.text('Brand new habit'), findsWidgets); // header + chip
      expect(
        find.text('Your first stone starts the trail.'),
        findsOneWidget,
      );
      expect(find.byType(GhostCairnStack), findsOneWidget);
      expect(find.text('WHERE YOU STARTED'), findsOneWidget);
      expect(find.byType(CairnStack), findsNothing);
    });
  });

  group('habit selector chips', () {
    testTrailWidgets(
        'chips render per task; the default-selected task is reflected in '
        'the header and its own chip styling', (tester) async {
      final clock = FixedClock(d(2026, 7, 20));
      final db = await pumpTrail(tester, clock, (db) async {
        final taskRepo = TaskRepository(db, clock);
        await taskRepo.createTask(
          title: 'Read 20 pages',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );
        await taskRepo.createTask(
          title: 'Morning workout',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );
      });
      addTearDown(db.close);

      // The first-created task ("Read 20 pages") is selected by default.
      expect(
        findStyledText('Read 20 pages', AppTextStyles.screenTitle),
        findsOneWidget,
      );
      expect(
        findStyledText('Read 20 pages', AppTextStyles.trailChipLabelSelected),
        findsOneWidget,
      );
      expect(
        findStyledText('Morning workout', AppTextStyles.trailChipLabelUnselected),
        findsOneWidget,
      );
      // Not shown as the header title or as a selected chip.
      expect(
        findStyledText('Morning workout', AppTextStyles.screenTitle),
        findsNothing,
      );
    });

    testTrailWidgets('tapping a chip switches the displayed trail', (tester) async {
      final clock = FixedClock(d(2026, 7, 20));
      final db = await pumpTrail(tester, clock, (db) async {
        final taskRepo = TaskRepository(db, clock);
        await taskRepo.createTask(
          title: 'Read 20 pages',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );
        await taskRepo.createTask(
          title: 'Morning workout',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );
      });
      addTearDown(db.close);

      // Unambiguous before the tap: only the (unselected) chip shows this
      // text yet, so a plain find.text/tap is safe here.
      await tester.tap(find.text('Morning workout'));
      await tester.pumpAndSettle();

      expect(
        findStyledText('Morning workout', AppTextStyles.screenTitle),
        findsOneWidget,
      );
      expect(
        findStyledText('Morning workout', AppTextStyles.trailChipLabelSelected),
        findsOneWidget,
      );
      expect(
        findStyledText('Read 20 pages', AppTextStyles.trailChipLabelUnselected),
        findsOneWidget,
      );
    });

    testTrailWidgets(
        'the trailing "+" chip navigates to the New Habit screen', (tester) async {
      final clock = FixedClock(d(2026, 7, 20));
      final db = await pumpTrail(tester, clock, (db) async {
        final taskRepo = TaskRepository(db, clock);
        await taskRepo.createTask(
          title: 'Read 20 pages',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );
      });
      addTearDown(db.close);

      // The dashed "+" chip's own on-screen glyph is a literal "+" (its
      // accessible label is 'New habit', but semantics matching needs a
      // live SemanticsHandle this test doesn't otherwise need); the "+" is
      // unique on screen.
      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();

      expect(find.byType(NewHabitScreen), findsOneWidget);
    });
  });

  group('cairn history rendering', () {
    testTrailWidgets(
        'a history spanning a capped, a broken and a growing cairn renders '
        'all three treatments plus the trailhead and WHERE YOU STARTED '
        'markers', (tester) async {
      final db = await pumpTrail(tester, FixedClock(d(2026, 7, 20)), (db) async {
        final seedTaskRepo = TaskRepository(db, FixedClock(d(2026, 7, 1)));
        final task = await seedTaskRepo.createTask(
          title: 'Read 20 pages',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );

        final stoneDays = [
          for (var day = 1; day <= 10; day++) day,
          for (var day = 12; day <= 14; day++) day,
          for (var day = 16; day <= 19; day++) day,
        ];
        for (final day in stoneDays) {
          final repo = CompletionRepository(db, FixedClock(d(2026, 7, day)),
              verifier: FakeProofVerifier());
          await repo.completeOccurrence(
            taskId: task.id,
            occurrenceDate: d(2026, 7, day),
          );
        }
      });
      addTearDown(db.close);

      expect(find.text('GROWING NOW'), findsOneWidget);
      // Cairn 1 (days 1-10) is both capped AND the trailhead here (it's the
      // very first cairn), and the trailhead caption replaces the usual
      // "N stones · capped" wording (see _SettledCairnNode's doc comment) -
      // so "10 stones · capped" itself never renders in this scenario.
      expect(find.text('10 stones · capped'), findsNothing);
      expect(find.text('The trailhead · Jul 1'), findsOneWidget);
      expect(find.text('broken · 3 stones'), findsOneWidget);
      expect(find.text('WHERE YOU STARTED'), findsOneWidget);
      // One CairnStack per cairn (growing 4, capped 10, broken 3): none of
      // this history's cairns has zero stones, so no GhostCairnStack.
      expect(find.byType(CairnStack), findsNWidgets(3));
      expect(find.byType(GhostCairnStack), findsNothing);
    });
  });
}
