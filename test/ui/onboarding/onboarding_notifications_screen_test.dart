import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/settings_repository.dart';
import 'package:cairn/src/ui/onboarding/onboarding_header.dart';
import 'package:cairn/src/ui/onboarding/onboarding_notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';
import '../../support/fake_notification_permission_requester.dart';

/// Widget tests for onboarding step 5, Reminders
/// (`Cairn Onboarding Notifications.dc.html`).
///
/// Pumps the screen directly rather than walking the whole flow (which
/// `onboarding_flow_test.dart` already covers end to end), so each footer
/// path can be asserted on in isolation: what it asks for, what it persists,
/// and that both of them finish onboarding.
void main() {
  Future<(AppDatabase, FakeNotificationPermissionRequester, List<String>)>
      pumpReminders(
    WidgetTester tester, {
    bool grantOnRequest = true,
  }) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final permission =
        FakeNotificationPermissionRequester(grantOnRequest: grantOnRequest);
    final events = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FixedClock(d(2026, 7, 20))),
          notificationPermissionRequesterProvider.overrideWithValue(permission),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingNotificationsScreen(
            onBack: () => events.add('back'),
            onComplete: () => events.add('complete'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (db, permission, events);
  }

  /// See `notifications_screen_test.dart`'s identical helper: the "Allow"
  /// path re-plans through `notificationTriggerProvider`, whose drift
  /// subscription leaves a pending timer on dispose.
  Future<void> drainTriggerTeardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  group('content', () {
    testWidgets(
        'renders the headline, subhead, both point cards, both footer '
        'choices, and the 5-dot indicator with the last dot active',
        (tester) async {
      await pumpReminders(tester);

      expect(find.text('Never miss a stone'), findsOneWidget);
      expect(
        find.text(
          'Two reminders, and nothing else. You can change or silence them '
          'any time.',
        ),
        findsOneWidget,
      );
      expect(find.text('When a habit is due'), findsOneWidget);
      expect(find.text('Before a streak breaks'), findsOneWidget);
      expect(find.text('Allow notifications'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);

      final dots = tester.widget<OnboardingProgressDots>(
        find.byType(OnboardingProgressDots),
      );
      expect(dots.count, 5);
      expect(dots.activeIndex, 4);
    });

    testWidgets('the back-chevron pops rather than completing', (tester) async {
      final (_, _, events) = await pumpReminders(tester);

      await tester.tap(find.byKey(const ValueKey('onboarding-back-button')));
      await tester.pumpAndSettle();

      expect(events, ['back']);
    });
  });

  group('Allow notifications', () {
    testWidgets('a granted prompt switches reminders on and completes',
        (tester) async {
      final (db, permission, events) = await pumpReminders(tester);
      expect(await SettingsRepository(db).remindersEnabled(), isFalse);

      await tester.tap(find.text('Allow notifications'));
      await tester.pumpAndSettle();

      expect(permission.requestCount, 1);
      expect(await SettingsRepository(db).remindersEnabled(), isTrue);
      expect(events, ['complete']);

      await drainTriggerTeardown(tester);
    });

    testWidgets(
        'a refused prompt completes anyway but leaves reminders off, so the '
        'app never claims it will remind you when it cannot', (tester) async {
      final (db, permission, events) = await pumpReminders(
        tester,
        grantOnRequest: false,
      );

      await tester.tap(find.text('Allow notifications'));
      await tester.pumpAndSettle();

      expect(permission.requestCount, 1);
      expect(await SettingsRepository(db).remindersEnabled(), isFalse);
      expect(events, ['complete']);
    });
  });

  group('Not now', () {
    testWidgets(
        'completes without ever asking for the permission, leaving reminders '
        'at their default', (tester) async {
      final (db, permission, events) = await pumpReminders(tester);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(permission.requestCount, 0);
      expect(await SettingsRepository(db).remindersEnabled(), isFalse);
      expect(events, ['complete']);
    });
  });
}
