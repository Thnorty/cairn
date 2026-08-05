import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/settings_repository.dart';
import 'package:cairn/src/ui/onboarding/onboarding_name_screen.dart';
import 'package:cairn/src/ui/proof/verification_chrome.dart' show CloseCircleButton;
import 'package:cairn/src/ui/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';
import '../../support/fake_auth_service.dart';

/// Widget tests for [OnboardingNameScreen] (`Cairn Onboarding Name.dc.html`):
/// both the onboarding step ([onBack]) and the Profile edit variant
/// ([onClose]), pumped directly (not through the full [OnboardingFlow]/
/// [ProfileScreen] hosts - those integration paths are covered in
/// `onboarding_verification_screen_test.dart`'s `pumpVerification` helper
/// and `profile_screen_test.dart` respectively).
void main() {
  /// The currently-rendered avatar-preview initial character (the [Text]
  /// widget itself carries the key, so this reads its `data` directly
  /// rather than searching for a descendant of it).
  String avatarInitialText(WidgetTester tester) {
    return tester
        .widget<Text>(find.byKey(const ValueKey('onboarding-name-avatar-initial')))
        .data!;
  }

  Future<AppDatabase> pumpOnboardingStep(
    WidgetTester tester, {
    VoidCallback? onBack,
    required VoidCallback onSubmit,
  }) async {
    final db = inMemoryDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingNameScreen(onBack: onBack ?? () {}, onSubmit: onSubmit),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  Future<AppDatabase> pumpEditVariant(
    WidgetTester tester, {
    String? initialName,
    VoidCallback? onClose,
    required VoidCallback onSubmit,
    FakeAuthService? auth,
    // Also seeds the *stored* name via SettingsRepository (not just the
    // widget's own initialName pre-fill) whenever true, so a test that
    // checks what's actually persisted after the fact (e.g. "closing
    // without saving leaves the stored value untouched") has a real
    // starting value to compare against.
    bool seedStoredName = false,
  }) async {
    final db = inMemoryDatabase();
    if (seedStoredName && initialName != null) {
      await SettingsRepository(db).setDisplayName(initialName);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          if (auth != null) authServiceProvider.overrideWithValue(auth),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingNameScreen(
            initialName: initialName,
            onClose: onClose ?? () {},
            onSubmit: onSubmit,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  group('onboarding step: content and structure', () {
    testWidgets(
        'renders the headline, subhead, field label, back arrow, and 4 page '
        'dots with the 3rd active - no skip affordance anywhere', (tester) async {
      final db = await pumpOnboardingStep(tester, onSubmit: () {});
      addTearDown(db.close);

      expect(find.text('What should we call you?'), findsOneWidget);
      expect(
        find.text(
          'Just for your greeting and the circle at the top of Today. '
          'Stays on this device until you make an account.',
        ),
        findsOneWidget,
      );
      expect(find.text('Your name'), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-back-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-progress-dots')), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(find.byType(CloseCircleButton), findsNothing);
      // No skip affordance - decided in the spec ("There is NO skip
      // affordance: a skip would reintroduce exactly the case this step
      // exists to remove").
      expect(find.textContaining('Skip'), findsNothing);
    });

    testWidgets('the back arrow calls onBack', (tester) async {
      var backCount = 0;
      final db = await pumpOnboardingStep(
        tester,
        onBack: () => backCount++,
        onSubmit: () {},
      );
      addTearDown(db.close);

      await tester.tap(find.byKey(const ValueKey('onboarding-back-button')));
      await tester.pump();

      expect(backCount, 1);
    });
  });

  group('empty state', () {
    testWidgets('the avatar shows the muted placeholder glyph and Continue '
        'is disabled', (tester) async {
      final db = await pumpOnboardingStep(tester, onSubmit: () {});
      addTearDown(db.close);

      expect(
        find.byKey(const ValueKey('onboarding-name-avatar-placeholder')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-name-avatar-initial')),
        findsNothing,
      );

      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('whitespace-only input keeps Continue disabled and the '
        'avatar on the placeholder glyph (trimmed, not raw, drives both)',
        (tester) async {
      final db = await pumpOnboardingStep(tester, onSubmit: () {});
      addTearDown(db.close);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      expect(
        find.byKey(const ValueKey('onboarding-name-avatar-placeholder')),
        findsOneWidget,
      );
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.onPressed, isNull);
    });
  });

  group('live avatar preview', () {
    testWidgets('typing a name updates the avatar to the uppercased first '
        'character on every keystroke, and enables Continue', (tester) async {
      final db = await pumpOnboardingStep(tester, onSubmit: () {});
      addTearDown(db.close);

      await tester.enterText(find.byType(TextField), 'S');
      await tester.pump();
      expect(find.byKey(const ValueKey('onboarding-name-avatar-initial')), findsOneWidget);
      expect(avatarInitialText(tester), 'S');

      await tester.enterText(find.byType(TextField), 'Sam');
      await tester.pump();
      // Still just the first character, uppercased - not the whole name.
      expect(avatarInitialText(tester), 'S');

      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('a lowercase first character is uppercased in the preview',
        (tester) async {
      final db = await pumpOnboardingStep(tester, onSubmit: () {});
      addTearDown(db.close);

      await tester.enterText(find.byType(TextField), 'riley');
      await tester.pump();

      expect(avatarInitialText(tester), 'R');
    });
  });

  group('onboarding step: submit', () {
    testWidgets('tapping Continue persists the trimmed name and calls '
        'onSubmit', (tester) async {
      var submitted = false;
      final db = await pumpOnboardingStep(
        tester,
        onSubmit: () => submitted = true,
      );
      addTearDown(db.close);

      await tester.enterText(find.byType(TextField), '  Sam  ');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(submitted, isTrue);
      expect(await SettingsRepository(db).displayName(), 'Sam');
    });

    testWidgets('submitting via the keyboard action behaves like Continue '
        'once the field is non-empty', (tester) async {
      var submitted = false;
      final db = await pumpOnboardingStep(
        tester,
        onSubmit: () => submitted = true,
      );
      addTearDown(db.close);

      await tester.enterText(find.byType(TextField), 'Sam');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(submitted, isTrue);
      expect(await SettingsRepository(db).displayName(), 'Sam');
    });
  });

  group('Profile edit variant', () {
    testWidgets('renders close-X instead of the back arrow, no page dots, '
        'and Save instead of Continue', (tester) async {
      final db = await pumpEditVariant(tester, onSubmit: () {});
      addTearDown(db.close);

      expect(find.byType(CloseCircleButton), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-back-button')), findsNothing);
      expect(find.byKey(const ValueKey('onboarding-progress-dots')), findsNothing);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('pre-fills the field and avatar with the current name',
        (tester) async {
      final db = await pumpEditVariant(
        tester,
        initialName: 'Sam',
        onSubmit: () {},
      );
      addTearDown(db.close);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Sam');
      expect(avatarInitialText(tester), 'S');
    });

    testWidgets('the close-X calls onClose without persisting anything',
        (tester) async {
      var closed = false;
      final db = await pumpEditVariant(
        tester,
        initialName: 'Sam',
        seedStoredName: true,
        onClose: () => closed = true,
        onSubmit: () {},
      );
      addTearDown(db.close);

      await tester.enterText(find.byType(TextField), 'Changed');
      await tester.pump();
      await tester.tap(find.byType(CloseCircleButton));
      await tester.pump();

      expect(closed, isTrue);
      expect(await SettingsRepository(db).displayName(), 'Sam');
    });

    testWidgets('tapping Save persists the new trimmed name and calls '
        'onSubmit', (tester) async {
      var submitted = false;
      final db = await pumpEditVariant(
        tester,
        initialName: 'Sam',
        onSubmit: () => submitted = true,
      );
      addTearDown(db.close);

      await tester.enterText(find.byType(TextField), '  Riley  ');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(submitted, isTrue);
      expect(await SettingsRepository(db).displayName(), 'Riley');
    });

    testWidgets('when signed in with a real account, Save also pushes the '
        'name to the account metadata best-effort', (tester) async {
      final auth = FakeAuthService(
        userId: 'real-user',
        userEmail: 'me@example.com',
        isAnonymousUser: false,
      );
      final db = await pumpEditVariant(
        tester,
        initialName: 'Sam',
        onSubmit: () {},
        auth: auth,
      );
      addTearDown(db.close);

      await tester.enterText(find.byType(TextField), 'Riley');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(auth.setDisplayNameCalls, ['Riley']);
    });

    testWidgets('while still anonymous, Save never touches the auth '
        'service', (tester) async {
      final auth = FakeAuthService(isAnonymousUser: true);
      final db = await pumpEditVariant(
        tester,
        initialName: 'Sam',
        onSubmit: () {},
        auth: auth,
      );
      addTearDown(db.close);

      await tester.enterText(find.byType(TextField), 'Riley');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(auth.setDisplayNameCalls, isEmpty);
    });

    testWidgets('a failure pushing to auth metadata never blocks saving the '
        'local name (best-effort)', (tester) async {
      var submitted = false;
      final auth = FakeAuthService(
        userId: 'real-user',
        userEmail: 'me@example.com',
        isAnonymousUser: false,
      )..setDisplayNameError = Exception('offline');
      final db = await pumpEditVariant(
        tester,
        initialName: 'Sam',
        onSubmit: () => submitted = true,
        auth: auth,
      );
      addTearDown(db.close);

      await tester.enterText(find.byType(TextField), 'Riley');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(submitted, isTrue);
      expect(await SettingsRepository(db).displayName(), 'Riley');
    });
  });
}
