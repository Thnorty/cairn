import 'package:flutter/material.dart'
    show
        Colors,
        InputBorder,
        InputDecoration,
        MaterialLocalizations,
        Scaffold,
        ScaffoldMessenger,
        SnackBar,
        TextField,
        TimeOfDay,
        showDatePicker,
        showTimePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../db/database.dart' show MonthlyMode, RecurrenceType;
import '../../l10n/date_number_formatting.dart';
import '../../models/local_date.dart';
import '../../providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/screen_background.dart';
import '../widgets/buttons.dart';
import '../widgets/card_surface.dart';
import 'monthly_ordinal.dart';
import 'new_habit_recurrence_panel.dart';
import 'new_habit_times_editor.dart';

/// `Cairn New Habit.dc.html` and its Once/Monthly siblings: one screen with
/// four recurrence-driven variants (once/daily/weekly/monthly), matching
/// how those four `.dc.html` files are four states of a single screen, not
/// four separate designs (see this run's spec).
///
/// Every field this screen captures maps directly onto
/// [TaskRepository.createTask]'s parameters; validation itself lives there
/// (see that method's `_validate`), not duplicated here - this screen's job
/// is only to make invalid input hard to *express* (fixed pickers instead
/// of free text for every recurrence-specific field) and to show a
/// graceful error if a validation exception still somehow reaches it.
class NewHabitScreen extends ConsumerStatefulWidget {
  const NewHabitScreen({super.key});

  @override
  ConsumerState<NewHabitScreen> createState() => _NewHabitScreenState();
}

class _NewHabitScreenState extends ConsumerState<NewHabitScreen> {
  final _titleController = TextEditingController();

  // Defaults to Daily: the only recurrence type with no extra required
  // fields, so the form starts in an always-valid state regardless of
  // which variant the base design file happens to illustrate (that file
  // shows Weekly selected purely to demonstrate the weekly picker itself).
  RecurrenceType _recurrenceType = RecurrenceType.daily;

  final Set<int> _weeklyDays = {};

  MonthlyMode _monthlyMode = MonthlyMode.dayOfMonth;
  late int _monthDay;
  int _monthNth = 1;
  late int _monthWeekday;

  late LocalDate _onceDate;

