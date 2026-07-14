import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// A [ThemeExtension] exposing the handful of semantic tokens that map
/// naturally onto `Theme.of(context)` lookups (screens should reach for
/// this rather than importing [AppColors] directly, where a token here
/// covers it). The bespoke tokens that don't map onto a theme role - chip
/// variants, stone gradients, card shadows - stay on the static
/// [AppColors]/[AppShadows]/[AppGradients]/[AppRadii] tables.
///
/// There's exactly one palette in the designs (no dark mode to swap
/// between), so this extension always resolves to the same values; it
/// exists for idiomatic `Theme.of(context)` access and future-proofing,
/// not because the app currently themes-swaps.
@immutable
class CairnTokens extends ThemeExtension<CairnTokens> {
  const CairnTokens({
    required this.screenBackground,
    required this.ink,
    required this.inkStrong,
    required this.textMuted,
    required this.labelGrey,
    required this.terracotta,
    required this.terracottaLight,
    required this.sage,
    required this.sageLight,
    required this.cardBorder,
  });

  final Color screenBackground;
  final Color ink;
  final Color inkStrong;
  final Color textMuted;
  final Color labelGrey;
  final Color terracotta;
  final Color terracottaLight;
  final Color sage;
  final Color sageLight;
  final Color cardBorder;

  static const CairnTokens standard = CairnTokens(
    screenBackground: AppColors.screenBackground,
    ink: AppColors.inkPrimary,
    inkStrong: AppColors.inkStrong,
    textMuted: AppColors.textMuted,
    labelGrey: AppColors.labelGrey,
    terracotta: AppColors.terracotta,
    terracottaLight: AppColors.terracottaLight,
    sage: AppColors.sage,
    sageLight: AppColors.sageLight,
    cardBorder: AppColors.cardBorder,
  );

  @override
  CairnTokens copyWith({
    Color? screenBackground,
    Color? ink,
    Color? inkStrong,
    Color? textMuted,
    Color? labelGrey,
    Color? terracotta,
    Color? terracottaLight,
    Color? sage,
    Color? sageLight,
    Color? cardBorder,
  }) {
    return CairnTokens(
      screenBackground: screenBackground ?? this.screenBackground,
      ink: ink ?? this.ink,
      inkStrong: inkStrong ?? this.inkStrong,
      textMuted: textMuted ?? this.textMuted,
      labelGrey: labelGrey ?? this.labelGrey,
      terracotta: terracotta ?? this.terracotta,
      terracottaLight: terracottaLight ?? this.terracottaLight,
      sage: sage ?? this.sage,
      sageLight: sageLight ?? this.sageLight,
      cardBorder: cardBorder ?? this.cardBorder,
    );
  }

  @override
  CairnTokens lerp(ThemeExtension<CairnTokens>? other, double t) {
    if (other is! CairnTokens) return this;
    return CairnTokens(
      screenBackground: Color.lerp(screenBackground, other.screenBackground, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkStrong: Color.lerp(inkStrong, other.inkStrong, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      labelGrey: Color.lerp(labelGrey, other.labelGrey, t)!,
      terracotta: Color.lerp(terracotta, other.terracotta, t)!,
      terracottaLight: Color.lerp(terracottaLight, other.terracottaLight, t)!,
      sage: Color.lerp(sage, other.sage, t)!,
      sageLight: Color.lerp(sageLight, other.sageLight, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
    );
  }
}

/// Builds the app's single [ThemeData] from the design tokens, so screens
/// inherit fonts/colours from `Theme.of(context)` rather than each screen
/// passing styles around by hand.
abstract final class AppTheme {
  static ThemeData get light {
    const tokens = CairnTokens.standard;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.terracotta,
      brightness: Brightness.light,
      primary: AppColors.terracotta,
      secondary: AppColors.sage,
      surface: AppColors.screenBackground,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.screenBackground,
      fontFamily: AppFontFamilies.workSans,
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.greeting,
        headlineLarge: AppTextStyles.screenTitle,
        headlineMedium: AppTextStyles.resultTitle,
        titleLarge: AppTextStyles.taskTitle,
        titleMedium: AppTextStyles.wordmark,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.caption,
        labelSmall: AppTextStyles.sectionLabel,
      ),
      extensions: const [tokens],
    );
  }
}
