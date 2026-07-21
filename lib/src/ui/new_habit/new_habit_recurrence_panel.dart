import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../../db/database.dart' show MonthlyMode;
import '../../l10n/date_number_formatting.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_text_styles.dart';
import '../widgets/card_surface.dart';
import 'monthly_ordinal.dart';

/// The 2x2 "How often?" recurrence-type selector shared by every New Habit
/// variant (`Cairn New Habit.dc.html` and its Once/Monthly siblings): cell
/// order (Once, Daily / Weekly, Monthly) matches every source file's DOM
/// order identically.
class RecurrenceTypeGrid extends StatelessWidget {
  const RecurrenceTypeGrid({
    super.key,
    required this.onceLabel,
    required this.dailyLabel,
    required this.weeklyLabel,
    required this.monthlyLabel,
    required this.selected,
    required this.onSelect,
  });

  final String onceLabel;
  final String dailyLabel;
  final String weeklyLabel;
  final String monthlyLabel;

  /// Which recurrence type index (0=once, 1=daily, 2=weekly, 3=monthly) is
  /// currently active. Plain ints (not `RecurrenceType` directly) so this
  /// widget stays presentational and doesn't need to import the db enum's
  /// full ordering assumptions - the caller maps to/from `RecurrenceType`.
  final int selected;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) {
    final labels = [onceLabel, dailyLabel, weeklyLabel, monthlyLabel];
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _chip(0, labels[0])),
            const SizedBox(width: 9),
            Expanded(child: _chip(1, labels[1])),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(child: _chip(2, labels[2])),
            const SizedBox(width: 9),
            Expanded(child: _chip(3, labels[3])),
          ],
        ),
      ],
    );
  }

  Widget _chip(int index, String label) {
    return _RecurrenceChip(
      key: ValueKey('recurrence-chip-$index'),
      label: label,
      active: selected == index,
      onTap: () => onSelect(index),
    );
  }
}

