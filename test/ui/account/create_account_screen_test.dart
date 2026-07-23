import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/services/account_error.dart';
import 'package:cairn/src/ui/account/create_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    AccountTestHarness harness, {
    VoidCallback? onClose,
    void Function(String email, String password)? onCreated,
    void Function(String email)? onSignInInstead,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CreateAccountScreen(
            onClose: onClose ?? () {},
            onCreated: onCreated ?? (_, __) {},
            onSignInInstead: onSignInInstead ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('renders the title, body, free-trail chip, and both fields',
      (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await pump(tester, harness);

    expect(find.text('Keep your trail safe'), findsOneWidget);
    expect(find.text('Free. Your trail stays exactly as it is.'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('a too-short password is rejected client-side without ever '
      'calling AccountService', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await pump(tester, harness);

    await tester.enterText(find.byType(TextField).first, 'new@example.com');
    await tester.enterText(find.byType(TextField).last, '123');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Password needs at least 6 characters.'), findsOneWidget);
    expect(harness.auth.startEmailUpgradeCalls, isEmpty);
  });

  testWidgets('a valid submission calls onCreated with the email and password',
      (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    String? createdEmail;
    String? createdPassword;
    await pump(
      tester,
      harness,
      onCreated: (email, password) {
        createdEmail = email;
        createdPassword = password;
      },
    );

    await tester.enterText(find.byType(TextField).first, 'new@example.com');
    await tester.enterText(find.byType(TextField).last, 'hunter22');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(createdEmail, 'new@example.com');
    expect(createdPassword, 'hunter22');
    expect(harness.auth.startEmailUpgradeCalls, ['new@example.com']);
  });

  testWidgets('emailInUse shows the inline error with a "Sign in instead?" '
      'link that forwards the typed email', (tester) async {
    final harness = buildAccountTestHarness();
    harness.auth.startEmailUpgradeError =
        const AccountException(AccountError.emailInUse);
    addTearDown(harness.db.close);
    String? signInEmail;
    await pump(tester, harness, onSignInInstead: (email) => signInEmail = email);

    await tester.enterText(find.byType(TextField).first, 'taken@example.com');
    await tester.enterText(find.byType(TextField).last, 'hunter22');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('That email is already in use.'), findsOneWidget);
    expect(find.text('Sign in instead?'), findsOneWidget);

    await tester.tap(find.text('Sign in instead?'));
    expect(signInEmail, 'taken@example.com');
  });

  testWidgets('offline shows the offline banner', (tester) async {
    final harness = buildAccountTestHarness();
    harness.auth.startEmailUpgradeError = const AccountException(AccountError.offline);
    addTearDown(harness.db.close);
    await pump(tester, harness);

    await tester.enterText(find.byType(TextField).first, 'new@example.com');
    await tester.enterText(find.byType(TextField).last, 'hunter22');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text("You're offline. Connect to create your account."), findsOneWidget);
  });

  testWidgets('the "Already have an account? Sign in" link forwards the '
      'typed email', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    String? signInEmail;
    await pump(tester, harness, onSignInInstead: (email) => signInEmail = email);

    await tester.enterText(find.byType(TextField).first, 'me@example.com');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(signInEmail, 'me@example.com');
  });

  testWidgets('the close button fires onClose', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    var closed = false;
    await pump(tester, harness, onClose: () => closed = true);

    await tester.tap(find.bySemanticsLabel('Close'));
    expect(closed, isTrue);
  });
}
