import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/ui/account/account_chrome.dart';
import 'package:cairn/src/ui/account/account_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';
import 'account_test_harness.dart';

/// Integration tests for the whole [AccountFlow] nested-Navigator host:
/// each screen wired to the next exactly as `account_flow.dart` builds it,
/// driven by a real [AccountService] (see `AccountTestHarness`) so these
/// tests exercise the actual routing decisions (which screen comes next,
/// and when the whole flow closes) rather than any one screen in
/// isolation.
void main() {
  Future<void> pumpFlow(
    WidgetTester tester,
    AccountTestHarness harness, {
    required AccountEntryPoint start,
    VoidCallback? onComplete,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AccountFlow(start: start, onComplete: onComplete),
                    ),
                  ),
                  child: const Text('placeholder-home'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('placeholder-home'));
    await tester.pumpAndSettle();
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    final fields = find.byType(TextField);
    for (var i = 0; i < code.length; i++) {
      await tester.enterText(fields.at(i), code[i]);
      await tester.pump();
    }
  }

  testWidgets('create success: Create account -> Enter code -> flow closes',
      (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await pumpFlow(tester, harness, start: AccountEntryPoint.createAccount);

    expect(find.text('Keep your trail safe'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'new@example.com');
    await tester.enterText(find.byType(TextField).last, 'Abcdefg1');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the code'), findsOneWidget);
    expect(
      find.textContaining('We sent a 6-digit code to new@example.com.'),
      findsOneWidget,
    );

    await enterCode(tester, '123456');
    await tester.tap(find.widgetWithText(AccountSubmitButton, 'Verify'));
    await tester.pumpAndSettle();

    expect(harness.auth.verifyEmailCodeCalls, ['123456']);
    expect(harness.auth.setPasswordCalls, ['Abcdefg1']);
    // The flow closed: back to the placeholder screen underneath.
    expect(find.text('placeholder-home'), findsOneWidget);
    expect(find.byType(AccountFlow), findsNothing);
  });

  testWidgets('sign-in with no local trail to lose: SignInComplete closes '
      'the flow directly', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await pumpFlow(tester, harness, start: AccountEntryPoint.signIn);

    expect(find.text('Welcome back'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'hunter22');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('placeholder-home'), findsOneWidget);
    expect(find.byType(AccountFlow), findsNothing);
  });

  testWidgets('sign-in with local data: SignInNeedsTrailChoice -> chooser -> '
      '"Keep this device" closes the flow', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await harness.taskRepository.createTask(
      title: 'Local habit',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );
    await pumpFlow(tester, harness, start: AccountEntryPoint.signIn);

    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'hunter22');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Keep which trail?'), findsOneWidget);

    await tester.tap(find.text('This device'));
    await tester.pump();
    await tester.tap(find.text("Keep this device's trail"));
    await tester.pumpAndSettle();

    expect(find.text('placeholder-home'), findsOneWidget);
    expect(find.byType(AccountFlow), findsNothing);
    final localTasks = await harness.db.select(harness.db.tasks).get();
    expect(localTasks, hasLength(1));
  });

  testWidgets('sign-in with local data: SignInNeedsTrailChoice -> chooser -> '
      '"This account" -> "Keep this account\'s trail" closes the flow',
      (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await harness.taskRepository.createTask(
      title: 'Local habit',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );
    await pumpFlow(tester, harness, start: AccountEntryPoint.signIn);

    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'hunter22');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('This account'));
    await tester.pump();
    await tester.tap(find.text("Keep this account's trail"));
    await tester.pumpAndSettle();

    expect(find.text('placeholder-home'), findsOneWidget);
    expect(find.byType(AccountFlow), findsNothing);
    final localTasks = await harness.db.select(harness.db.tasks).get();
    expect(localTasks, isEmpty); // replaced by the (empty) cloud account
  });

  testWidgets('password reset end to end: Sign in -> Forgot password screen -> '
      'Enter code -> Set new password -> flow closes', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await pumpFlow(tester, harness, start: AccountEntryPoint.signIn);

    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    // Now on Forgot password screen
    expect(find.text('Forgot your password?'), findsOneWidget);
    expect(find.text('a@b.com'), findsOneWidget);
    expect(harness.auth.sendPasswordResetCodeCalls, isEmpty);

    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(harness.auth.sendPasswordResetCodeCalls, ['a@b.com']);
    expect(find.text('Enter the code'), findsOneWidget);
    expect(
      find.text('We sent a 6-digit code to a@b.com to reset your password.'),
      findsOneWidget,
    );

    await enterCode(tester, '654321');
    await tester.tap(find.widgetWithText(AccountSubmitButton, 'Verify'));
    await tester.pumpAndSettle();

    expect(harness.auth.verifyPasswordResetCodeCalls, hasLength(1));
    expect(harness.auth.verifyPasswordResetCodeCalls.single.code, '654321');
    expect(find.text('Set a new password'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'BrandNew1');
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();

    expect(harness.auth.setPasswordCalls, ['BrandNew1']);
    expect(find.text('placeholder-home'), findsOneWidget);
    expect(find.byType(AccountFlow), findsNothing);
  });

  testWidgets('closing via the X on the first screen pops the whole flow '
      'without completing anything', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await pumpFlow(tester, harness, start: AccountEntryPoint.createAccount);

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();

    expect(find.text('placeholder-home'), findsOneWidget);
    expect(harness.auth.startEmailUpgradeCalls, isEmpty);
  });

  testWidgets('onComplete runs before the flow closes on a successful '
      'sign-in (the onboarding hand-off hook)', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    var completed = false;
    await pumpFlow(
      tester,
      harness,
      start: AccountEntryPoint.signIn,
      onComplete: () => completed = true,
    );

    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'hunter22');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });
}
