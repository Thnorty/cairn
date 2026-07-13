import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/local_date.dart';
import 'package:sqlite3/open.dart';

/// In-memory database for tests. On Windows dev machines sqlite3.dll is often
/// not on PATH, so fall back to winsqlite3.dll (ships with Windows 10+).
AppDatabase inMemoryDatabase() {
  if (Platform.isWindows) {
    open.overrideFor(OperatingSystem.windows, _openSqliteOnWindows);
  }
  return AppDatabase(NativeDatabase.memory());
}

DynamicLibrary _openSqliteOnWindows() {
  try {
    return DynamicLibrary.open('sqlite3.dll');
  } on ArgumentError {
    return DynamicLibrary.open('winsqlite3.dll');
  }
}

/// Builds a Task row directly (the generator and streak logic are pure and
/// don't need a database).
Task makeTask({
  String id = 'task-1',
  String title = 'Test task',
  RecurrenceType recurrenceType = RecurrenceType.daily,
  List<int>? weeklyDays,
  MonthlyMode? monthlyMode,
  int? monthDay,
  int? monthNth,
  int? monthWeekday,
  LocalDate? dueDate,
  List<String> dueTimes = const [],
  required LocalDate startDate,
  LocalDate? endDate,
  bool archived = false,
}) {
  return Task(
    id: id,
    title: title,
    recurrenceType: recurrenceType,
    weeklyDays: weeklyDays,
    monthlyMode: monthlyMode,
    monthDay: monthDay,
    monthNth: monthNth,
    monthWeekday: monthWeekday,
    dueDate: dueDate,
    dueTimes: dueTimes,
    startDate: startDate,
    endDate: endDate,
    archived: archived,
    createdAt: 0,
    updatedAt: 0,
  );
}

LocalDate d(int year, int month, int day) => LocalDate(year, month, day);
