import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/trail_summary.dart';
import 'package:cairn/src/services/account_error.dart';
import 'package:cairn/src/ui/account/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';
import 'account_test_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    AccountTestHarness harness, {
    VoidCallback? onClose,
    VoidCallback? onSignInComplete,
    void Function(TrailSummary local, TrailSummary remote)? onNeedsTrailChoice,
    void Function(String email)? onForgotPassword,
    VoidCallback? onCreateAccount,
    String? initialEmail,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SignInScreen(
            onClose: onClose ?? () {},
            onSignInComplete: onSignInComplete ?? () {},
            onNeedsTrailChoice: onNeedsTrailChoice ?? (_, __) {},
            onForgotPassword: onForgotPassword ?? (_) {},
            onCreateAccount: onCreateAccount ?? () {},
            initialEmail: initialEmail,
          ),
        ),
      ),
    );
  }

  testWidgets('renders the title, body, fields, and pre-fills the email',
      (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await pump(tester, harness, initialEmail: 'prefill@example.com');

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('prefill@example.com'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('SignInComplete calls onSignInComplete (no local trail to lose)',
      (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    var completed = false;
    await pump(tester, harness, onSignInComplete: () => completed = true);

    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'hunter22');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });

  testWidgets('SignInNeedsTrailChoice forwards both summaries when local data '
      'exists', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await harness.taskRepository.createTask(
      title: 'Local habit',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    TrailSummary? gotLocal;
    TrailSummary? gotRemote;
    await pump(
      tester,
      harness,
      onNeedsTrailChoice: (local, remote) {
        gotLocal = local;
        gotRemote = remote;
      },
    );

    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'hunter22');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(gotLocal, isNotNull);
    expect(gotRemote, isNotNull);
  });

  testWidgets('invalidCredentials shows an inline password error', (tester) async {
    final harness = buildAccountTestHarness();
    harness.auth.signInWithPasswordError =
        const AccountException(AccountError.invalidCredentials);
    addTearDown(harness.db.close);
    await pump(tester, harness);

    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
  });

  testWidgets('offline shows the offline banner', (tester) async {
    final harness = buildAccountTestHarness();
    harness.auth.signInWithPasswordError = const AccountException(AccountError.offline);
    addTearDown(harness.db.close);
    await pump(tester, harness);

    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'hunter22');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text("You're offline. Try again once you're connected."), findsOneWidget);
  });

  testWidgets('"Forgot password?" fires onForgotPassword with typed email '
      '(navigation only; no reset code sent)', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    String? forgotEmail;
    await pump(tester, harness, onForgotPassword: (email) => forgotEmail = email);

    await tester.enterText(find.byType(TextField).first, 'user@example.com');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(forgotEmail, 'user@example.com');
    expect(harness.auth.sendPasswordResetCodeCalls, isEmpty);
  });

  testWidgets('"New here? Create an account" fires onCreateAccount', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    var tapped = false;
    await pump(tester, harness, onCreateAccount: () => tapped = true);

    await tester.tap(find.text('Create an account'));
    expect(tapped, isTrue);
  });
}
