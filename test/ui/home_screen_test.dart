import 'dart:typed_data';

import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/l10n/date_number_formatting.dart';
import 'package:cairn/src/models/proof_verdict.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/photo_capture.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/ui/home/home_occurrence_card.dart';
import 'package:cairn/src/ui/home/home_screen.dart';
import 'package:cairn/src/ui/widgets/buttons.dart';
import 'package:cairn/src/ui/widgets/ghost_cairn.dart';
import 'package:cairn/src/ui/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Local wall-clock instant on this same process/timezone; see
/// `home_service_test.dart`'s identical helper for why.
int _localMillis(int y, int m, int d, int hh, int mm) =>
    DateTime(y, m, d, hh, mm).millisecondsSinceEpoch;

class _FakePhotoCapture implements PhotoCapture {
  final int? takenAtMillis;
  _FakePhotoCapture({this.takenAtMillis});

  @override
  Future<CapturedPhoto?> capture(ProofSource source) async {
    return CapturedPhoto(
      tempPath: '/fake/path.jpg',
      source: source,
      takenAtMillis: takenAtMillis,
    );
  }
}

class _FakeImageCompressor implements ImageCompressor {
  @override
  Future<Uint8List> compress(String path) async => Uint8List.fromList([1, 2, 3]);
}

class _FakeProofPhotoStore implements ProofPhotoStore {
  @override
  Future<String> save(Uint8List bytes) async => '/fake/saved.jpg';

  @override
  Future<Uint8List?> load(String path) async => Uint8List.fromList([1, 2, 3]);

  @override
  Future<void> delete(String path) async {}
}

/// Wraps [testWidgets] with a fix-up for a drift + flutter_test
/// interaction: cancelling a `.watch()` stream subscription - which happens
/// when the widget tree (and with it [homeSnapshotProvider]'s
/// `ProviderScope`) is torn down - schedules a zero-duration `Timer` (see
/// drift's `QueryStream._onCancelOrPause`). In the running app that's
/// harmless (it fires on the very next frame); `flutter_test`'s own
/// `_verifyInvariants` check runs immediately once the test body returns,
/// before any further pump, so without this every test that pumps a
/// [HomeScreen] fails with "A Timer is still pending even after the widget
/// tree was disposed." Replacing the tree with something trivial (which
/// unmounts the `ProviderScope` and schedules the timer) and pumping once
/// more (letting it fire) runs that disposal while the test can still pump
/// afterward, instead of leaving it to the framework's own automatic
/// end-of-test teardown, which gets no such extra pump.
void testHomeWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    // `tester.pump()` with no argument never elapses flutter_test's fake
    // clock (see AutomatedTestWidgetsFlutterBinding.pump: it only calls
    // `_currentFakeAsync!.elapse(duration)` when `duration != null`), so it
    // flushes microtasks but never actually fires a pending `Timer`, zero-
    // duration or not. Passing `Duration.zero` explicitly still elapses
    // (by zero), which is what lets the timer above actually fire.
    await tester.pump(Duration.zero);
  });
}

