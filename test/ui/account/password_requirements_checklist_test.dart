import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/ui/account/password_requirements_checklist.dart';
import 'package:cairn/src/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildWidget(String password) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PasswordRequirementsChecklist(password: password),
      ),
    );
  }

  testWidgets('renders all 4 requirement labels', (tester) async {
    await tester.pumpWidget(buildWidget(''));

    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(find.text('An uppercase letter'), findsOneWidget);
    expect(find.text('A lowercase letter'), findsOneWidget);
    expect(find.text('A number'), findsOneWidget);
  });

  testWidgets('empty password renders all rules as unmet (terracotta text color)',
      (tester) async {
    await tester.pumpWidget(buildWidget(''));

    final texts = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(texts.length, 4);
    for (final text in texts) {
      expect(text.style?.color, AppColors.terracotta);
    }
  });

  testWidgets('fully valid password renders all rules as met (sageText color)',
      (tester) async {
    await tester.pumpWidget(buildWidget('Abcdefg1'));

    final texts = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(texts.length, 4);
    for (final text in texts) {
      expect(text.style?.color, AppColors.sageText);
    }
  });

  testWidgets('partially valid password renders met and unmet rules correctly',
      (tester) async {
    await tester.pumpWidget(buildWidget('abc'));

    final minLengthText =
        tester.widget<Text>(find.text('At least 8 characters'));
    final uppercaseText = tester.widget<Text>(find.text('An uppercase letter'));
    final lowercaseText = tester.widget<Text>(find.text('A lowercase letter'));
    final digitText = tester.widget<Text>(find.text('A number'));

    expect(minLengthText.style?.color, AppColors.terracotta);
    expect(uppercaseText.style?.color, AppColors.terracotta);
    expect(lowercaseText.style?.color, AppColors.sageText);
    expect(digitText.style?.color, AppColors.terracotta);
  });
}
