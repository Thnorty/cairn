import 'package:flutter/widgets.dart';

import '../theme/app_text_styles.dart';

/// The small "+" glyph paired with every "New habit" CTA in the designs
/// (the header's tinted pill and the Empty Today CTA alike): plain bold
/// text rather than an icon font, matching the source files'
/// `<span style="font-size:...">+</span>`.
class PlusGlyph extends StatelessWidget {
  const PlusGlyph({super.key, required this.color, this.fontSize = 15});

  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      '+',
      style: TextStyle(
        // Explicit, not inherited: every other text style in this app
        // hardcodes its own fontFamily via an AppTextStyles token rather
        // than relying on MaterialApp's ambient theme font, and this needs
        // to too - without it, this glyph silently renders as a "missing
        // glyph" box in any host that hasn't set `theme: AppTheme.light`
        // (every current widget test, and the screenshot harness, since
        // neither wires a theme - only main.dart's real CairnApp does).
        // Caught by the screenshot harness: the "+" rendered as a solid
        // square instead of a plus sign until this was added.
        fontFamily: AppFontFamilies.workSans,
        fontSize: fontSize,
        height: 1,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}
