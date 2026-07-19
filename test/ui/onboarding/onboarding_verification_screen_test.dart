import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/settings_repository.dart';
import 'package:cairn/src/services/camera_permission_requester.dart';
import 'package:cairn/src/ui/onboarding/onboarding_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// Records whether/how many times [request] was called, so a test can
/// assert the "Allow camera" button really goes through
/// [cameraPermissionRequesterProvider] rather than skipping it, without
/// ever touching `permission_handler`'s platform channel.
class _FakeCameraPermissionRequester implements CameraPermissionRequester {
  int callCount = 0;

  @override
  Future<void> request() async {
    callCount++;
  }
}

/// Widget tests for the onboarding verification screen
/// (`Cairn Onboarding Verification.dc.html`, screen 2 of 2), exercised
/// through the real [OnboardingFlow] (see
/// `onboarding_welcome_screen_test.dart`'s doc comment for why), reached by
/// first tapping "Start climbing" on screen 1.
void main() {
  Future<(AppDatabase db, _FakeCameraPermissionRequester fakeRequester)> pumpVerification(
    WidgetTester tester,
  ) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final fakeRequester = _FakeCameraPermissionRequester();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FixedClock(d(2026, 7, 1))),
          cameraPermissionRequesterProvider.overrideWithValue(fakeRequester),
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

    return (db, fakeRequester);
  }

  group('content', () {
    testWidgets(
        'renders the title, subhead, all three point cards, the permission '
        'primer, the Allow camera button, the privacy link, the 3-dot '
        'indicator, and the back-chevron', (tester) async {
      await pumpVerification(tester);

      expect(find.text('How verification works'), findsOneWidget);
      expect(
        find.text("A quick check keeps every stone honest. Here's exactly what happens to your photo."),
        findsOneWidget,
      );

      expect(find.text('Sent only to be checked'), findsOneWidget);
      expect(
        find.text('Your photo is sent to an AI (Google Gemini) to confirm it matches your habit, nothing else.'),
        findsOneWidget,
      );
      expect(find.text('Never stored in the cloud'), findsOneWidget);
      expect(
        find.text("We don't keep your photos on our servers. They're checked, then discarded."),
        findsOneWidget,
      );
      expect(find.text('Your archive lives on your phone'), findsOneWidget);
      expect(
        find.text('Proof photos are saved on your device. Cloud backup is optional with Premium.'),
        findsOneWidget,
      );

      // Bold lead + plain remainder compose into one Text.rich, same
      // textContaining convention as the welcome screen's step cards.
      expect(find.textContaining('Cairn needs your camera'), findsOneWidget);
      expect(find.textContaining('to capture proof of each habit.'), findsOneWidget);

      expect(find.text('Allow camera'), findsOneWidget);
      expect(find.text('Learn more about privacy'), findsOneWidget);

      expect(find.byKey(const ValueKey('onboarding-progress-dots')), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-back-button')), findsOneWidget);
    });
  });

  group('back navigation', () {
    testWidgets('the back-chevron pops to the welcome screen', (tester) async {
      await pumpVerification(tester);

      await tester.tap(find.byKey(const ValueKey('onboarding-back-button')));
      await tester.pumpAndSettle();

      expect(find.text('Start climbing'), findsOneWidget);
      expect(find.text('How verification works'), findsNothing);
    });
  });

  group('allow camera', () {
    testWidgets(
        'calls the camera-permission requester and marks onboarding complete',
        (tester) async {
      final (db, fakeRequester) = await pumpVerification(tester);

      expect(fakeRequester.callCount, 0);
      expect(await SettingsRepository(db).isOnboardingComplete(), isFalse);

      await tester.tap(find.text('Allow camera'));
      await tester.pumpAndSettle();

      expect(fakeRequester.callCount, 1);
      expect(await SettingsRepository(db).isOnboardingComplete(), isTrue);
    });
  });

  group('learn more about privacy', () {
    testWidgets('shows the coming-soon snackbar', (tester) async {
      await pumpVerification(tester);

      await tester.tap(find.text('Learn more about privacy'));
      await tester.pump();

      expect(find.text('A privacy details page is coming soon.'), findsOneWidget);
    });
  });
}
