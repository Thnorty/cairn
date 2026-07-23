import 'package:cairn/src/ui/account/account_chrome.dart';
import 'package:cairn/src/ui/theme/app_colors.dart';
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

  group('AccountInlineLink', () {
    testWidgets('renders navigation variant with sage color and no underline by default',
        (tester) async {
      await tester.pumpWidget(wrap(AccountInlineLink(
        label: 'Sign in',
        onTap: () {},
      )));

      final textWidget = tester.widget<Text>(find.text('Sign in'));
      expect(textWidget.style?.color, AppColors.sage);
      expect(textWidget.style?.decoration, TextDecoration.none);
      expect(textWidget.style?.fontWeight, FontWeight.w600);
      expect(textWidget.style?.fontSize, 14);
    });

    testWidgets('renders error variant with terracotta color and underline',
        (tester) async {
      await tester.pumpWidget(wrap(AccountInlineLink(
        label: 'Sign in instead?',
        style: AccountInlineLinkStyle.error,
        onTap: () {},
      )));

      final textWidget = tester.widget<Text>(find.text('Sign in instead?'));
      expect(textWidget.style?.color, AppColors.terracotta);
      expect(textWidget.style?.decoration, TextDecoration.underline);
      expect(textWidget.style?.fontWeight, FontWeight.w600);
      expect(textWidget.style?.fontSize, 12.5);
    });

    testWidgets('supports font weight and font size overrides', (tester) async {
      await tester.pumpWidget(wrap(AccountInlineLink(
        label: 'Forgot password?',
        fontWeight: FontWeight.w500,
        fontSize: 13,
        onTap: () {},
      )));

      final textWidget = tester.widget<Text>(find.text('Forgot password?'));
      expect(textWidget.style?.color, AppColors.sage);
      expect(textWidget.style?.decoration, TextDecoration.none);
      expect(textWidget.style?.fontWeight, FontWeight.w500);
      expect(textWidget.style?.fontSize, 13);
    });
  });
}

