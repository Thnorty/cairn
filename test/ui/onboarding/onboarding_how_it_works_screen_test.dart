import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/ui/onboarding/onboarding_flow.dart';
import 'package:cairn/src/ui/onboarding/onboarding_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// Widget tests for the onboarding How It Works screen (step 2 of 3: the
/// three "Do the thing / Snap a photo / AI verifies" step cards moved here
/// from the welcome screen - see `onboarding_how_it_works_screen.dart`'s
/// doc comment), exercised through the real [OnboardingFlow] - same
/// rationale as `onboarding_welcome_screen_test.dart`'s own real-navigation
/// approach - reached by first tapping "Start climbing" on step 1.
void main() {
  Future<void> pumpHowItWorks(WidgetTester tester) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FixedClock(d(2026, 7, 1))),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OnboardingFlow(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start climbing'));
    await tester.pumpAndSettle();
  }

  group('content', () {
    testWidgets(
        'renders the title, all three step cards, the Continue button, dot '
        '1 active, and a back-chevron', (tester) async {
      await pumpHowItWorks(tester);

      expect(find.text('How it works'), findsOneWidget);

      // Bold lead + muted remainder compose into one Text.rich, so
      // textContaining (not text) is the right matcher - same convention
      // the welcome screen's own step-card test used to use.
      expect(find.textContaining('Do the thing.'), findsOneWidget);
      expect(find.textContaining('Your habit, in the real world.'), findsOneWidget);
      expect(find.textContaining('Snap a photo.'), findsOneWidget);
      expect(find.textContaining('A quick proof of what you did.'), findsOneWidget);
      expect(find.textContaining('AI verifies.'), findsOneWidget);
      expect(find.textContaining('A stone settles on your cairn.'), findsOneWidget);

      expect(find.text('Continue'), findsOneWidget);

      final dots = tester.widget<OnboardingProgressDots>(find.byType(OnboardingProgressDots));
      expect(dots.activeIndex, 1);
      expect(find.byKey(const ValueKey('onboarding-back-button')), findsOneWidget);
    });
  });

  group('back navigation', () {
    testWidgets('the back-chevron pops to the welcome screen', (tester) async {
      await pumpHowItWorks(tester);

      await tester.tap(find.byKey(const ValueKey('onboarding-back-button')));
      await tester.pumpAndSettle();

      expect(find.text('Start climbing'), findsOneWidget);
      expect(find.text('How it works'), findsNothing);
    });
  });

  group('continue', () {
    testWidgets('"Continue" pushes the verification screen (step 3)', (tester) async {
      await pumpHowItWorks(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('How verification works'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });
  });
}
