import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_shadows.dart';

/// The app's on/off switch, defined by `Cairn Notifications.dc.html` (its
/// header comment calls it out as a genuinely new shared component: nothing
/// in the design corpus had a switch before, and New Habit's monthly-mode
/// control is a segmented pill, a different thing).
///
/// A 46x28 track with a 22px parchment knob: OFF is a flat recessed muted
/// fill, ON is the sage gradient. Sage because in this design language sage
/// means "on / yours / live".
///
/// Deliberately not Material's `Switch`, for the same reason no other
/// control in this app is a stock Material widget - it would bring its own
/// sizing, ripple, thumb elevation and colour scheme, none of which match.
///
/// The design's `inset` shadows (a 1px white top bevel on ON, a 2px recess
/// on OFF) are not reproduced: Flutter's `BoxShadow` has no inset variant,
/// and at 28px tall neither reads. This follows the precedent set by the
/// segmented pill in `new_habit_recurrence_panel.dart`, which renders its
/// own inset track as a flat translucent fill; see `AppShadows`' header
/// comment for the general note on this deviation.
///
/// [onChanged] null renders the switch non-interactive but does NOT dim it -
/// the two rows that can be disabled on the Notifications screen are dimmed
/// by their own row wrapper, so the whole row (label, subtitle and switch)
/// fades together rather than the switch fading twice.
class CairnSwitch extends StatelessWidget {
  const CairnSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;

  /// Called with the value the switch would move to. Null disables it.
  final ValueChanged<bool>? onChanged;

  /// Announced by screen readers in place of the bare on/off state. Usually
  /// the label of the row the switch sits in.
  final String? semanticLabel;

  static const double _trackWidth = 46;
  static const double _trackHeight = 28;
  static const double _knobSize = 22;
  static const double _knobInset = 3;

  @override
  Widget build(BuildContext context) {
    final changed = onChanged;
    return Semantics(
      toggled: value,
      enabled: changed != null,
      label: semanticLabel,
      child: GestureDetector(
        onTap: changed == null ? null : () => changed(!value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: _trackWidth,
          height: _trackHeight,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: _knobInset),
          alignment: value
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          decoration: BoxDecoration(
            color: value ? null : AppColors.switchTrackOff,
            gradient: value ? AppGradients.switchTrackOn : null,
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            boxShadow: value ? AppShadows.switchTrackOn : null,
          ),
          child: Container(
            width: _knobSize,
            height: _knobSize,
            decoration: BoxDecoration(
              color: AppColors.switchKnob,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  // rgba(45,38,26,.35) on, .28 off - the design gives the ON
                  // knob the slightly heavier shadow.
                  color: const Color(0xFF2D261A).withValues(alpha: value ? 0.35 : 0.28),
                  offset: const Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
