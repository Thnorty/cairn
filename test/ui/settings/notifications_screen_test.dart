import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/settings_repository.dart';
import 'package:cairn/src/ui/settings/notifications_screen.dart';
import 'package:cairn/src/ui/widgets/cairn_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';
import '../../support/fake_notification_permission_requester.dart';
import '../../support/fake_recent_photos.dart' show FakeAppSettingsOpener;

/// Widget tests for `Cairn Notifications.dc.html`'s three states: reminders
/// on, reminders off, and blocked by Android.
void main() {
  Future<(AppDatabase, FakeNotificationPermissionRequester, FakeAppSettingsOpener)>
      pumpNotifications(
    WidgetTester tester, {
    bool remindersEnabled = false,
    bool permissionGranted = false,
    bool grantOnRequest = true,
  }) async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final settings = SettingsRepository(db);
    if (remindersEnabled) await settings.setRemindersEnabled(true);

    final permission = FakeNotificationPermissionRequester(
      grantOnRequest: grantOnRequest,
      initiallyGranted: permissionGranted,
    );
    final opener = FakeAppSettingsOpener();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FixedClock(d(2026, 7, 20))),
          notificationPermissionRequesterProvider.overrideWithValue(permission),
          appSettingsOpenerProvider.overrideWithValue(opener),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (db, permission, opener);
  }

  /// Any test that writes a setting goes through
  /// `notificationTriggerProvider`, which starts a drift `.watch()`
  /// subscription; disposing that subscription schedules a zero-duration
  /// timer, and the test framework asserts no timer is pending at the end of
  /// the test body. Tearing the tree down and pumping once more drains it.
  ///
  /// Has to run INSIDE the test body, not in an `addTearDown` - the pending
  /// timer check fires before teardowns do. Same fix-up the
  /// onboarding/AppShell tests already apply inline, for the same reason.
  Future<void> drainTriggerTeardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  CairnSwitch switchIn(WidgetTester tester, String rowKey) {
    return tester.widget<CairnSwitch>(
      find.descendant(
        of: find.byKey(ValueKey(rowKey)),
        matching: find.byType(CairnSwitch),
      ),
    );
  }

  group('reminders off (the default)', () {
    testWidgets('renders all three rows with the master switch off',
        (tester) async {
      await pumpNotifications(tester);

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Habit reminders'), findsOneWidget);
      expect(find.text('Default time'), findsOneWidget);
      expect(find.text('Streak warnings'), findsOneWidget);
      expect(switchIn(tester, 'notifications-master-row').value, isFalse);
    });

    testWidgets(
        'the default-time and streak rows are inert while the master is off, '
        'and only the master stays live', (tester) async {
      await pumpNotifications(tester);

      // A disabled CairnSwitch has a null onChanged - the design dims these
      // two rows precisely because they control nothing in this state.
      expect(switchIn(tester, 'notifications-streak-row').onChanged, isNull);
      expect(switchIn(tester, 'notifications-master-row').onChanged, isNotNull);

      // Tapping the dimmed default-time row opens no picker.
      await tester.tap(find.byKey(const ValueKey('notifications-default-time-row')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);
    });

    testWidgets('the blocked notice is never shown while reminders are off, '
        'even with the permission denied', (tester) async {
      await pumpNotifications(tester, permissionGranted: false);

      expect(find.text('Android is blocking these'), findsNothing);
    });
  });

  group('turning reminders on', () {
    testWidgets('asks for the OS permission and persists the preference',
        (tester) async {
      final (db, permission, _) = await pumpNotifications(tester);

      await tester.tap(find.byType(CairnSwitch).first);
      await tester.pumpAndSettle();

      expect(permission.requestCount, 1);
      expect(await SettingsRepository(db).remindersEnabled(), isTrue);
      expect(switchIn(tester, 'notifications-master-row').value, isTrue);
      // Now live, so the other two rows come with it.
      expect(switchIn(tester, 'notifications-streak-row').onChanged, isNotNull);

      await drainTriggerTeardown(tester);
    });

    testWidgets('does not re-ask when the permission is already granted',
        (tester) async {
      final (_, permission, _) = await pumpNotifications(
        tester,
        permissionGranted: true,
      );

      await tester.tap(find.byType(CairnSwitch).first);
      await tester.pumpAndSettle();

      expect(permission.requestCount, 0);

      await drainTriggerTeardown(tester);
    });

    testWidgets(
        'a refused prompt still saves the preference and surfaces the '
        'blocked notice, rather than snapping the switch back', (tester) async {
      final (db, permission, _) = await pumpNotifications(
        tester,
        grantOnRequest: false,
      );

      await tester.tap(find.byType(CairnSwitch).first);
      await tester.pumpAndSettle();

      expect(permission.requestCount, 1);
      expect(await SettingsRepository(db).remindersEnabled(), isTrue);
      expect(switchIn(tester, 'notifications-master-row').value, isTrue);
      expect(find.text('Android is blocking these'), findsOneWidget);

      await drainTriggerTeardown(tester);
    });
  });

  group('reminders on', () {
    testWidgets('turning the master off persists false', (tester) async {
      final (db, _, _) = await pumpNotifications(
        tester,
        remindersEnabled: true,
        permissionGranted: true,
      );
      expect(switchIn(tester, 'notifications-master-row').value, isTrue);

      await tester.tap(find.byType(CairnSwitch).first);
      await tester.pumpAndSettle();

      expect(await SettingsRepository(db).remindersEnabled(), isFalse);

      await drainTriggerTeardown(tester);
    });

    testWidgets('the streak switch persists independently of the master',
        (tester) async {
      final (db, _, _) = await pumpNotifications(
        tester,
        remindersEnabled: true,
        permissionGranted: true,
      );
      // Streak warnings default ON once reminders are on (opt-out).
      expect(switchIn(tester, 'notifications-streak-row').value, isTrue);

      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('notifications-streak-row')),
        matching: find.byType(CairnSwitch),
      ));
      await tester.pumpAndSettle();

      expect(await SettingsRepository(db).streakWarningsEnabled(), isFalse);
      expect(await SettingsRepository(db).remindersEnabled(), isTrue);

      await drainTriggerTeardown(tester);
    });

    testWidgets('picking a default time persists it as "HH:mm"',
        (tester) async {
      final (db, _, _) = await pumpNotifications(
        tester,
        remindersEnabled: true,
        permissionGranted: true,
      );
      expect(await SettingsRepository(db).defaultReminderTime(), '09:00');

      await tester.tap(find.byKey(const ValueKey('notifications-default-time-row')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);

      // The dialog opens on the stored time; cancelling must change nothing.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await SettingsRepository(db).defaultReminderTime(), '09:00');
    });
  });

  group('blocked by Android', () {
    testWidgets(
        'shows the notice when reminders are on but the permission is denied, '
        'and its button opens system settings', (tester) async {
      final (_, _, opener) = await pumpNotifications(
        tester,
        remindersEnabled: true,
        permissionGranted: false,
      );

      expect(find.text('Android is blocking these'), findsOneWidget);
      // The user's own choices stay visible and stay true - the app never
      // silently flips them off to match the OS.
      expect(switchIn(tester, 'notifications-master-row').value, isTrue);

      await tester.tap(find.text('Open system settings'));
      await tester.pumpAndSettle();
      expect(opener.openCalls, 1);
    });

    testWidgets('no notice once the permission is granted', (tester) async {
      await pumpNotifications(
        tester,
        remindersEnabled: true,
        permissionGranted: true,
      );

      expect(find.text('Android is blocking these'), findsNothing);
    });
  });
}
