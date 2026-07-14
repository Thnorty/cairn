import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// Size variant for [PrimaryButton], matching the two terracotta-gradient
/// button treatments in the designs: a large full-width footer CTA
/// ("Done", "Retake photo", "Go unlimited", "Back to Today") and a small
/// inline CTA on a task card ("Prove it").
enum PrimaryButtonSize { large, small }

/// The terracotta gradient primary action button. One widget, two sizes
/// (see [PrimaryButtonSize]); [icon], when given, is laid out before
/// [label] the way every gradient button in the designs pairs a small
/// glyph with its text.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = PrimaryButtonSize.large,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final PrimaryButtonSize size;
  final Widget? icon;

  /// Whether the button fills the available width (the large footer CTAs
  /// always do; the small inline "Prove it" CTA sizes to its content).
  final bool expand;

  bool get _isLarge => size == PrimaryButtonSize.large;

  @override
  Widget build(BuildContext context) {
    final radius = _isLarge ? AppRadii.buttonLarge : AppRadii.buttonSmall;
    final textStyle = _isLarge
        ? AppTextStyles.buttonLabelLarge
        : AppTextStyles.buttonLabelSmall;
    final padding = _isLarge
        ? const EdgeInsetsDirectional.symmetric(vertical: 17)
        : const EdgeInsetsDirectional.symmetric(horizontal: 18, vertical: 11);
    final shadows = _isLarge
        ? AppShadows.buttonLarge
        : AppShadows.buttonSmall;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 8)],
        Text(label, style: textStyle),
      ],
    );

    return _Pressable(
      onPressed: onPressed,
      child: Container(
        width: expand ? double.infinity : null,
        padding: padding,
        decoration: BoxDecoration(
          gradient: AppGradients.terracottaButton,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadows,
          border: Border.all(
            color: AppColors.buttonInsetHighlight,
            width: 0.5,
          ),
        ),
        child: content,
      ),
    );
  }
}

/// The terracotta-tinted ghost pill ("New habit" in the Home app bar):
/// translucent terracotta fill, a matching border, no gradient/shadow.
class TintedPillButton extends StatelessWidget {
  const TintedPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.terracottaTintBg,
          border: Border.all(color: AppColors.terracottaTintBorder, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(11, 7, 13, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 6)],
              Text(label, style: AppTextStyles.tintedPillLabel),
            ],
          ),
        ),
      ),
    );
  }
}

/// The plain text/ghost button ("Cancel", "Maybe later"): no fill, no
/// border, just muted label text.
class TextGhostButton extends StatelessWidget {
  const TextGhostButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(6),
        child: Text(label, style: AppTextStyles.textGhostButtonLabel),
      ),
    );
  }
}

/// Shared tap/disabled handling for the button family above: none of the
/// designs show a Material ripple, so this is a plain tap target (dimmed
/// and inert when [onPressed] is null) rather than an `InkWell`.
class _Pressable extends StatelessWidget {
  const _Pressable({required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: onPressed,
          child: Opacity(opacity: enabled ? 1 : 0.5, child: child),
        ),
      ),
    );
  }
}
