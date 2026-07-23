import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/services/account_error.dart';
import 'package:cairn/src/ui/account/set_new_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    AccountTestHarness harness, {
    VoidCallback? onClose,
    String email = 'a@b.com',
    VoidCallback? onSaved,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SetNewPasswordScreen(
            onClose: onClose ?? () {},
            email: email,
            onSaved: onSaved ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('renders the title, body with the email, and the field',
      (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await pump(tester, harness, email: 'me@example.com');

    expect(find.text('Set a new password'), findsOneWidget);
    expect(
      find.text("Choose a new password for me@example.com and you're back on your trail."),
      findsOneWidget,
    );
  });

  testWidgets('a too-short password is rejected client-side', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await pump(tester, harness);

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();

    expect(find.text('Password needs at least 6 characters.'), findsOneWidget);
    expect(harness.auth.setPasswordCalls, isEmpty);
  });

  testWidgets('a valid password calls AccountService.setNewPassword then '
      'onSaved', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    var saved = false;
    await pump(tester, harness, onSaved: () => saved = true);

    await tester.enterText(find.byType(TextField), 'new-secret');
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();

    expect(harness.auth.setPasswordCalls, ['new-secret']);
    expect(saved, isTrue);
  });

  testWidgets('offline shows the offline banner', (tester) async {
    final harness = buildAccountTestHarness();
    harness.auth.setPasswordError = const AccountException(AccountError.offline);
    addTearDown(harness.db.close);
    await pump(tester, harness);

    await tester.enterText(find.byType(TextField), 'new-secret');
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();

    expect(find.text("You're offline. Try again once you're connected."), findsOneWidget);
  });
}