void main() {
  Widget wrap(Widget home) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  group('Empty Today', () {
    testHomeWidgets('renders the empty state when there are no tasks at all', (
      tester,
    ) async {
      final db = await pumpHomeWithSeed(
        tester,
        FixedClock(d(2026, 7, 1)),
        (db) async {},
      );
      addTearDown(db.close);

      expect(find.text('Your first stone is waiting'), findsOneWidget);
      expect(
        find.text('Add a habit, prove it once, and watch your cairn begin to rise.'),
        findsOneWidget,
      );
      // No "N of M done" summary and no "TODAY" section label without tasks.
      expect(find.text('TODAY'), findsNothing);
      expect(find.byType(HomeOccurrenceCardView), findsNothing);
    });

    testHomeWidgets(
        'defect 2 regression: title, body and CTA are all centered on the '
        'full screen width, not just relative to each other', (tester) async {
      final db = await pumpHomeWithSeed(
        tester,
        FixedClock(d(2026, 7, 1)),
        (db) async {},
      );
      addTearDown(db.close);

      final screenCenterX =
          tester.getSize(find.byType(MaterialApp)).width / 2;

      final titleCenterX = tester
          .getCenter(find.text('Your first stone is waiting'))
          .dx;
      final bodyCenterX = tester
          .getCenter(find.text(
            'Add a habit, prove it once, and watch your cairn begin to rise.',
          ))
          .dx;
      final ctaCenterX = tester.getCenter(find.byType(PrimaryButton)).dx;

      // Before the fix, the title (the widest child) defined the whole
      // block's width, so the body/button - though centered *relative to
      // the title* - all sat left-shifted together off the true screen
      // centre. Asserting against the screen's own centre (not just against
      // each other) is what catches that.
      const tolerance = 1.0;
      expect(titleCenterX, closeTo(screenCenterX, tolerance));
      expect(bodyCenterX, closeTo(screenCenterX, tolerance));
      expect(ctaCenterX, closeTo(screenCenterX, tolerance));
    });
  });

  group('card states', () {
    testHomeWidgets('VERIFIED: sage chip, meta line, no Prove it button', (
      tester,
    ) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = await pumpHomeWithSeed(tester, clock, (db) async {
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
      });
      addTearDown(db.close);

      expect(find.text('Morning workout'), findsOneWidget);
      expect(find.textContaining('Verified ·'), findsOneWidget);
      expect(find.text('Cairn 1 · 1 stone · new stone placed'), findsOneWidget);
      expect(find.text('Prove it'), findsNothing);
      expect(find.byWidgetPredicate((w) => w is StatusChip && w.variant == StatusChipVariant.verified), findsOneWidget);
    });

    testHomeWidgets(
        'AWAITING VERIFICATION: muted chip, held metres, stone still counts',
        (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = await pumpHomeWithSeed(tester, clock, (db) async {
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
      });
      addTearDown(db.close);

      expect(find.text('Meditate 10 min'), findsOneWidget);
      expect(find.text('Awaiting verification'), findsOneWidget);
      // First-ever completion, sole occurrence today: base 10 + streak 1 +
      // perfect-day 15 = 26, but withheld until verified.
      expect(
        find.text('Cairn 1 · 1 stone · 26 m when verified'),
        findsOneWidget,
      );
      expect(find.text('Prove it'), findsNothing);
    });

    testHomeWidgets('DUE: terracotta Prove it button, no chip', (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = await pumpHomeWithSeed(tester, clock, (db) async {
        final taskRepo = TaskRepository(db, clock);
        await taskRepo.createTask(
          title: 'Read 20 pages',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );
      });
      addTearDown(db.close);

      expect(find.text('Read 20 pages'), findsOneWidget);
      expect(find.text('Due today · Cairn 1 · 0 stones'), findsOneWidget);
      expect(find.text('Prove it'), findsOneWidget);
      expect(find.byType(PrimaryButton), findsOneWidget);
      // Defect 4 regression: a zero-stone task renders the dashed ghost
      // cairn in its mini-cairn column instead of an empty gap.
      expect(find.byType(GhostCairnStack), findsOneWidget);
    });

    testHomeWidgets('SCHEDULED: dimmed card, outlined Scheduled chip', (
      tester,
    ) async {
      final clock = FixedClock(
        d(2026, 7, 10),
        nowMillis: _localMillis(2026, 7, 10, 7, 0),
      );
      final db = await pumpHomeWithSeed(tester, clock, (db) async {
        final taskRepo = TaskRepository(db, clock);
        await taskRepo.createTask(
          title: 'Water the plants',
          recurrenceType: RecurrenceType.daily,
          dueTimes: const ['20:00'],
          startDate: d(2026, 7, 1),
        );
      });
      addTearDown(db.close);

      final expectedTime = formatTimeOfDay(
        DateTime(2000, 1, 1, 20, 0),
        const Locale('en'),
      );
      expect(find.text('Water the plants'), findsOneWidget);
      expect(find.text('Cairn 1 · 0 stones'), findsOneWidget);
      expect(find.text('Scheduled · $expectedTime'), findsOneWidget);
      expect(find.text('Prove it'), findsNothing);
      // Defect 4 regression: a zero-stone task renders the dashed ghost
      // cairn in its mini-cairn column instead of an empty gap.
      expect(find.byType(GhostCairnStack), findsOneWidget);
    });
  });

  group('multiple occurrences', () {
    testHomeWidgets('a task with two due times produces two cards', (
      tester,
    ) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = await pumpHomeWithSeed(tester, clock, (db) async {
        final taskRepo = TaskRepository(db, clock);
        await taskRepo.createTask(
          title: 'Meds',
          recurrenceType: RecurrenceType.daily,
          dueTimes: const ['08:00', '20:00'],
          startDate: d(2026, 7, 1),
        );
      });
      addTearDown(db.close);

      expect(find.byType(HomeOccurrenceCardView), findsNWidgets(2));
      expect(find.text('Meds'), findsNWidgets(2));
    });
  });

  group('header summary', () {
    testHomeWidgets('N of M done and N stones this week reflect real data', (
      tester,
    ) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = await pumpHomeWithSeed(tester, clock, (db) async {
        final taskRepo = TaskRepository(db, clock);
        final completionRepo =
            CompletionRepository(db, clock, verifier: FakeProofVerifier());
        final taskA = await taskRepo.createTask(
          title: 'A',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );
        await taskRepo.createTask(
          title: 'B',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );
        await completionRepo.completeOccurrence(
          taskId: taskA.id,
          occurrenceDate: d(2026, 7, 10),
        );
      });
      addTearDown(db.close);

      expect(find.text('1 of 2 done'), findsOneWidget);
      expect(find.text('1 stone this week'), findsOneWidget);
    });
  });

  group('reactivity', () {
    testHomeWidgets(
        'the screen updates when a completion is recorded underneath it',
        (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      late TaskRepository taskRepo;
      late CompletionRepository completionRepo;
      late Task task;

      final db = await pumpHomeWithSeed(tester, clock, (db) async {
        taskRepo = TaskRepository(db, clock);
        completionRepo =
            CompletionRepository(db, clock, verifier: FakeProofVerifier());
        task = await taskRepo.createTask(
          title: 'Push-ups',
          recurrenceType: RecurrenceType.daily,
          startDate: d(2026, 7, 1),
        );
      });
      addTearDown(db.close);

      expect(find.text('Prove it'), findsOneWidget);
      expect(find.text('0 of 1 done'), findsOneWidget);

      // Simulate a completion recorded elsewhere (e.g. a background retry
      // resolving, or another surface of the app) - not via a tap on this
      // screen's own button.
      await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      await tester.pumpAndSettle();

      expect(find.text('Prove it'), findsNothing);
      expect(find.textContaining('Verified ·'), findsOneWidget);
      expect(find.text('1 of 1 done'), findsOneWidget);
    });
  });

  group('Prove it wiring', () {
    testHomeWidgets(
        'tapping Prove it calls the proof flow and flips the card to verified',
        (tester) async {
      final clock = FixedClock(d(2026, 7, 10));
      final db = inMemoryDatabase();
      addTearDown(db.close);

      final taskRepo = TaskRepository(db, clock);
      final task = await taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            clockProvider.overrideWithValue(clock),
            debugVerifierModeProvider.overrideWith((ref) => DebugVerifierMode.pass),
            photoCaptureProvider.overrideWithValue(_FakePhotoCapture(
              takenAtMillis: clock.nowEpochMillis(),
            )),
            imageCompressorProvider.overrideWithValue(_FakeImageCompressor()),
            proofPhotoStoreProvider.overrideWithValue(_FakeProofPhotoStore()),
          ],
          child: wrap(const HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Prove it'), findsOneWidget);

      await tester.tap(find.text('Prove it'));
      await tester.pumpAndSettle();

      expect(find.text('Prove it'), findsNothing);
      expect(find.textContaining('Verified ·'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget); // snackbar placeholder
      expect(task.title, 'Push-ups'); // sanity: same task throughout
    });
  });
}

/// Seeds data via [seed] (given the same in-memory [AppDatabase] the
/// pumped [HomeScreen] will read through its providers), then pumps the
/// screen. Seeding first (rather than after) means the very first snapshot
/// the screen builds already reflects it, without relying on a second
/// reactive update to prove these state-mapping tests.
Future<AppDatabase> pumpHomeWithSeed(
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
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}
