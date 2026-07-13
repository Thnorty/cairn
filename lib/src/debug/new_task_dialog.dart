import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../models/local_date.dart';
import '../providers.dart';

/// Minimal, ugly task-creation form for the Phase 1 debug screen. Not a
/// real design: supports every recurrence type so occurrence generation can
/// be exercised end to end.
Future<void> showNewTaskDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (context) => _NewTaskDialog(ref: ref),
  );
}

class _NewTaskDialog extends StatefulWidget {
  final WidgetRef ref;
  const _NewTaskDialog({required this.ref});

  @override
  State<_NewTaskDialog> createState() => _NewTaskDialogState();
}

class _NewTaskDialogState extends State<_NewTaskDialog> {
  final _titleController = TextEditingController();
  final _monthDayController = TextEditingController(text: '1');
  RecurrenceType _recurrenceType = RecurrenceType.daily;
  final Set<int> _weeklyDays = {1};
  MonthlyMode _monthlyMode = MonthlyMode.dayOfMonth;
  int _monthNth = 1;
  int _monthWeekday = DateTime.monday;
  late LocalDate _onceDate;
  bool _twiceDaily = false;

  @override
  void initState() {
    super.initState();
    _onceDate = widget.ref.read(clockProvider).today();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _monthDayController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final clock = widget.ref.read(clockProvider);
    final today = clock.today();
    final taskRepo = widget.ref.read(taskRepositoryProvider);

    await taskRepo.createTask(
      title: title,
      recurrenceType: _recurrenceType,
      weeklyDays: _recurrenceType == RecurrenceType.weekly
          ? (_weeklyDays.toList()..sort())
          : null,
      monthlyMode: _recurrenceType == RecurrenceType.monthly ? _monthlyMode : null,
      monthDay: _recurrenceType == RecurrenceType.monthly &&
              _monthlyMode == MonthlyMode.dayOfMonth
          ? int.tryParse(_monthDayController.text) ?? 1
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
      dueTimes: _twiceDaily ? const ['08:00', '20:00'] : const [],
      startDate: _recurrenceType == RecurrenceType.once ? _onceDate : today,
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New task (debug)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            DropdownButton<RecurrenceType>(
              value: _recurrenceType,
              items: RecurrenceType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                  .toList(),
              onChanged: (v) => setState(() => _recurrenceType = v!),
            ),
            const SizedBox(height: 8),
            ..._buildRecurrenceFields(),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Twice daily (08:00 / 20:00)'),
              value: _twiceDaily,
              onChanged: (v) => setState(() => _twiceDaily = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }

  List<Widget> _buildRecurrenceFields() {
    switch (_recurrenceType) {
      case RecurrenceType.once:
        return [
          Row(
            children: [
              Text('Due date: $_onceDate'),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(
                        _onceDate.year, _onceDate.month, _onceDate.day),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _onceDate = LocalDate.of(picked));
                  }
                },
                child: const Text('Pick'),
              ),
            ],
          ),
        ];
      case RecurrenceType.daily:
        return const [];
      case RecurrenceType.weekly:
        const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return [
          Wrap(
            spacing: 4,
            children: [
              for (var i = 0; i < 7; i++)
                FilterChip(
                  label: Text(labels[i]),
                  selected: _weeklyDays.contains(i + 1),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _weeklyDays.add(i + 1);
                    } else {
                      _weeklyDays.remove(i + 1);
                    }
                  }),
                ),
            ],
          ),
        ];
      case RecurrenceType.monthly:
        return [
          DropdownButton<MonthlyMode>(
            value: _monthlyMode,
            items: MonthlyMode.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                .toList(),
            onChanged: (v) => setState(() => _monthlyMode = v!),
          ),
          if (_monthlyMode == MonthlyMode.dayOfMonth)
            TextField(
              controller: _monthDayController,
              decoration: const InputDecoration(labelText: 'Day of month (1-31)'),
              keyboardType: TextInputType.number,
            )
          else
            Row(
              children: [
                DropdownButton<int>(
                  value: _monthNth,
                  items: const [1, 2, 3, 4, -1]
                      .map((n) => DropdownMenuItem(
                          value: n, child: Text(n == -1 ? 'Last' : '${n}th')))
                      .toList(),
                  onChanged: (v) => setState(() => _monthNth = v!),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _monthWeekday,
                  items: const [
                    (DateTime.monday, 'Mon'),
                    (DateTime.tuesday, 'Tue'),
                    (DateTime.wednesday, 'Wed'),
                    (DateTime.thursday, 'Thu'),
                    (DateTime.friday, 'Fri'),
                    (DateTime.saturday, 'Sat'),
                    (DateTime.sunday, 'Sun'),
                  ]
                      .map((e) =>
                          DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                      .toList(),
                  onChanged: (v) => setState(() => _monthWeekday = v!),
                ),
              ],
            ),
        ];
    }
  }
}
