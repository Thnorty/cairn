import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/ui/account/signed_in_account_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_service.dart';
import 'account_test_harness.dart';

FakeAuthService _signedInAuth({required String email}) => FakeAuthService(
      userId: 'real-user',
      userEmail: email,
      isAnonymousUser: false,
    );

void main() {
  Future<void> pump(WidgetTester tester, AccountTestHarness harness, {required String email}) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SignedInAccountRow(email: email)),
        ),
      ),
    );
  }

  testWidgets('renders "Signed in", the email, and the backed-up line',
      (tester) async {
    final harness = buildAccountTestHarness(
      auth: _signedInAuth(email: 'me@example.com'),
    );
    addTearDown(harness.db.close);
    await pump(tester, harness, email: 'me@example.com');

    expect(find.text('Signed in'), findsOneWidget);
    expect(find.text('me@example.com'), findsOneWidget);
    expect(find.text('Your trail is backed up.'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('tapping Sign out opens a confirm dialog; Cancel dismisses it '
      'without signing out', (tester) async {
    final harness = buildAccountTestHarness(
      auth: _signedInAuth(email: 'me@example.com'),
    );
    addTearDown(harness.db.close);
    await pump(tester, harness, email: 'me@example.com');

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsOneWidget);
    expect(
      find.text('Your trail stays on this device. Sign back in anytime to sync it to your account again.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(harness.auth.signOutCallCount, 0);
    expect(find.text('Signed in'), findsOneWidget); // still rendered
  });

  testWidgets('confirming Sign out calls AccountService.signOut, reverting '
      'to an anonymous session', (tester) async {
    final harness = buildAccountTestHarness(
      auth: _signedInAuth(email: 'me@example.com'),
    );
    addTearDown(harness.db.close);
    await pump(tester, harness, email: 'me@example.com');

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    // Two "Sign out" texts now exist (the dialog's confirm action reuses
    // the same label as the row's own button): the dialog's own action is
    // the last one in the tree.
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();

    expect(harness.auth.signOutCallCount, 1);
    expect(harness.auth.isAnonymous, isTrue);
  });
}