class _RecurrenceChip extends StatelessWidget {
  const _RecurrenceChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  /// `0 8px 15px -7px rgba(45,38,26,.55), inset 0 1px 0 rgba(255,255,255,.14)`
  static const _activeShadow = [
    BoxShadow(
      color: Color(0x8C2D261A),
      offset: Offset(0, 8),
      blurRadius: 15,
      spreadRadius: -7,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.inkStrong : null,
              gradient: active ? null : AppGradients.chipInactive,
              borderRadius: BorderRadius.circular(20),
              border: active ? null : Border.all(color: AppColors.cardBorder),
              boxShadow: active ? _activeShadow : null,
            ),
            child: Text(
              label,
              style: AppTextStyles.recurrenceChipLabel.copyWith(
                color: active ? AppColors.darkChipText : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sage-tinted panel wrapping each recurrence type's extra controls
/// (`background:rgba(122,141,96,.1);border-radius:24px;
/// border:1px solid rgba(122,141,96,.18)`), shared by [WeeklyDayPanel],
/// [MonthlyPanel] and [OnceDatePanel].
class _SagePanel extends StatelessWidget {
  const _SagePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.sagePanelBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sageRing),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// A day-of-week/day-of-month toggle circle, shared by [WeeklyDayPanel]'s
/// day-of-week row, [MonthlyPanel]'s day-of-month grid, and its
/// nth-weekday mode's own day-of-week row: a plain sage-filled circle when
/// [selected], an outlined parchment circle otherwise.
class DayCircle extends StatelessWidget {
  const DayCircle({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.fontSize = 14,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: selected ? AppGradients.sageCircleSelected : AppGradients.circleInactive,
                shape: BoxShape.circle,
                border: selected ? null : Border.all(color: AppColors.circleBorder),
                boxShadow: selected
                    ? const [
                        BoxShadow(
                          color: AppColors.selectedCircleShadow,
                          offset: Offset(0, 4),
                          blurRadius: 8,
                          spreadRadius: -4,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFontFamilies.workSans,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSize,
                    color: selected ? AppColors.sageChipText : AppColors.textFaint,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Weekly recurrence panel (`Cairn New Habit.dc.html`'s "On these
/// days" picker): a Sunday-first row of seven [DayCircle]s (matching that
/// file's literal "S M T W T F S" order), toggling ISO weekdays (1=Mon..
/// 7=Sun) independently.
class WeeklyDayPanel extends StatelessWidget {
  const WeeklyDayPanel({
    super.key,
    required this.label,
    required this.selectedDays,
    required this.onToggleDay,
    required this.locale,
  });

  final String label;

  /// ISO weekdays (1=Mon..7=Sun) currently selected.
  final Set<int> selectedDays;
  final void Function(int isoWeekday) onToggleDay;
  final Locale locale;

  /// Sunday-first display order (ISO weekday numbers), matching the
  /// design's literal "S M T W T F S" row.
  static const _displayOrder = [7, 1, 2, 3, 4, 5, 6];

  @override
  Widget build(BuildContext context) {
    return _SagePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.panelSubLabel),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final isoWeekday in _displayOrder) ...[
                if (isoWeekday != _displayOrder.first) const SizedBox(width: 6),
                Expanded(
                  child: DayCircle(
                    key: ValueKey('weekday-circle-$isoWeekday'),
                    label: narrowWeekdayLabel(isoWeekday, locale),
                    selected: selectedDays.contains(isoWeekday),
                    onTap: () => onToggleDay(isoWeekday),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The Monthly recurrence panel, both sub-modes
/// (`Cairn New Habit - Monthly.dc.html` / `Cairn New Habit - Monthly 3rd
/// Weekday.dc.html`): the mode toggle up top, then either the 1-31
/// day-of-month grid or the "Which week" / "Which day" nth-weekday
/// pickers, matching whichever [mode] is active.
class MonthlyPanel extends StatelessWidget {
  const MonthlyPanel({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.dayToggleLabel,
    required this.nthWeekdayToggleLabel,
    required this.dayOfTheMonthLabel,
    required this.clampHelpText,
    required this.monthDay,
    required this.onMonthDayChanged,
    required this.whichWeekLabel,
    required this.whichDayLabel,
    required this.monthNth,
    required this.onMonthNthChanged,
    required this.lastLabel,
    required this.monthWeekday,
    required this.onMonthWeekdayChanged,
    required this.locale,
  });

  final MonthlyMode mode;
  final void Function(MonthlyMode mode) onModeChanged;

  /// "On the {day}" summary of the current [monthDay], pre-formatted.
  final String dayToggleLabel;

  /// "On the {nth} {weekday}" summary of the current [monthNth]/
  /// [monthWeekday], pre-formatted.
  final String nthWeekdayToggleLabel;

  final String dayOfTheMonthLabel;
  final String clampHelpText;
  final int monthDay;
  final void Function(int day) onMonthDayChanged;

  final String whichWeekLabel;
  final String whichDayLabel;
  final int monthNth;
  final void Function(int nth) onMonthNthChanged;
  final String lastLabel;
  final int monthWeekday;
  final void Function(int isoWeekday) onMonthWeekdayChanged;

  final Locale locale;

  /// Monday-first ISO weekday order for the nth-weekday mode's "Which day"
  /// row, matching `Cairn New Habit - Monthly 3rd Weekday.dc.html`'s
  /// literal "M T W T F S S" order (distinct from [WeeklyDayPanel]'s
  /// Sunday-first order, taken verbatim from each file).
  static const _weekdayDisplayOrder = [1, 2, 3, 4, 5, 6, 7];

  static const List<int> _validMonthNths = [1, 2, 3, 4, -1];

  @override
  Widget build(BuildContext context) {
    return _SagePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ModeToggle(
            dayLabel: dayToggleLabel,
            nthWeekdayLabel: nthWeekdayToggleLabel,
            mode: mode,
            onSelect: onModeChanged,
          ),
          const SizedBox(height: 16),
          if (mode == MonthlyMode.dayOfMonth) ...[
            Text(dayOfTheMonthLabel, style: AppTextStyles.panelSubLabel),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
              children: [
                for (var day = 1; day <= 31; day++)
                  DayCircle(
                    key: ValueKey('month-day-circle-$day'),
                    label: '$day',
                    fontSize: 12.5,
                    selected: monthDay == day,
                    onTap: () => onMonthDayChanged(day),
                  ),
              ],
            ),
            const SizedBox(height: 11),
            _ClampNote(text: clampHelpText),
          ] else ...[
            Text(whichWeekLabel, style: AppTextStyles.panelSubLabel),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final nth in _validMonthNths) ...[
                  if (nth != _validMonthNths.first) const SizedBox(width: 6),
                  Expanded(
                    child: _WeekOrdinalChip(
                      key: ValueKey('month-nth-chip-$nth'),
                      label: nth == -1 ? lastLabel : englishOrdinal(nth),
                      selected: monthNth == nth,
                      onTap: () => onMonthNthChanged(nth),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(whichDayLabel, style: AppTextStyles.panelSubLabel),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final isoWeekday in _weekdayDisplayOrder) ...[
                  if (isoWeekday != _weekdayDisplayOrder.first) const SizedBox(width: 6),
                  Expanded(
                    child: DayCircle(
                      key: ValueKey('month-weekday-circle-$isoWeekday'),
                      label: narrowWeekdayLabel(isoWeekday, locale),
                      fontSize: 13,
                      selected: monthWeekday == isoWeekday,
                      onTap: () => onMonthWeekdayChanged(isoWeekday),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ClampNote extends StatelessWidget {
  const _ClampNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsetsDirectional.only(top: 1),
          child: SizedBox(
            width: 14,
            height: 14,
            child: CustomPaint(painter: _InfoDotPainter()),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(child: Text(text, style: AppTextStyles.formFinePrint)),
      ],
    );
  }
}

/// The small circle+stem+dot info glyph beside [_ClampNote]'s text
/// (`<circle r="9"/><path d="M12 11v5"/><circle r="0.4"/>`), matching the
/// design's info icon at a smaller size than
/// `verification_chrome.dart`'s [ReasonBanner] uses for the same motif.
class _InfoDotPainter extends CustomPainter {
  const _InfoDotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.textFaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - stroke.strokeWidth / 2;
    canvas.drawCircle(center, radius, stroke);
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.1),
      Offset(center.dx, center.dy + radius * 0.55),
      stroke,
    );
    canvas.drawCircle(Offset(center.dx, center.dy - radius * 0.55), 0.5, Paint()..color = AppColors.textFaint);
  }

  @override
  bool shouldRepaint(_InfoDotPainter oldDelegate) => false;
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.dayLabel,
    required this.nthWeekdayLabel,
    required this.mode,
    required this.onSelect,
  });

  final String dayLabel;
  final String nthWeekdayLabel;
  final MonthlyMode mode;
  final void Function(MonthlyMode mode) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(4),
      decoration: BoxDecoration(
        color: AppColors.pillToggleTrackBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleSegment(
              key: const ValueKey('monthly-mode-day'),
              label: dayLabel,
              active: mode == MonthlyMode.dayOfMonth,
              onTap: () => onSelect(MonthlyMode.dayOfMonth),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _ToggleSegment(
              key: const ValueKey('monthly-mode-nth-weekday'),
              label: nthWeekdayLabel,
              active: mode == MonthlyMode.nthWeekday,
              onTap: () => onSelect(MonthlyMode.nthWeekday),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  /// `0 3px 7px -4px rgba(60,50,35,.4)`
  static const _activeShadow = [
    BoxShadow(
      color: Color(0x663C3223),
      offset: Offset(0, 3),
      blurRadius: 7,
      spreadRadius: -4,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 9, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: active ? AppGradients.pillToggleActive : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: active ? _activeShadow : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFontFamilies.workSans,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: active ? AppColors.inkPrimary : AppColors.textFaint,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekOrdinalChip extends StatelessWidget {
  const _WeekOrdinalChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 10, horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: selected ? AppGradients.sageCircleSelected : AppGradients.circleInactive,
              borderRadius: BorderRadius.circular(14),
              border: selected ? null : Border.all(color: AppColors.circleBorder),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: AppColors.selectedCircleShadow,
                        offset: Offset(0, 4),
                        blurRadius: 8,
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFontFamilies.workSans,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? AppColors.sageChipText : AppColors.textFaint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Once recurrence panel (`Cairn New Habit - Once.dc.html`'s "On this
/// date" picker row): a tappable [ParchmentPill] row showing the currently
/// chosen date, opening a date picker via [onTap] (owned by the parent
/// screen, which needs a `BuildContext`/`showDatePicker`, not this
/// presentational widget).
class OnceDatePanel extends StatelessWidget {
  const OnceDatePanel({
    super.key,
    required this.label,
    required this.dateText,
    required this.onTap,
  });

  final String label;
  final String dateText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SagePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.panelSubLabel),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: ParchmentPill(
              radius: 18,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CustomPaint(painter: _CalendarGlyphPainter()),
                      ),
                      const SizedBox(width: 11),
                      Text(dateText, style: AppTextStyles.taskTitle.copyWith(fontSize: 18)),
                    ],
                  ),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CustomPaint(painter: _ChevronRightPainter()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small calendar glyph (rounded rect + two top tabs + header rule),
/// matching the Once panel's date-row SVG: a rounded rect body plus a
/// header rule and two short vertical tabs at the top.
class _CalendarGlyphPainter extends CustomPainter {
  const _CalendarGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.clockGlyph
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4 * w, 5 * h, 16 * w, 16 * h),
        Radius.circular(3 * w),
      ),
      stroke,
    );
    canvas.drawLine(Offset(4 * w, 9 * h), Offset(20 * w, 9 * h), stroke);
    canvas.drawLine(Offset(8 * w, 3 * h), Offset(8 * w, 7 * h), stroke);
    canvas.drawLine(Offset(16 * w, 3 * h), Offset(16 * w, 7 * h), stroke);
  }

  @override
  bool shouldRepaint(_CalendarGlyphPainter oldDelegate) => false;
}

/// Small chevron-right glyph (`M9 6l6 6-6 6`), matching the Once panel's
/// date-row trailing affordance.
class _ChevronRightPainter extends CustomPainter {
  const _ChevronRightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.textFaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;
    canvas.drawPath(
      Path()
        ..moveTo(9 * w, 6 * h)
        ..lineTo(15 * w, 12 * h)
        ..lineTo(9 * w, 18 * h),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_ChevronRightPainter oldDelegate) => false;
}
