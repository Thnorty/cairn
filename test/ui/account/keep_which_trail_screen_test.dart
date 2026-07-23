import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/local_date.dart';
import 'package:cairn/src/models/trail_summary.dart';
import 'package:cairn/src/ui/account/keep_which_trail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    AccountTestHarness harness, {
    VoidCallback? onClose,
    required TrailSummary local,
    required TrailSummary remote,
    VoidCallback? onDone,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: KeepWhichTrailScreen(
            onClose: onClose ?? () {},
            local: local,
            remote: remote,
            onDone: onDone ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('renders both option cards with stone counts, defaults to '
      '"This device" selected, and shows the account-side empty state', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await pump(
      tester,
      harness,
      local: const TrailSummary(stones: 12, lastClimb: LocalDate(2026, 7, 10)),
      remote: const TrailSummary(stones: 0),
    );

    expect(find.text('This device'), findsOneWidget);
    expect(find.text('This account'), findsOneWidget);
    expect(find.text('12 stones · last climb today'), findsOneWidget);
    expect(find.text('No activity yet'), findsOneWidget);
    expect(find.text("Keep this device's trail"), findsOneWidget);
  });

  testWidgets('shows a past last-climb date when it is not today', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await pump(
      tester,
      harness,
      local: const TrailSummary(stones: 1, lastClimb: LocalDate(2026, 7, 10)),
      remote: const TrailSummary(stones: 48, lastClimb: LocalDate(2026, 7, 2)),
    );

    expect(find.text('48 stones · last climb Jul 2'), findsOneWidget);
  });

  testWidgets('selecting "This account" swaps the consequence line and CTA '
      'label, and tapping it calls AccountService.useAccount', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    var done = false;
    await pump(
      tester,
      harness,
      local: const TrailSummary(stones: 12, lastClimb: LocalDate(2026, 7, 10)),
      remote: const TrailSummary(stones: 48, lastClimb: LocalDate(2026, 7, 2)),
      onDone: () => done = true,
    );

    expect(
      find.text("Keeping this device replaces the account's 48 stones "
          "everywhere. This can't be undone."),
      findsOneWidget,
    );

    await tester.tap(find.text('This account'));
    await tester.pump();

    expect(
      find.text("Using this account replaces this device's 12 stones. "
          "This can't be undone."),
      findsOneWidget,
    );
    expect(find.text("Keep this account's trail"), findsOneWidget);

    await tester.tap(find.text("Keep this account's trail"));
    await tester.pumpAndSettle();

    expect(done, isTrue);
    final localTasks = await harness.db.select(harness.db.tasks).get();
    expect(localTasks, isEmpty); // replaced by the (empty) cloud data
  });

  testWidgets('keeping "This device" calls AccountService.keepThisDevice',
      (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await harness.taskRepository.createTask(
      title: 'Local habit',
      recurrenceType: RecurrenceType.daily,
      startDate: LocalDate(2026, 7, 1),
    );
    var done = false;
    await pump(
      tester,
      harness,
      local: const TrailSummary(stones: 1, lastClimb: LocalDate(2026, 7, 10)),
      remote: const TrailSummary(stones: 0),
      onDone: () => done = true,
    );

    await tester.tap(find.text("Keep this device's trail"));
    await tester.pumpAndSettle();

    expect(done, isTrue);
    final localTasks = await harness.db.select(harness.db.tasks).get();
    expect(localTasks, hasLength(1)); // kept, not replaced
  });
}
