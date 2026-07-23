import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/services/account_error.dart';
import 'package:cairn/src/ui/account/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    AccountTestHarness harness, {
    VoidCallback? onClose,
    VoidCallback? onBack,
    void Function(String email)? onCodeSent,
    String? initialEmail,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ForgotPasswordScreen(
            onClose: onClose ?? () {},
            onBack: onBack ?? () {},
            onCodeSent: onCodeSent ?? (_) {},
            initialEmail: initialEmail,
          ),
        ),
      ),
    );
  }

  testWidgets('renders title, body, prefilled email field, and Send code button',
      (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await pump(tester, harness, initialEmail: 'prefilled@example.com');

    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Forgot your password?'), findsOneWidget);
    expect(
      find.text("Enter your account email and we'll send you a 6-digit code to reset it."),
      findsOneWidget,
    );
    expect(find.text('prefilled@example.com'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
    expect(find.textContaining('Remembered it?'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('empty or invalid email shows inline error and does not call sendPasswordResetCode',
      (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    String? codeSentEmail;
    await pump(tester, harness, onCodeSent: (email) => codeSentEmail = email);

    // Tap with empty email
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(harness.auth.sendPasswordResetCodeCalls, isEmpty);
    expect(codeSentEmail, isNull);

    // Enter invalid email (no @)
    await tester.enterText(find.byType(TextField), 'invalidemail');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(harness.auth.sendPasswordResetCodeCalls, isEmpty);
    expect(codeSentEmail, isNull);

    // Typing clears the inline error
    await tester.enterText(find.byType(TextField), 'valid@example.com');
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsNothing);
  });

  testWidgets('valid email calls sendPasswordResetCode and invokes onCodeSent',
      (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    String? codeSentEmail;
    await pump(tester, harness, onCodeSent: (email) => codeSentEmail = email);

    await tester.enterText(find.byType(TextField), 'user@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(harness.auth.sendPasswordResetCodeCalls, ['user@example.com']);
    expect(codeSentEmail, 'user@example.com');
  });

  testWidgets('offline error shows the offline banner', (tester) async {
    final harness = buildAccountTestHarness();
    harness.auth.sendPasswordResetCodeError =
        const AccountException(AccountError.offline);
    addTearDown(harness.db.close);
    await pump(tester, harness);

    await tester.enterText(find.byType(TextField), 'user@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(find.text("You're offline. Try again once you're connected."), findsOneWidget);
  });

  testWidgets('back button and Sign in link invoke onBack', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    var backCount = 0;
    await pump(tester, harness, onBack: () => backCount++);

    // Tap back circle button
    await tester.tap(find.bySemanticsLabel('Back'));
    expect(backCount, 1);

    // Tap "Sign in" link
    await tester.tap(find.text('Sign in'));
    expect(backCount, 2);
  });
}
