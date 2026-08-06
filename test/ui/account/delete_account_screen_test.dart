import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/services/account_error.dart';
import 'package:cairn/src/ui/account/delete_account_screen.dart';
import 'package:cairn/src/ui/widgets/buttons.dart';
import 'package:cairn/src/ui/widgets/cairn_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_account_deleter.dart';
import '../../support/fake_auth_service.dart';
import 'account_test_harness.dart';

void main() {
  testWidgets('DeleteAccountScreen renders signed in email and banners',
      (tester) async {
    final harness = buildAccountTestHarness(
      auth: FakeAuthService(
        userId: 'signed-in-user',
        userEmail: 'ada@example.com',
        isAnonymousUser: false,
      ),
    );
    addTearDown(harness.db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DeleteAccountScreen(
            email: 'ada@example.com',
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete account'), findsWidgets);
    expect(find.text('Signed in as ada@example.com'), findsOneWidget);
    expect(find.text('This cannot be undone'), findsOneWidget);
    expect(find.text('Your trail stays on this phone'), findsOneWidget);
  });

  testWidgets('DeleteAccountScreen primary button is disabled when password is empty',
      (tester) async {
    final harness = buildAccountTestHarness(
      auth: FakeAuthService(
        userId: 'signed-in-user',
        userEmail: 'ada@example.com',
        isAnonymousUser: false,
      ),
    );
    addTearDown(harness.db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DeleteAccountScreen(
            email: 'ada@example.com',
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buttonFinder = find.byType(PrimaryButton);
    expect(buttonFinder, findsOneWidget);

    final buttonWidget = tester.widget<PrimaryButton>(buttonFinder);
    expect(buttonWidget.onPressed, isNull);
  });

  testWidgets('Cancelling confirmation dialog deletes nothing', (tester) async {
    final deleter = FakeAccountDeleter();
    final harness = buildAccountTestHarness(
      auth: FakeAuthService(
        userId: 'signed-in-user',
        userEmail: 'ada@example.com',
        isAnonymousUser: false,
      ),
      accountDeleter: deleter,
    );
    addTearDown(harness.db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DeleteAccountScreen(
            email: 'ada@example.com',
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter password
    await tester.enterText(find.byType(TextField), 'valid-password');
    await tester.pumpAndSettle();

    // Tap Delete account button
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(find.byType(CairnDialog), findsOneWidget);
    expect(find.text('Delete this account?'), findsOneWidget);

    // Tap Cancel on dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Dialog dismissed, deleteRemoteAccount was NOT called
    expect(find.byType(CairnDialog), findsNothing);
    expect(deleter.callCount, 0);
  });

  testWidgets('Confirming dialog invokes deleteAccount and succeeds',
      (tester) async {
    final deleter = FakeAccountDeleter();
    final harness = buildAccountTestHarness(
      auth: FakeAuthService(
        userId: 'signed-in-user',
        userEmail: 'ada@example.com',
        isAnonymousUser: false,
      ),
      accountDeleter: deleter,
    );
    addTearDown(harness.db.close);

    bool closed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DeleteAccountScreen(
              email: 'ada@example.com',
              onClose: () => closed = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter password
    await tester.enterText(find.byType(TextField), 'valid-password');
    await tester.pumpAndSettle();

    // Tap Delete account button
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    // Confirm in dialog
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(deleter.callCount, 1);
    expect(closed, isTrue);
  });

  testWidgets('Wrong password shows inline error on DeleteAccountScreen',
      (tester) async {
    final auth = FakeAuthService(
      userId: 'signed-in-user',
      userEmail: 'ada@example.com',
      isAnonymousUser: false,
    )..signInWithPasswordError =
        const AccountException(AccountError.invalidCredentials);
    final deleter = FakeAccountDeleter();
    final harness = buildAccountTestHarness(
      auth: auth,
      accountDeleter: deleter,
    );
    addTearDown(harness.db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DeleteAccountScreen(
              email: 'ada@example.com',
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter wrong password
    await tester.enterText(find.byType(TextField), 'wrong-password');
    await tester.pumpAndSettle();

    // Tap Delete account button
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    // Confirm in dialog
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    // Surfaces inline error
    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(deleter.callCount, 0);
  });
}
