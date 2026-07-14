import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/buttons.dart';
import '../widgets/ghost_cairn.dart';
import '../widgets/plus_glyph.dart';

/// The "no tasks at all" state (`Cairn Empty Today.dc.html`): a dashed
/// ghost cairn, a title/body pair, and a CTA to add the first habit.
///
/// Centered in whatever space is left below the greeting, matching the
/// source file's `flex:1;display:flex;flex-direction:column;
/// align-items:center;justify-content:center`.
class EmptyTodayView extends StatelessWidget {
  const EmptyTodayView({super.key, required this.onNewHabit});

  final VoidCallback onNewHabit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 40),
      // The source file's flex container is a block-level div, so
      // `align-items:center` centers its children against the *full* width
      // handed to it, not against the width of its widest child. A bare
      // `Column` here would do the latter - since nothing above it stretches
      // it (this screen's outer Column is `crossAxisAlignment.start`), it
      // sizes itself to its widest child (the title, wider than the 260px
      // body/button) and centers everything *inside that*, which visually
      // reads as the title hugging the left edge while the narrower body
      // and button look indented/centered relative to it. `double.infinity`
      // forces this Column to the full width its parent offers first, so
      // `CrossAxisAlignment.center` then centers every child - including
      // the title - against that same full width, matching the design.
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const GhostCairnStack(),
            const SizedBox(height: 30),
            Text(
              l10n.emptyTodayTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.emptyStateTitle,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 260,
              child: Text(
                l10n.emptyTodayBody,
                textAlign: TextAlign.center,
                style: AppTextStyles.emptyStateBody,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: l10n.newHabitButton,
              onPressed: onNewHabit,
              size: PrimaryButtonSize.medium,
              expand: false,
              icon: const PlusGlyph(color: AppColors.buttonText, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
