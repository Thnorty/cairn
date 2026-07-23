import 'package:cairn/src/ui/account/account_chrome.dart';
import 'package:cairn/src/ui/account/email_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders the label, hint, and typed text', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      wrap(EmailField(
        label: 'Email',
        controller: controller,
        hintText: 'you@example.com',
      )),
    );

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('you@example.com'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'me@example.com');
    expect(controller.text, 'me@example.com');
  });

  testWidgets('renders the error row (and its trailing action) when error is given',
      (tester) async {
    final controller = TextEditingController();
    var tapped = false;
    await tester.pumpWidget(
      wrap(EmailField(
        label: 'Email',
        controller: controller,
        error: AccountFieldErrorRow(
          message: 'That email is already in use.',
          action: AccountInlineLink(
            label: 'Sign in instead?',
            onTap: () => tapped = true,
          ),
        ),
      )),
    );

    expect(find.textContaining('That email is already in use.'), findsOneWidget);
    expect(find.text('Sign in instead?'), findsOneWidget);

    await tester.tap(find.text('Sign in instead?'));
    expect(tapped, isTrue);
  });

  testWidgets('renders no error row when error is null', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      wrap(EmailField(label: 'Email', controller: controller)),
    );

    expect(find.byType(AccountFieldErrorRow), findsNothing);
  });
}
