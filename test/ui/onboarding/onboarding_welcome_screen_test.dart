import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/ui/onboarding/onboarding_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// Widget tests for the onboarding welcome screen (`Cairn Onboarding.dc.html`,
/// screen 1 of 2), exercised through the real [OnboardingFlow] - the same
/// nested-`Navigator` host the app actually uses - rather than
/// `MaterialApp(home: OnboardingWelcomeScreen())` directly, so "Start
/// climbing" is asserted against real internal navigation, not a bare
/// callback invocation.
void main() {
  Widget wrap() {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FixedClock(d(2026, 7, 1))),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OnboardingFlow(),
      ),
    );
  }

  Future<void> pumpWelcome(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
  }

  group('content', () {
    testWidgets(
        'renders both headline lines, the subhead, the clarifier line, all '
        'three step cards, and both buttons', (tester) async {
      await pumpWelcome(tester);

      expect(find.text("Don't just check it off."), findsOneWidget);
      expect(find.text('Prove it.'), findsOneWidget);

      expect(
        find.text(
          'Cairn turns real effort into something you can see grow: one '
          'verified stone at a time.',
        ),
        findsOneWidget,
      );

      expect(
        find.text('A cairn is a small stack of stones that hikers build to mark a trail.'),
        findsOneWidget,
      );

      // Step cards: bold lead + muted remainder compose into one Text.rich
      // whose flattened text is "<lead> <body>", so find.textContaining
      // (not find.text) is the right matcher here - same convention
      // verify_result_screen_test.dart uses for its own lead/body banners.
      expect(find.textContaining('Do the thing.'), findsOneWidget);
      expect(find.textContaining('Your habit, in the real world.'), findsOneWidget);
      expect(find.textContaining('Snap a photo.'), findsOneWidget);
      expect(find.textContaining('A quick proof of what you did.'), findsOneWidget);
      expect(find.textContaining('AI verifies.'), findsOneWidget);
      expect(find.textContaining('A stone settles on your cairn.'), findsOneWidget);

      expect(find.text('Start climbing'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('"Start climbing" pushes the verification screen on the internal Navigator',
        (tester) async {
      await pumpWelcome(tester);

      await tester.tap(find.text('Start climbing'));
      await tester.pumpAndSettle();

      expect(find.text('How verification works'), findsOneWidget);
      expect(find.text('Start climbing'), findsNothing);
    });
  });

  group('already have an account', () {
    testWidgets('shows the coming-soon snackbar', (tester) async {
      await pumpWelcome(tester);

      await tester.tap(find.text('I already have an account'));
      await tester.pump();

      expect(
        find.text('Signing in to an existing account is coming soon.'),
        findsOneWidget,
      );
    });
  });
}