  List<String> _dueTimes = [];

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final today = ref.read(clockProvider).today();
    _monthDay = today.day;
    _monthWeekday = today.weekday;
    _onceDate = today;
    _titleController.addListener(_onTitleChanged);
  }

  void _onTitleChanged() => setState(() {});

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    super.dispose();
  }

  bool get _isValid {
    if (_titleController.text.trim().isEmpty) return false;
    if (_recurrenceType == RecurrenceType.weekly && _weeklyDays.isEmpty) {
      return false;
    }
    return true;
  }

  bool get _canAddMoreTimes =>
      _recurrenceType != RecurrenceType.once || _dueTimes.isEmpty;

  Future<void> _handleAddTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    final hhmm =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() => _dueTimes = addDueTime(_dueTimes, hhmm));
  }

  void _handleRemoveTime(int index) {
    setState(() => _dueTimes = [..._dueTimes]..removeAt(index));
  }

  Future<void> _handlePickOnceDate() async {
    final today = ref.read(clockProvider).today();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_onceDate.year, _onceDate.month, _onceDate.day),
      // A brand-new "once" task's due date can't be in the past: the
      // repository has no rule against it directly (no back-filling
      // governs completions, not task creation), but a one-off habit due
      // yesterday could never be proven, so the picker itself keeps this
      // impossible to express rather than accepting it and failing later.
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 5, today.month, today.day),
    );
    if (picked == null || !mounted) return;
    setState(() => _onceDate = LocalDate.of(picked));
  }

  Future<void> _handleCreate() async {
    if (!_isValid || _submitting) return;
    setState(() => _submitting = true);
    try {
      final clock = ref.read(clockProvider);
      final today = clock.today();
      final taskRepo = ref.read(taskRepositoryProvider);
      await taskRepo.createTask(
        title: _titleController.text.trim(),
        recurrenceType: _recurrenceType,
        weeklyDays: _recurrenceType == RecurrenceType.weekly
            ? (_weeklyDays.toList()..sort())
            : null,
        monthlyMode: _recurrenceType == RecurrenceType.monthly ? _monthlyMode : null,
        monthDay: _recurrenceType == RecurrenceType.monthly &&
                _monthlyMode == MonthlyMode.dayOfMonth
            ? _monthDay
            : null,
        monthNth: _recurrenceType == RecurrenceType.monthly &&
                _monthlyMode == MonthlyMode.nthWeekday
            ? _monthNth
            : null,
        monthWeekday: _recurrenceType == RecurrenceType.monthly &&
                _monthlyMode == MonthlyMode.nthWeekday
            ? _monthWeekday
            : null,
        dueDate: _recurrenceType == RecurrenceType.once ? _onceDate : null,
        dueTimes: _dueTimes,
        startDate: _recurrenceType == RecurrenceType.once ? _onceDate : today,
      );
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? error.toString())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ScreenBackground(
        washes: const [
          RadialGradient(
            center: Alignment(-0.64, -1.16),
            radius: 1.3,
            colors: [Color(0x33968368), Color(0x00968368)],
          ),
        ],
        child: SafeArea(
          child: Column(
            children: [
              _Header(title: l10n.newHabitScreenTitle),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(22, 12, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.whatAreYouProvingLabel, style: AppTextStyles.formSectionLabel),
                      const SizedBox(height: 9),
                      _TitleField(controller: _titleController),
                      const SizedBox(height: 22),
                      Text(l10n.howOftenLabel, style: AppTextStyles.formSectionLabel),
                      const SizedBox(height: 9),
                      RecurrenceTypeGrid(
                        onceLabel: l10n.recurrenceOnceLabel,
                        dailyLabel: l10n.recurrenceDailyLabel,
                        weeklyLabel: l10n.recurrenceWeeklyLabel,
                        monthlyLabel: l10n.recurrenceMonthlyLabel,
                        selected: RecurrenceType.values.indexOf(_recurrenceType),
                        onSelect: (index) => setState(() {
                          _recurrenceType = RecurrenceType.values[index];
                        }),
                      ),
                      ..._buildRecurrencePanel(l10n, locale),
                      const SizedBox(height: 22),
                      NewHabitTimesEditor(
                        sectionLabel: _recurrenceType == RecurrenceType.once
                            ? l10n.timeOfDayLabel
                            : l10n.timesOfDayLabel,
                        helperText: _recurrenceType == RecurrenceType.once
                            ? l10n.onceTimeHelpText
                            : l10n.timesOfDayHelpText,
                        times: _dueTimes,
                        canAddMore: _canAddMoreTimes,
                        addTimeLabel: l10n.addTimeButton,
                        onAddTime: _handleAddTime,
                        onRemoveTime: _handleRemoveTime,
                        locale: locale,
                      ),
                    ],
                  ),
                ),
              ),
              _Footer(
                label: l10n.createHabitButton,
                enabled: _isValid && !_submitting,
                onPressed: _handleCreate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRecurrencePanel(AppLocalizations l10n, Locale locale) {
    switch (_recurrenceType) {
      case RecurrenceType.daily:
        return const [];
      case RecurrenceType.weekly:
        return [
          const SizedBox(height: 16),
          WeeklyDayPanel(
            label: l10n.onTheseDaysLabel,
            selectedDays: _weeklyDays,
            onToggleDay: (day) => setState(() {
              if (!_weeklyDays.remove(day)) _weeklyDays.add(day);
            }),
            locale: locale,
          ),
        ];
      case RecurrenceType.monthly:
        final nthLabel = _monthNth == -1
            ? l10n.monthlyWeekLastLabel
            : englishOrdinal(_monthNth);
        return [
          const SizedBox(height: 16),
          MonthlyPanel(
            mode: _monthlyMode,
            onModeChanged: (mode) => setState(() => _monthlyMode = mode),
            dayToggleLabel: l10n.monthlyDayToggleLabel(englishOrdinal(_monthDay)),
            nthWeekdayToggleLabel: l10n.monthlyNthWeekdayToggleLabel(
              nthLabel,
              weekdayFullName(_monthWeekday, locale),
            ),
            dayOfTheMonthLabel: l10n.dayOfTheMonthLabel,
            clampHelpText: l10n.monthlyClampHelpText,
            monthDay: _monthDay,
            onMonthDayChanged: (day) => setState(() => _monthDay = day),
            whichWeekLabel: l10n.whichWeekLabel,
            whichDayLabel: l10n.whichDayLabel,
            monthNth: _monthNth,
            onMonthNthChanged: (nth) => setState(() => _monthNth = nth),
            lastLabel: l10n.monthlyWeekLastLabel,
            monthWeekday: _monthWeekday,
            onMonthWeekdayChanged: (day) => setState(() => _monthWeekday = day),
            locale: locale,
          ),
        ];
      case RecurrenceType.once:
        return [
          const SizedBox(height: 16),
          OnceDatePanel(
            label: l10n.onThisDateLabel,
            dateText: formatShortWeekdayMonthDay(_onceDate, locale),
            onTap: _handlePickOnceDate,
          ),
        ];
    }
  }
}

class _TitleField extends StatelessWidget {
  const _TitleField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ParchmentPill(
      radius: 22,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 18, vertical: 4),
      child: Row(
        children: [
          const _TitleFieldCairnGlyph(),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              style: AppTextStyles.taskTitle.copyWith(height: 1.2),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsetsDirectional.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The tiny 3-bar cairn silhouette beside the habit-title field
/// (`Cairn New Habit.dc.html`'s three stacked ellipses: 9x4/14x5/18x5,
/// sage/muted-tan/muted-tan), distinct from the full [CairnStack]/
/// [GhostCairnStack] motifs used elsewhere - a much simpler flattened
/// silhouette this one design uses only as a small field icon.
class _TitleFieldCairnGlyph extends StatelessWidget {
  const _TitleFieldCairnGlyph();

  static const _bars = [
    (width: 9.0, color: AppColors.sage),
    (width: 14.0, color: Color(0xFFB1A796)),
    (width: 18.0, color: Color(0xFFAEA491)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final bar in _bars)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 1),
            child: Container(
              width: bar.width,
              height: 5,
              decoration: BoxDecoration(color: bar.color, borderRadius: BorderRadius.circular(2.5)),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 16, 22, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _BackButton(onTap: () => Navigator.of(context).maybePop()),
          Text(title, style: AppTextStyles.taskTitle),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: GestureDetector(
        key: const ValueKey('back-button'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.awaitingChipBg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 17,
            height: 17,
            child: CustomPaint(painter: _BackChevronPainter()),
          ),
        ),
      ),
    );
  }
}

/// Back-chevron glyph (`M15 5l-7 7 7 7`), matching the New Habit header's
/// leading control across all four variants.
class _BackChevronPainter extends CustomPainter {
  const _BackChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.iconMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;
    canvas.drawPath(
      Path()
        ..moveTo(15 * w, 5 * h)
        ..lineTo(8 * w, 12 * h)
        ..lineTo(15 * w, 19 * h),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_BackChevronPainter oldDelegate) => false;
}

class _Footer extends StatelessWidget {
  const _Footer({required this.label, required this.enabled, required this.onPressed});

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(22, 14, 22, 30),
      child: PrimaryButton(
        label: label,
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}
