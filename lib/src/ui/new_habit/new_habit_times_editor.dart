import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../../l10n/date_number_formatting.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/card_surface.dart';
import '../widgets/plus_glyph.dart';
import '../widgets/status_chip.dart' show CloseGlyph;

/// Builds a "HH:mm" 24-hour string into a throwaway [DateTime] purely so
/// [formatTimeOfDay] (which formats a `DateTime`'s time-of-day component)
/// can render it in the locale's preferred 12/24-hour convention. Only the
/// hour/minute are meaningful; the date fields are arbitrary and unused -
/// the same technique `home_occurrence_card.dart`'s private `_timeOfDay`
/// helper uses for the same reason.
DateTime timeOfDayFromHHmm(String hhmm) {
  final parts = hhmm.split(':');
  return DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
}

/// Adds [hhmm] to [times], deduped and kept sorted ascending. Lexical
/// sorting of zero-padded 24-hour "HH:mm" strings is equivalent to
/// chronological order, so a plain `sort()` is enough - no need to parse
/// hour/minute out again.
///
/// Returns [times] unchanged (a no-op, not a copy with a duplicate
/// appended) if [hhmm] is already present: re-picking a time equal to an
/// existing slot on the New Habit screen is treated as a silent no-op
/// rather than surfacing `TaskRepository.createTask`'s own
/// no-duplicate-dueTimes validation error after the fact - the same
/// "make invalid input hard to express" principle as every other control
/// on this screen.
List<String> addDueTime(List<String> times, String hhmm) {
  if (times.contains(hhmm)) return times;
  return [...times, hhmm]..sort();
}

/// The due-times editor shared by every New Habit recurrence variant
/// (`Cairn New Habit.dc.html`'s "Times of day" list; reused capped at one
/// slot for `Cairn New Habit - Once.dc.html`'s singular "Time of day"): a
/// row per configured "HH:mm" slot (clock icon, formatted time, a remove
/// control) plus a dashed "+ Add a time" affordance when [canAddMore].
class NewHabitTimesEditor extends StatelessWidget {
  const NewHabitTimesEditor({
    super.key,
    required this.sectionLabel,
    required this.helperText,
    required this.times,
    required this.canAddMore,
    required this.addTimeLabel,
    required this.onAddTime,
    required this.onRemoveTime,
    required this.locale,
  });

  final String sectionLabel;
  final String helperText;
  final List<String> times;
  final bool canAddMore;
  final String addTimeLabel;
  final VoidCallback onAddTime;
  final void Function(int index) onRemoveTime;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(sectionLabel, style: AppTextStyles.formSectionLabel),
        const SizedBox(height: 4),
        Text(helperText, style: AppTextStyles.formHelperText),
        const SizedBox(height: 11),
        for (var i = 0; i < times.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _TimeSlotRow(
            key: ValueKey('time-slot-$i'),
            label: formatTimeOfDay(timeOfDayFromHHmm(times[i]), locale),
            onRemove: () => onRemoveTime(i),
          ),
        ],
        if (canAddMore) ...[
          if (times.isNotEmpty) const SizedBox(height: 10),
          _AddTimeRow(label: addTimeLabel, onTap: onAddTime),
        ],
      ],
    );
  }
}

class _TimeSlotRow extends StatelessWidget {
  const _TimeSlotRow({super.key, required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ParchmentPill(
      radius: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CustomPaint(painter: _SlotClockGlyphPainter()),
              ),
              const SizedBox(width: 11),
              Text(label, style: AppTextStyles.taskTitle.copyWith(fontSize: 18)),
            ],
          ),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsetsDirectional.all(2),
              child: CloseGlyph(color: AppColors.textInactive, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small clock glyph (circle + hands) matching the times-editor slot rows'
/// SVG (`stroke:#7a7062`), sized for an 18px box. Distinct from
/// `status_chip.dart`'s private `_ClockGlyph` (not reusable from outside
/// that file) and from `verification_chrome.dart`'s [SealClockIcon]
/// (styled for the much larger seal icon).
class _SlotClockGlyphPainter extends CustomPainter {
  const _SlotClockGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.clockGlyph
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - paint.strokeWidth / 2;
    canvas.drawCircle(center, radius, paint);
    final path = Path()
      ..moveTo(center.dx, center.dy - radius * 0.55)
      ..lineTo(center.dx, center.dy)
      ..lineTo(center.dx + radius * 0.5, center.dy + radius * 0.35);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SlotClockGlyphPainter oldDelegate) => false;
}

class _AddTimeRow extends StatelessWidget {
  const _AddTimeRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: CustomPaint(
            painter: const _DashedRRectPainter(
              color: AppColors.scheduledPillBorder,
              radius: 20,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsetsDirectional.symmetric(vertical: 13),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppColors.addTimeIconBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const PlusGlyph(color: AppColors.textMuted, fontSize: 15),
                  ),
                  const SizedBox(width: 8),
                  Text(label, style: AppTextStyles.recurrenceChipLabel),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded-rectangle border, matching the "+ Add a time" row's
/// `border:1.5px dashed rgba(120,108,88,.4)`. A rectangular sibling to
/// `ghost_cairn.dart`'s private `_DashedPebblePainter` (which draws a
/// stadium/pebble shape, not a fixed-radius rect), so kept separate rather
/// than shared.
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dashLength = 4;
  static const double _gapLength = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashLength;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}
