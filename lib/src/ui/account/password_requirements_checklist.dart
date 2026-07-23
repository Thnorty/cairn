import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../services/account_policy.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Frame 2 of `Cairn Account - Forgot Password & Rules.dc.html`: live
/// password-requirements checklist updating on every keystroke.
///
/// Renders 4 rules (min length, uppercase, lowercase, digit). MET rules
/// show a sage check inside a sage-tinted circle with sage text; UNMET
/// rules show a clay cross inside a clay-tinted circle with clay text.
class PasswordRequirementsChecklist extends StatelessWidget {
  const PasswordRequirementsChecklist({
    super.key,
    required this.password,
  });

  final String password;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final rules = [
      _RuleItem(
        label: l10n.accountRuleMinLength,
        isMet: passwordHasMinLength(password),
      ),
      _RuleItem(
        label: l10n.accountRuleUppercase,
        isMet: passwordHasUppercase(password),
      ),
      _RuleItem(
        label: l10n.accountRuleLowercase,
        isMet: passwordHasLowercase(password),
      ),
      _RuleItem(
        label: l10n.accountRuleDigit,
        isMet: passwordHasDigit(password),
      ),
    ];

    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rules.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            _RequirementRow(
              label: rules[i].label,
              isMet: rules[i].isMet,
            ),
          ],
        ],
      ),
    );
  }
}

class _RuleItem {
  const _RuleItem({required this.label, required this.isMet});
  final String label;
  final bool isMet;
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.label, required this.isMet});

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMet
                ? AppColors.accountRuleSageCircleBg
                : AppColors.accountRuleClayCircleBg,
          ),
          alignment: Alignment.center,
          child: SizedBox(
            width: 10,
            height: 10,
            child: CustomPaint(
              painter: isMet
                  ? const _CheckGlyphPainter(color: AppColors.sageText)
                  : const _CrossGlyphPainter(
                      color: AppColors.accountFieldErrorIcon,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFontFamilies.workSans,
            fontSize: 12.5,
            color: isMet ? AppColors.sageText : AppColors.terracotta,
          ),
        ),
      ],
    );
  }
}

class _CheckGlyphPainter extends CustomPainter {
  const _CheckGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 24;
    final h = size.height / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4 * w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(20 * w, 6 * h)
      ..lineTo(9 * w, 17 * h)
      ..lineTo(4 * w, 12 * h);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckGlyphPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _CrossGlyphPainter extends CustomPainter {
  const _CrossGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 24;
    final h = size.height / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * w
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(6 * w, 6 * h)
      ..lineTo(18 * w, 18 * h)
      ..moveTo(18 * w, 6 * h)
      ..lineTo(6 * w, 18 * h);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CrossGlyphPainter oldDelegate) =>
      color != oldDelegate.color;
}
