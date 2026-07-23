import 'package:cairn/src/ui/account/account_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('AccountSubmitButton', () {
    testWidgets('shows the plain label and fires onPressed when not loading',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(AccountSubmitButton(
        label: 'Create account',
        loadingLabel: 'Creating account...',
        isLoading: false,
        onPressed: () => tapped = true,
      )));

      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Creating account...'), findsNothing);

      await tester.tap(find.text('Create account'));
      expect(tapped, isTrue);
    });

    testWidgets('shows the loading label and spinner, and is not tappable, '
        'while isLoading is true', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(AccountSubmitButton(
        label: 'Create account',
        loadingLabel: 'Creating account...',
        isLoading: true,
        onPressed: () => tapped = true,
      )));

      expect(find.text('Creating account...'), findsOneWidget);
      expect(find.text('Create account'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Creating account...'));
      expect(tapped, isFalse);
    });
  });

  group('AccountOfflineBanner', () {
    testWidgets('renders its message', (tester) async {
      await tester.pumpWidget(
        wrap(const AccountOfflineBanner(message: "You're offline.")),
      );
      expect(find.text("You're offline."), findsOneWidget);
    });
  });

  group('AccountFieldErrorRow', () {
    testWidgets('renders the message with no action when action is omitted',
        (tester) async {
      await tester.pumpWidget(
        wrap(const AccountFieldErrorRow(message: 'Incorrect email or password.')),
      );
      expect(find.text('Incorrect email or password.'), findsOneWidget);
    });
  });
}
