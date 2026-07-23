import 'package:flutter/material.dart'
    show InputDecoration, TextField, TextInputAction;
import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'account_chrome.dart';

/// The single reusable email input used across every account-flow screen
/// that needs one (Create account, Sign in): a labeled parchment field,
/// with an optional inline error row underneath.
class EmailField extends StatelessWidget {
  const EmailField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.error,
    this.enabled = true,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;

  /// Rendered below the field when non-null; the field's own border tints
  /// to [AppColors.accountFieldErrorBorder] whenever this is non-null.
  final Widget? error;

  final bool enabled;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.accountFieldLabel),
        const SizedBox(height: 8),
        AccountFieldSurface(
          hasError: error != null,
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            textInputAction: textInputAction,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: AppTextStyles.accountFieldInput,
            decoration: InputDecoration.collapsed(
              hintText: hintText,
              hintStyle: AppTextStyles.accountFieldInput.copyWith(
                color: AppColors.accountPlaceholderText,
              ),
            ),
          ),
        ),
        if (error != null) error!,
      ],
    );
  }
}
