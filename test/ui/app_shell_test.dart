import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/ui/shell/app_shell.dart';
import 'package:cairn/src/ui/theme/app_colors.dart';
import 'package:cairn/src/ui/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Wraps [testWidgets] with a fix-up for a drift + flutter_test interaction:
/// cancelling a `.watch()` stream subscription - which happens when the
/// widget tree (and with it Home's `homeSnapshotProvider`, now that Today is
/// the real [HomeScreen]) is torn down - schedules a zero-duration `Timer`
/// (see drift's `QueryStream._onCancelOrPause`). In the running app that's
/// harmless (it fires on the very next frame); `flutter_test`'s own
/// `_verifyInvariants` check runs immediately once the test body returns,
/// before any further pump, so without this every test that pumps an
/// [AppShell] fails with "A Timer is still pending even after the widget
/// tree was disposed." Replacing the tree with something trivial (which
/// unmounts the `ProviderScope` and schedules the timer) and pumping with an
/// explicit (if zero) duration - `tester.pump()` with no argument never
/// elapses flutter_test's fake clock, so it would never actually fire the
/// timer - runs that disposal while the test can still pump afterward,
/// instead of leaving it to the framework's own automatic end-of-test
/// teardown, which gets no such extra pump.
void testAppShellWidgets(
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
  Widget wrap(Widget home) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  /// Today is now the real [HomeScreen] (Phase 3), which reads through
  /// [databaseProvider]/[clockProvider] like every other real screen; every
  /// [AppShell] test needs those overridden with a fresh in-memory database
  /// now, not just the debug-screen one that already did this.
  Future<void> pumpShell(WidgetTester tester) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FixedClock(d(2026, 7, 1))),
        ],
        child: wrap(const AppShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The *resolved* style a `Text` widget paints with, i.e. after Flutter
  /// merges its `style:` argument onto whatever `DefaultTextStyle` is in
  /// scope - not just the `style:` argument itself (reading `Text.style`
  /// directly would hide a missing-`Material`-ancestor regression, since
  /// [AppTextStyles] tokens always set their own `fontFamily`/`color` and
  /// those survive the merge either way; only ambient-only properties like
  /// `decoration` reveal it). Digs into the `RichText` the `Text` builds
  /// down to, which carries the fully-merged style.
  TextStyle resolvedStyle(WidgetTester tester, Finder textFinder) {
    final richText = tester.widget<RichText>(
      find.descendant(of: textFinder, matching: find.byType(RichText)),
    );
    return richText.text.style!;
  }

  /// MaterialApp gives its root `DefaultTextStyle` a deliberately-ugly
  /// red/yellow-double-underlined style to flag `Text` with no `Material`
  /// ancestor (see `MaterialApp`'s "Why is my app's text red with yellow
  /// underlines?" troubleshooting doc). Any leftover trace of it in a
  /// resolved style means some ancestor chain is missing a `Material`.
  void expectThemedNotFallback(TextStyle style) {
    expect(
      style.decoration,
      isNot(TextDecoration.underline),
      reason: 'still carrying MaterialApp\'s no-Material-ancestor marker',
    );
    expect(
      style.decorationColor,
      isNot(const Color(0xFFFFFF00)),
      reason: 'still carrying MaterialApp\'s no-Material-ancestor marker',
    );
    expect(
      style.decorationStyle,
      isNot(TextDecorationStyle.double),
      reason: 'still carrying MaterialApp\'s no-Material-ancestor marker',
    );
  }

  group('AppShell', () {
    testAppShellWidgets('renders all four tabs', (tester) async {
      await pumpShell(tester);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Trail'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
    });

    testAppShellWidgets(
      'starts on the Today tab, showing the real Home screen (Empty '
      'Today for a fresh database)',
      (tester) async {
        await pumpShell(tester);

        // HomeScreen, not the old placeholder: a fresh in-memory database
        // has no tasks yet, so Home renders its Empty Today state.
        expect(find.text('Your first stone is waiting'), findsOneWidget);
        expect(find.text('Trail - coming soon'), findsNothing);
      },
    );

    testAppShellWidgets(
      'the Today tab has no stray scrollbar (Empty Today does not scroll)',
      (tester) async {
        await pumpShell(tester);

        expect(find.byType(Scrollbar), findsNothing);
        expect(find.byType(Scrollable), findsNothing);
      },
    );

    testAppShellWidgets('switching tabs changes the visible body', (tester) async {
      await pumpShell(tester);

      await tester.tap(find.text('Trail'));
      await tester.pumpAndSettle();
      expect(find.text('Trail - coming soon'), findsOneWidget);

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();
      expect(find.text('Stats - coming soon'), findsOneWidget);

      await tester.tap(find.text('You'));
      await tester.pumpAndSettle();
      expect(find.text('You - coming soon'), findsOneWidget);
    });

    testAppShellWidgets('long-pressing the wordmark opens the debug screen', (
      tester,
    ) async {
      // The wordmark long-press now lives on HomeScreen's own brand row
      // (see AppShell's doc comment: its shared placeholder header is
      // hidden while a real screen, like Home, is showing), so this is
      // exercising HomeScreen's wiring of the same callback, not
      // AppShell's own header.
      await pumpShell(tester);

      await tester.longPress(find.text('Cairn'));
      await tester.pumpAndSettle();

      expect(find.text('No active tasks. Tap + to add one.'), findsOneWidget);
    });
  });

  // Regression coverage for the missing-`Material`-ancestor bug: every one
  // of these used to render with MaterialApp's yellow-double-underlined
  // debug fallback decoration, invisible to `find.text` assertions and
  // only visible on an actual render (a real-device screenshot). Wrapping
  // AppShell in a `Material` (see its build() method) fixes it; these
  // assert on the resolved style so a regression fails here instead of
  // only being visible on a device.
  group('AppShell text styling (no Material-ancestor debug fallback)', () {
    testAppShellWidgets(
      'the wordmark (now on HomeScreen\'s own brand row) renders with the '
      'themed style',
      (tester) async {
        await pumpShell(tester);

        final style = resolvedStyle(tester, find.text('Cairn'));
        expectThemedNotFallback(style);
        expect(style.fontFamily, AppTextStyles.wordmark.fontFamily);
        expect(style.color, AppTextStyles.wordmark.color);
      },
    );

    testAppShellWidgets('a still-placeholder body renders with the themed style', (
      tester,
    ) async {
      await pumpShell(tester);

      await tester.tap(find.text('Trail'));
      await tester.pumpAndSettle();

      final style = resolvedStyle(
        tester,
        find.text('Trail - coming soon'),
      );
      expectThemedNotFallback(style);
      expect(style.fontFamily, AppTextStyles.body.fontFamily);
      expect(style.color, AppTextStyles.body.color);
    });

    testAppShellWidgets('an active tab label renders with the themed style', (
      tester,
    ) async {
      await pumpShell(tester);

      final style = resolvedStyle(tester, find.text('Today'));
      expectThemedNotFallback(style);
      expect(style.fontFamily, AppTextStyles.tabLabelActive.fontFamily);
      expect(style.color, AppColors.inkStrong);
    });

    testAppShellWidgets('an inactive tab label renders with the themed style', (
      tester,
    ) async {
      await pumpShell(tester);

      final style = resolvedStyle(tester, find.text('Trail'));
      expectThemedNotFallback(style);
      expect(style.fontFamily, AppTextStyles.tabLabelInactive.fontFamily);
      expect(style.color, AppColors.textInactive);
    });
  });
}
