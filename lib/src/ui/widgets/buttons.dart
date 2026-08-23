import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// Size variant for [PrimaryButton], matching the terracotta-gradient
/// button treatments in the designs: a large full-width footer CTA
/// ("Done", "Retake photo", "Go unlimited", "Back to Today"), a small
/// inline CTA on a task card ("Prove it"), and a medium content-sized CTA
/// (the Empty Today "+ New habit" button - `padding:14px 22px;
/// border-radius:24px; font-size:15px`, otherwise identical treatment to
/// [large], including its drop shadow).
enum PrimaryButtonSize { large, medium, small }

/// Which gradient fill [PrimaryButton] paints. Terracotta is the app's
/// default primary-action colour everywhere; sage is the Phase 4b
/// account-flow screens' own CTA colour (Create account / Sign in / Verify
/// / Save password / Keep this device's trail); delete is the deeper clay
/// CTA colour for destructive account deletion.
enum PrimaryButtonColor { terracotta, sage, delete }

/// The gradient primary action button. One widget, three sizes (see
/// [PrimaryButtonSize]) and three colours (see [PrimaryButtonColor]); [icon],
/// when given, is laid out before [label] the way every gradient button in
/// the designs pairs a small glyph with its text.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = PrimaryButtonSize.large,
    this.color = PrimaryButtonColor.terracotta,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final PrimaryButtonSize size;
  final PrimaryButtonColor color;
  final Widget? icon;

  /// Whether the button fills the available width (the large footer CTAs
  /// always do; the small inline "Prove it" CTA sizes to its content).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final double radius;
    final TextStyle textStyle;
    final EdgeInsetsGeometry padding;
    switch (size) {
      case PrimaryButtonSize.large:
        radius = AppRadii.buttonLarge;
        textStyle = AppTextStyles.buttonLabelLarge;
        padding = const EdgeInsetsDirectional.symmetric(vertical: 17);
      case PrimaryButtonSize.medium:
        radius = AppRadii.buttonMedium;
        textStyle = AppTextStyles.buttonLabelMedium;
        padding = const EdgeInsetsDirectional.symmetric(
          horizontal: 22,
          vertical: 14,
        );
      case PrimaryButtonSize.small:
        radius = AppRadii.buttonSmall;
        textStyle = AppTextStyles.buttonLabelSmall;
        padding = const EdgeInsetsDirectional.symmetric(
          horizontal: 18,
          vertical: 11,
        );
    }

    final isSmall = size == PrimaryButtonSize.small;
    final shadows = switch (color) {
      PrimaryButtonColor.sage =>
        isSmall ? AppShadows.sageButtonSmall : AppShadows.sageButtonLarge,
      PrimaryButtonColor.delete =>
        isSmall ? AppShadows.deleteButtonSmall : AppShadows.deleteButtonLarge,
      PrimaryButtonColor.terracotta =>
        isSmall ? AppShadows.buttonSmall : AppShadows.buttonLarge,
    };
    final gradient = switch (color) {
      PrimaryButtonColor.sage => AppGradients.sageButton,
      PrimaryButtonColor.delete => AppGradients.deleteButton,
      PrimaryButtonColor.terracotta => AppGradients.terracottaButton,
    };

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
          gradient: gradient,
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
///
/// Every button label ([PrimaryButton], [TintedPillButton],
/// [TextGhostButton]) routes through here, so this is also the one place
/// that gives all three a `Material` ancestor: buttons get dropped into
/// whichever screen a later run builds, and must not depend on that caller
/// remembering one (without it, `Text` falls back to MaterialApp's
/// deliberately-ugly red/yellow-underlined debug style - see AppShell's
/// build() comment). `MaterialType.transparency` fixes text inheritance
/// without painting anything of its own, so it can't cover the button's own
/// gradient/fill.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && mounted) {
      setState(() => _pressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_pressed && mounted) {
      setState(() => _pressed = false);
    }
  }

  void _handleTapCancel() {
    if (_pressed && mounted) {
      setState(() => _pressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        enabled: enabled,
        child: MouseRegion(
          cursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: widget.onPressed,
            onTapDown: enabled ? _handleTapDown : null,
            onTapUp: enabled ? _handleTapUp : null,
            onTapCancel: enabled ? _handleTapCancel : null,
            behavior: HitTestBehavior.opaque,
            child: AnimatedScale(
              scale: (enabled && _pressed) ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutCubic,
              child: Opacity(
                opacity: enabled ? 1.0 : 0.5,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
