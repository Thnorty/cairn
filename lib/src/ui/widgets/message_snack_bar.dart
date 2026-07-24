import 'package:flutter/material.dart'
    show BorderSide, RoundedRectangleBorder, ScaffoldMessenger, SnackBar, TextStyle;
import 'package:flutter/widgets.dart' show BorderRadius, BuildContext, Color, Text;

import '../theme/app_colors.dart';

/// Tone treatments for transient snackbar messages.
enum MessageTone { neutral, success, muted }

/// Shared helper for presenting a text [SnackBar] with optional tone styling.
extension MessageSnackBar on BuildContext {
  /// Shows [message] in a [SnackBar] via this context's nearest
  /// [ScaffoldMessenger], formatted according to [tone].
  void showMessageSnackBar(
    String message, {
    MessageTone tone = MessageTone.neutral,
  }) {
    final SnackBar snackBar;
    switch (tone) {
      case MessageTone.neutral:
        snackBar = SnackBar(content: Text(message));
      case MessageTone.success:
        snackBar = SnackBar(
          backgroundColor: AppColors.sage,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Color(0xFFF2F0E4)),
          ),
        );
      case MessageTone.muted:
        snackBar = SnackBar(
          backgroundColor: AppColors.snackbarMutedBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.hairlineDivider),
          ),
          content: Text(
            message,
            style: const TextStyle(color: AppColors.inkDimmed),
          ),
        );
    }
    ScaffoldMessenger.of(this).showSnackBar(snackBar);
  }
}
