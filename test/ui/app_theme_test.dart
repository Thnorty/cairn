import 'package:cairn/src/ui/theme/app_colors.dart';
import 'package:cairn/src/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    testWidgets('exposes CairnTokens with the expected palette values', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final tokens = Theme.of(capturedContext).extension<CairnTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.screenBackground, AppColors.screenBackground);
      expect(tokens.ink, AppColors.inkPrimary);
      expect(tokens.terracotta, AppColors.terracotta);
      expect(tokens.sage, AppColors.sage);
    });

    testWidgets('scaffold background matches the screen background token', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const Scaffold()),
      );
      expect(
        AppTheme.light.scaffoldBackgroundColor,
        AppColors.screenBackground,
      );
    });

    test('text theme uses Zilla Slab for the greeting/heading roles', () {
      final textTheme = AppTheme.light.textTheme;
      expect(textTheme.displayLarge!.fontFamily, 'Zilla Slab');
      expect(textTheme.titleLarge!.fontFamily, 'Zilla Slab');
    });

    test('text theme uses Work Sans for the default body role', () {
      final textTheme = AppTheme.light.textTheme;
      expect(textTheme.bodyMedium!.fontFamily, 'Work Sans');
    });
  });
}
