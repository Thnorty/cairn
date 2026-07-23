import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/repo/settings_repository.dart';
import 'package:cairn/src/ui/onboarding/onboarding_flow.dart';
import 'package:cairn/src/ui/onboarding/onboarding_gate.dart';
import 'package:cairn/src/ui/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/account_test_harness.dart';

/// Integration test for the Phase 4b account upgrade's onboarding entry
/// point: `OnboardingWelcomeScreen`'s "I already have an account" pushes
/// the real `AccountFlow` (Sign in first) on the onboarding's own nested
/// Navigator, and a successful sign-in marks onboarding complete and hands
/// off to `AppShell` - see `onboarding_flow.dart`'s own doc comment on why
/// this must happen via `onComplete`, not a plain pop.
void main() {
  Widget wrap(AccountTestHarness harness) {
    return ProviderScope(
      overrides: harness.overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OnboardingGate(),
      ),
    );
  }

  testWidgets(
      'signing in from onboarding marks onboarding complete and hands off '
      'to AppShell', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);

    await tester.pumpWidget(wrap(harness));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingFlow), findsOneWidget);

    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'hunter22');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(await SettingsRepository(harness.db).isOnboardingComplete(), isTrue);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);

    // Teardown fix-up (see other onboarding/AppShell tests' identical
    // rationale): a drift `.watch()` subscription's teardown timer needs an
    // extra pump after the widget tree is replaced.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
