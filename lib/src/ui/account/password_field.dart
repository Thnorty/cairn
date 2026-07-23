import 'package:flutter/material.dart'
    show InputDecoration, Material, MaterialType, TextField, TextInputAction;
import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'account_chrome.dart';

/// The single reusable password input used across every account-flow
/// screen that needs one (Create account, Sign in, Set a new password): a
/// labeled parchment field with a working show/hide eye toggle, and an
/// optional inline error row underneath.
class PasswordField extends StatefulWidget {
  const PasswordField({
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
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTextStyles.accountFieldLabel),
        const SizedBox(height: 8),
        AccountFieldSurface(
          hasError: widget.error != null,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  enabled: widget.enabled,
                  obscureText: _obscure,
                  textInputAction: widget.textInputAction,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: AppTextStyles.accountFieldInput,
                  decoration: InputDecoration.collapsed(
                    hintText: widget.hintText,
                    hintStyle: AppTextStyles.accountFieldInput.copyWith(
                      color: AppColors.accountPlaceholderText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _EyeToggleButton(
                obscured: _obscure,
                onTap: () => setState(() => _obscure = !_obscure),
              ),
            ],
          ),
        ),
        if (widget.error != null) widget.error!,
      ],
    );
  }
}

class _EyeToggleButton extends StatelessWidget {
  const _EyeToggleButton({required this.obscured, required this.onTap});

  final bool obscured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        label: obscured ? 'Show password' : 'Hide password',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 19,
            height: 19,
            child: CustomPaint(painter: _EyeGlyphPainter(showSlash: !obscured)),
          ),
        ),
      ),
    );
  }
}

/// The eye / eye-with-slash toggle glyph, matching
/// `Cairn Account.dc.html`'s password show/hide icon: an eye outline
/// (`M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z`) with a
/// pupil circle (`cx=12 cy=12 r=3`), plus a diagonal slash line when the
/// password is shown (unobscured).
class _EyeGlyphPainter extends CustomPainter {
  const _EyeGlyphPainter({required this.showSlash});

  final bool showSlash;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textFaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;

    final path = Path()
      ..moveTo(2 * w, 12 * h)
      ..cubicTo(2 * w, 12 * h, 5.6 * w, 5.5 * h, 12 * w, 5.5 * h)
      ..cubicTo(18.4 * w, 5.5 * h, 22 * w, 12 * h, 22 * w, 12 * h)
      ..cubicTo(22 * w, 12 * h, 18.4 * w, 18.5 * h, 12 * w, 18.5 * h)
      ..cubicTo(5.6 * w, 18.5 * h, 2 * w, 12 * h, 2 * w, 12 * h)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(12 * w, 12 * h), 3 * w, paint);

    if (showSlash) {
      canvas.drawLine(
        Offset(4 * w, 3.5 * h),
        Offset(20 * w, 20.5 * h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EyeGlyphPainter oldDelegate) =>
      showSlash != oldDelegate.showSlash;
}
