import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/services/account_error.dart';
import 'package:cairn/src/ui/account/account_chrome.dart';
import 'package:cairn/src/ui/account/enter_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    AccountTestHarness harness, {
    VoidCallback? onClose,
    required AccountCodePurpose purpose,
    String email = 'a@b.com',
    String? password,
    VoidCallback? onVerified,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EnterCodeScreen(
            onClose: onClose ?? () {},
            purpose: purpose,
            email: email,
            password: password,
            onVerified: onVerified ?? () {},
          ),
        ),
      ),
    );
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    final fields = find.byType(TextField);
    for (var i = 0; i < code.length; i++) {
      await tester.enterText(fields.at(i), code[i]);
      await tester.pump();
    }
  }

  testWidgets('verify-email purpose renders the trail-safety body copy with '
      'the email interpolated', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await pump(
      tester,
      harness,
      purpose: AccountCodePurpose.verifyEmail,
      email: 'me@example.com',
      password: 'hunter22',
    );

    expect(find.text('Enter the code'), findsOneWidget);
    expect(
      find.text(
        'We sent a 6-digit code to me@example.com. Your trail is safe on '
        'this device in the meantime.',
      ),
      findsOneWidget,
    );
    expect(
      find.text("Can't find it? Check your spam folder."),
      findsOneWidget,
    );
  });

  testWidgets('password-reset purpose renders the reset body copy',
      (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await pump(
      tester,
      harness,
      purpose: AccountCodePurpose.passwordReset,
      email: 'me@example.com',
    );

    expect(
      find.text('We sent a 6-digit code to me@example.com to reset your password.'),
      findsOneWidget,
    );
  });

  testWidgets('Verify is disabled until all 6 digits are entered, then '
      'verifies (verify-email purpose)', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    // Mirrors the real flow: CreateAccountScreen's own successful
    // startCreateAccount call always precedes EnterCodeScreen with
    // purpose = verifyEmail (AccountService.confirmCreateAccount throws
    // StateError otherwise - see its own doc comment).
    await harness.accountService
        .startCreateAccount(email: 'a@b.com', password: 'hunter22');
    var verified = false;
    await pump(
      tester,
      harness,
      purpose: AccountCodePurpose.verifyEmail,
      password: 'hunter22',
      onVerified: () => verified = true,
    );

    final verifyButton = find.widgetWithText(AccountSubmitButton, 'Verify');
    await tester.tap(verifyButton);
    await tester.pump();
    expect(verified, isFalse); // not enough digits yet

    await enterCode(tester, '123456');
    await tester.tap(verifyButton);
    await tester.pumpAndSettle();

    expect(verified, isTrue);
    expect(harness.auth.verifyEmailCodeCalls, ['123456']);
  });

  testWidgets('invalidCode shows an inline error (password-reset purpose)',
      (tester) async {
    final harness = buildAccountTestHarness();
    harness.auth.verifyPasswordResetCodeError =
        const AccountException(AccountError.invalidCode);
    addTearDown(harness.db.close);
    await pump(tester, harness, purpose: AccountCodePurpose.passwordReset);

    await enterCode(tester, '000000');
    await tester.tap(find.widgetWithText(AccountSubmitButton, 'Verify'));
    await tester.pumpAndSettle();

    expect(find.text("That code didn't match. Check it and try again."), findsOneWidget);
  });

  testWidgets('the resend button starts disabled with a countdown, and '
      'resending re-sends the code for the current purpose', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await pump(tester, harness, purpose: AccountCodePurpose.passwordReset);

    expect(find.textContaining('Resend code in 0:'), findsOneWidget);
    expect(find.text('Resend code'), findsNothing);

    // Fast-forward past the cooldown.
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();

    expect(find.text('Resend code'), findsOneWidget);
    await tester.tap(find.text('Resend code'));
    await tester.pumpAndSettle();

    expect(harness.auth.sendPasswordResetCodeCalls, ['a@b.com']);
    // Cooldown restarted.
    expect(find.textContaining('Resend code in 0:'), findsOneWidget);
  });
}
