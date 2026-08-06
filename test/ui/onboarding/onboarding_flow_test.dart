import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/settings_repository.dart';
import 'package:cairn/src/services/camera_permission_requester.dart';
import 'package:cairn/src/ui/onboarding/onboarding_flow.dart';
import 'package:cairn/src/ui/onboarding/onboarding_gate.dart';
import 'package:cairn/src/ui/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

class _FakeCameraPermissionRequester implements CameraPermissionRequester {
  @override
  Future<void> request() async {}
}

/// End-to-end test of the whole four-step first-launch onboarding flow
/// (Welcome -> How It Works -> Your Name -> Verification), exercised through
/// the real [OnboardingGate] the app actually boots into - see
/// `onboarding_gate_test.dart` for that widget's own narrower tests and
/// `onboarding_welcome_screen_test.dart`/`onboarding_how_it_works_screen_test.dart`/
/// `onboarding_name_screen_test.dart`/`onboarding_verification_screen_test.dart`
/// for each individual step's own focused tests. This file's job is only the
/// ordering and the "cannot be completed without a name" guarantee end to end.
void main() {
  Widget wrap(AppDatabase db, Clock clock) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        cameraPermissionRequesterProvider.overrideWithValue(_FakeCameraPermissionRequester()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OnboardingGate(),
      ),
    );
  }

  testWidgets(
      'the five steps run in order (Welcome -> How It Works -> Your Name -> '
      'Verification -> Reminders) and Your Name cannot be skipped: Continue '
      'stays disabled and no tap can reach Verification/AppShell until a '
      'name is entered', (tester) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);

    await tester.pumpWidget(wrap(db, FixedClock(d(2026, 7, 1))));
    await tester.pumpAndSettle();
    expect(find.text('Start climbing'), findsOneWidget);

    await tester.tap(find.text('Start climbing'));
    await tester.pumpAndSettle();
    expect(find.text('How it works'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('What should we call you?'), findsOneWidget);

    // Continue is disabled while the field is empty: tapping it (a no-op
    // on a disabled PrimaryButton) must not advance anywhere.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('What should we call you?'), findsOneWidget);
    expect(find.text('How verification works'), findsNothing);
    expect(find.byType(AppShell), findsNothing);

    // Whitespace-only is treated exactly like empty: still stuck.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('What should we call you?'), findsOneWidget);

    // Now enter a real name: Continue finally advances to Verification.
    await tester.enterText(find.byType(TextField), 'Sam');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('How verification works'), findsOneWidget);
    expect(find.text('What should we call you?'), findsNothing);

    // The name was already persisted at the Your Name step (before
    // Verification), independent of the camera-permission step that
    // follows.
    expect(await SettingsRepository(db).displayName(), 'Sam');

    await tester.tap(find.text('Allow camera'));
    await tester.pumpAndSettle();

    // Step 5 (Reminders): skippable, and "Not now" completes onboarding
    // without asking for the notification permission at all.
    expect(find.text('Never miss a stone'), findsOneWidget);
    expect(await SettingsRepository(db).isOnboardingComplete(), isFalse);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(await SettingsRepository(db).isOnboardingComplete(), isTrue);
    // "Not now" writes nothing, so reminders stay at their default (off).
    expect(await SettingsRepository(db).remindersEnabled(), isFalse);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
    // Home renders the just-entered name, no manual refresh needed.
    expect(find.text('Good morning, Sam'), findsOneWidget);

    // Teardown fix-up (see other onboarding/AppShell tests' identical
    // rationale): a drift `.watch()` subscription's teardown timer needs an
    // extra pump after the widget tree is replaced.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
