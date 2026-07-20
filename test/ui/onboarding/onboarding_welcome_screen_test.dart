import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/ui/onboarding/onboarding_flow.dart';
import 'package:cairn/src/ui/onboarding/onboarding_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// Widget tests for the onboarding welcome screen (`Cairn Onboarding.dc.html`,
/// step 1 of 3), exercised through the real [OnboardingFlow] - the same
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
        'renders both headline lines, the subhead, the clarifier line, '
        'both buttons, and dot 1 active - the three step cards moved to the '
        'How It Works screen are not shown here', (tester) async {
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

      // The step cards (Do the thing / Snap a photo / AI verifies) live on
      // the How It Works screen now, not here.
      expect(find.textContaining('Do the thing.'), findsNothing);
      expect(find.textContaining('Snap a photo.'), findsNothing);
      expect(find.textContaining('AI verifies.'), findsNothing);

      expect(find.text('Start climbing'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);

      // Progress indicator with dot 0 (of 3) active; no back control on
      // this first step.
      final dots = tester.widget<OnboardingProgressDots>(find.byType(OnboardingProgressDots));
      expect(dots.activeIndex, 0);
      expect(find.byKey(const ValueKey('onboarding-back-button')), findsNothing);
    });
  });

  group('navigation', () {
    testWidgets('"Start climbing" pushes the How It Works screen (step 2) on the internal Navigator',
        (tester) async {
      await pumpWelcome(tester);

      await tester.tap(find.text('Start climbing'));
      await tester.pumpAndSettle();

      expect(find.text('How it works'), findsOneWidget);
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
