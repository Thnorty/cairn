// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RecurrenceType, String>
  recurrenceType = GeneratedColumn<String>(
    'recurrence_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<RecurrenceType>($TasksTable.$converterrecurrenceType);
  @override
  late final GeneratedColumnWithTypeConverter<List<int>?, String> weeklyDays =
      GeneratedColumn<String>(
        'weekly_days',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<List<int>?>($TasksTable.$converterweeklyDaysn);
  @override
  late final GeneratedColumnWithTypeConverter<MonthlyMode?, String>
  monthlyMode = GeneratedColumn<String>(
    'monthly_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<MonthlyMode?>($TasksTable.$convertermonthlyModen);
  static const VerificationMeta _monthDayMeta = const VerificationMeta(
    'monthDay',
  );
  @override
  late final GeneratedColumn<int> monthDay = GeneratedColumn<int>(
    'month_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monthNthMeta = const VerificationMeta(
    'monthNth',
  );
  @override
  late final GeneratedColumn<int> monthNth = GeneratedColumn<int>(
    'month_nth',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monthWeekdayMeta = const VerificationMeta(
    'monthWeekday',
  );
  @override
  late final GeneratedColumn<int> monthWeekday = GeneratedColumn<int>(
    'month_weekday',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate?, String> dueDate =
      GeneratedColumn<String>(
        'due_date',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<LocalDate?>($TasksTable.$converterdueDaten);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> dueTimes =
      GeneratedColumn<String>(
        'due_times',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($TasksTable.$converterdueTimes);
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate, String> startDate =
      GeneratedColumn<String>(
        'start_date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LocalDate>($TasksTable.$converterstartDate);
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate?, String> endDate =
      GeneratedColumn<String>(
        'end_date',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<LocalDate?>($TasksTable.$converterendDaten);
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    recurrenceType,
    weeklyDays,
    monthlyMode,
    monthDay,
    monthNth,
    monthWeekday,
    dueDate,
    dueTimes,
    startDate,
    endDate,
    archived,
    userId,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Task> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('month_day')) {
      context.handle(
        _monthDayMeta,
        monthDay.isAcceptableOrUnknown(data['month_day']!, _monthDayMeta),
      );
    }
    if (data.containsKey('month_nth')) {
      context.handle(
        _monthNthMeta,
        monthNth.isAcceptableOrUnknown(data['month_nth']!, _monthNthMeta),
      );
    }
    if (data.containsKey('month_weekday')) {
      context.handle(
        _monthWeekdayMeta,
        monthWeekday.isAcceptableOrUnknown(
          data['month_weekday']!,
          _monthWeekdayMeta,
        ),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      recurrenceType: $TasksTable.$converterrecurrenceType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}recurrence_type'],
        )!,
      ),
      weeklyDays: $TasksTable.$converterweeklyDaysn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}weekly_days'],
        ),
      ),
      monthlyMode: $TasksTable.$convertermonthlyModen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}monthly_mode'],
        ),
      ),
      monthDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month_day'],
      ),
      monthNth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month_nth'],
      ),
      monthWeekday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month_weekday'],
      ),
      dueDate: $TasksTable.$converterdueDaten.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}due_date'],
        ),
      ),
      dueTimes: $TasksTable.$converterdueTimes.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}due_times'],
        )!,
      ),
      startDate: $TasksTable.$converterstartDate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}start_date'],
        )!,
      ),
      endDate: $TasksTable.$converterendDaten.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}end_date'],
        ),
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RecurrenceType, String, String>
  $converterrecurrenceType = const EnumNameConverter<RecurrenceType>(
    RecurrenceType.values,
  );
  static TypeConverter<List<int>, String> $converterweeklyDays =
      const IntListConverter();
  static TypeConverter<List<int>?, String?> $converterweeklyDaysn =
      NullAwareTypeConverter.wrap($converterweeklyDays);
  static TypeConverter<MonthlyMode, String> $convertermonthlyMode =
      const MonthlyModeConverter();
  static TypeConverter<MonthlyMode?, String?> $convertermonthlyModen =
      NullAwareTypeConverter.wrap($convertermonthlyMode);
  static TypeConverter<LocalDate, String> $converterdueDate =
      const LocalDateConverter();
  static TypeConverter<LocalDate?, String?> $converterdueDaten =
      NullAwareTypeConverter.wrap($converterdueDate);
  static TypeConverter<List<String>, String> $converterdueTimes =
      const StringListConverter();
  static TypeConverter<LocalDate, String> $converterstartDate =
      const LocalDateConverter();
  static TypeConverter<LocalDate, String> $converterendDate =
      const LocalDateConverter();
  static TypeConverter<LocalDate?, String?> $converterendDaten =
      NullAwareTypeConverter.wrap($converterendDate);
}

class Task extends DataClass implements Insertable<Task> {
  /// Client-generated UUID v7.
  final String id;
  final String title;
  final String? description;
  final RecurrenceType recurrenceType;

  /// JSON array of ISO weekday ints (1=Mon..7=Sun); for weekly.
  final List<int>? weeklyDays;

  /// For monthly.
  final MonthlyMode? monthlyMode;

  /// 1–31; for monthly day_of_month. Clamped to short months at generation.
  final int? monthDay;

  /// 1..4, or -1 for "Last"; for monthly nth_weekday.
  final int? monthNth;

  /// ISO weekday; for monthly nth_weekday.
  final int? monthWeekday;

  /// ISO date; for once.
  final LocalDate? dueDate;

  /// JSON array of "HH:mm" strings: the task's slots by index.
  /// `[]` = one untimed slot 0.
  final List<String> dueTimes;
  final LocalDate startDate;
  final LocalDate? endDate;

  /// User-facing archive (hidden, not deleted).
  final bool archived;

  /// Owner (auth.uid()); nullable until the auth phase.
  final String? userId;

  /// Epoch millis. updated_at drives last-write-wins sync.
  final int createdAt;
  final int updatedAt;

  /// Sync tombstone (rows are never hard-deleted).
  final int? deletedAt;
  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.recurrenceType,
    this.weeklyDays,
    this.monthlyMode,
    this.monthDay,
    this.monthNth,
    this.monthWeekday,
    this.dueDate,
    required this.dueTimes,
    required this.startDate,
    this.endDate,
    required this.archived,
    this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    {
      map['recurrence_type'] = Variable<String>(
        $TasksTable.$converterrecurrenceType.toSql(recurrenceType),
      );
    }
    if (!nullToAbsent || weeklyDays != null) {
      map['weekly_days'] = Variable<String>(
        $TasksTable.$converterweeklyDaysn.toSql(weeklyDays),
      );
    }
    if (!nullToAbsent || monthlyMode != null) {
      map['monthly_mode'] = Variable<String>(
        $TasksTable.$convertermonthlyModen.toSql(monthlyMode),
      );
    }
    if (!nullToAbsent || monthDay != null) {
      map['month_day'] = Variable<int>(monthDay);
    }
    if (!nullToAbsent || monthNth != null) {
      map['month_nth'] = Variable<int>(monthNth);
    }
    if (!nullToAbsent || monthWeekday != null) {
      map['month_weekday'] = Variable<int>(monthWeekday);
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<String>(
        $TasksTable.$converterdueDaten.toSql(dueDate),
      );
    }
    {
      map['due_times'] = Variable<String>(
        $TasksTable.$converterdueTimes.toSql(dueTimes),
      );
    }
    {
      map['start_date'] = Variable<String>(
        $TasksTable.$converterstartDate.toSql(startDate),
      );
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<String>(
        $TasksTable.$converterendDaten.toSql(endDate),
      );
    }
    map['archived'] = Variable<bool>(archived);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      recurrenceType: Value(recurrenceType),
      weeklyDays: weeklyDays == null && nullToAbsent
          ? const Value.absent()
          : Value(weeklyDays),
      monthlyMode: monthlyMode == null && nullToAbsent
          ? const Value.absent()
          : Value(monthlyMode),
      monthDay: monthDay == null && nullToAbsent
          ? const Value.absent()
          : Value(monthDay),
      monthNth: monthNth == null && nullToAbsent
          ? const Value.absent()
          : Value(monthNth),
      monthWeekday: monthWeekday == null && nullToAbsent
          ? const Value.absent()
          : Value(monthWeekday),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      dueTimes: Value(dueTimes),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      archived: Value(archived),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Task.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      recurrenceType: $TasksTable.$converterrecurrenceType.fromJson(
        serializer.fromJson<String>(json['recurrenceType']),
      ),
      weeklyDays: serializer.fromJson<List<int>?>(json['weeklyDays']),
      monthlyMode: serializer.fromJson<MonthlyMode?>(json['monthlyMode']),
      monthDay: serializer.fromJson<int?>(json['monthDay']),
      monthNth: serializer.fromJson<int?>(json['monthNth']),
      monthWeekday: serializer.fromJson<int?>(json['monthWeekday']),
      dueDate: serializer.fromJson<LocalDate?>(json['dueDate']),
      dueTimes: serializer.fromJson<List<String>>(json['dueTimes']),
      startDate: serializer.fromJson<LocalDate>(json['startDate']),
      endDate: serializer.fromJson<LocalDate?>(json['endDate']),
      archived: serializer.fromJson<bool>(json['archived']),
      userId: serializer.fromJson<String?>(json['userId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'recurrenceType': serializer.toJson<String>(
        $TasksTable.$converterrecurrenceType.toJson(recurrenceType),
      ),
      'weeklyDays': serializer.toJson<List<int>?>(weeklyDays),
      'monthlyMode': serializer.toJson<MonthlyMode?>(monthlyMode),
      'monthDay': serializer.toJson<int?>(monthDay),
      'monthNth': serializer.toJson<int?>(monthNth),
      'monthWeekday': serializer.toJson<int?>(monthWeekday),
      'dueDate': serializer.toJson<LocalDate?>(dueDate),
      'dueTimes': serializer.toJson<List<String>>(dueTimes),
      'startDate': serializer.toJson<LocalDate>(startDate),
      'endDate': serializer.toJson<LocalDate?>(endDate),
      'archived': serializer.toJson<bool>(archived),
      'userId': serializer.toJson<String?>(userId),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  Task copyWith({
    String? id,
    String? title,
    Value<String?> description = const Value.absent(),
    RecurrenceType? recurrenceType,
    Value<List<int>?> weeklyDays = const Value.absent(),
    Value<MonthlyMode?> monthlyMode = const Value.absent(),
    Value<int?> monthDay = const Value.absent(),
    Value<int?> monthNth = const Value.absent(),
    Value<int?> monthWeekday = const Value.absent(),
    Value<LocalDate?> dueDate = const Value.absent(),
    List<String>? dueTimes,
    LocalDate? startDate,
    Value<LocalDate?> endDate = const Value.absent(),
    bool? archived,
    Value<String?> userId = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    recurrenceType: recurrenceType ?? this.recurrenceType,
    weeklyDays: weeklyDays.present ? weeklyDays.value : this.weeklyDays,
    monthlyMode: monthlyMode.present ? monthlyMode.value : this.monthlyMode,
    monthDay: monthDay.present ? monthDay.value : this.monthDay,
    monthNth: monthNth.present ? monthNth.value : this.monthNth,
    monthWeekday: monthWeekday.present ? monthWeekday.value : this.monthWeekday,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    dueTimes: dueTimes ?? this.dueTimes,
    startDate: startDate ?? this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    archived: archived ?? this.archived,
    userId: userId.present ? userId.value : this.userId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Task copyWithCompanion(TasksCompanion data) {
    return Task(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      recurrenceType: data.recurrenceType.present
          ? data.recurrenceType.value
          : this.recurrenceType,
      weeklyDays: data.weeklyDays.present
          ? data.weeklyDays.value
          : this.weeklyDays,
      monthlyMode: data.monthlyMode.present
          ? data.monthlyMode.value
          : this.monthlyMode,
      monthDay: data.monthDay.present ? data.monthDay.value : this.monthDay,
      monthNth: data.monthNth.present ? data.monthNth.value : this.monthNth,
      monthWeekday: data.monthWeekday.present
          ? data.monthWeekday.value
          : this.monthWeekday,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      dueTimes: data.dueTimes.present ? data.dueTimes.value : this.dueTimes,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      archived: data.archived.present ? data.archived.value : this.archived,
      userId: data.userId.present ? data.userId.value : this.userId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('recurrenceType: $recurrenceType, ')
          ..write('weeklyDays: $weeklyDays, ')
          ..write('monthlyMode: $monthlyMode, ')
          ..write('monthDay: $monthDay, ')
          ..write('monthNth: $monthNth, ')
          ..write('monthWeekday: $monthWeekday, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueTimes: $dueTimes, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('archived: $archived, ')
          ..write('userId: $userId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    recurrenceType,
    weeklyDays,
    monthlyMode,
    monthDay,
    monthNth,
    monthWeekday,
    dueDate,
    dueTimes,
    startDate,
    endDate,
    archived,
    userId,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.recurrenceType == this.recurrenceType &&
          other.weeklyDays == this.weeklyDays &&
          other.monthlyMode == this.monthlyMode &&
          other.monthDay == this.monthDay &&
          other.monthNth == this.monthNth &&
          other.monthWeekday == this.monthWeekday &&
          other.dueDate == this.dueDate &&
          other.dueTimes == this.dueTimes &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.archived == this.archived &&
          other.userId == this.userId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> description;
  final Value<RecurrenceType> recurrenceType;
  final Value<List<int>?> weeklyDays;
  final Value<MonthlyMode?> monthlyMode;
  final Value<int?> monthDay;
  final Value<int?> monthNth;
  final Value<int?> monthWeekday;
  final Value<LocalDate?> dueDate;
  final Value<List<String>> dueTimes;
  final Value<LocalDate> startDate;
  final Value<LocalDate?> endDate;
  final Value<bool> archived;
  final Value<String?> userId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.recurrenceType = const Value.absent(),
    this.weeklyDays = const Value.absent(),
    this.monthlyMode = const Value.absent(),
    this.monthDay = const Value.absent(),
    this.monthNth = const Value.absent(),
    this.monthWeekday = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.dueTimes = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.archived = const Value.absent(),
    this.userId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String id,
    required String title,
    this.description = const Value.absent(),
    required RecurrenceType recurrenceType,
    this.weeklyDays = const Value.absent(),
    this.monthlyMode = const Value.absent(),
    this.monthDay = const Value.absent(),
    this.monthNth = const Value.absent(),
    this.monthWeekday = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.dueTimes = const Value.absent(),
    required LocalDate startDate,
    this.endDate = const Value.absent(),
    this.archived = const Value.absent(),
    this.userId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       recurrenceType = Value(recurrenceType),
       startDate = Value(startDate),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Task> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? recurrenceType,
    Expression<String>? weeklyDays,
    Expression<String>? monthlyMode,
    Expression<int>? monthDay,
    Expression<int>? monthNth,
    Expression<int>? monthWeekday,
    Expression<String>? dueDate,
    Expression<String>? dueTimes,
    Expression<String>? startDate,
    Expression<String>? endDate,
    Expression<bool>? archived,
    Expression<String>? userId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (recurrenceType != null) 'recurrence_type': recurrenceType,
      if (weeklyDays != null) 'weekly_days': weeklyDays,
      if (monthlyMode != null) 'monthly_mode': monthlyMode,
      if (monthDay != null) 'month_day': monthDay,
      if (monthNth != null) 'month_nth': monthNth,
      if (monthWeekday != null) 'month_weekday': monthWeekday,
      if (dueDate != null) 'due_date': dueDate,
      if (dueTimes != null) 'due_times': dueTimes,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (archived != null) 'archived': archived,
      if (userId != null) 'user_id': userId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? description,
    Value<RecurrenceType>? recurrenceType,
    Value<List<int>?>? weeklyDays,
    Value<MonthlyMode?>? monthlyMode,
    Value<int?>? monthDay,
    Value<int?>? monthNth,
    Value<int?>? monthWeekday,
    Value<LocalDate?>? dueDate,
    Value<List<String>>? dueTimes,
    Value<LocalDate>? startDate,
    Value<LocalDate?>? endDate,
    Value<bool>? archived,
    Value<String?>? userId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      weeklyDays: weeklyDays ?? this.weeklyDays,
      monthlyMode: monthlyMode ?? this.monthlyMode,
      monthDay: monthDay ?? this.monthDay,
      monthNth: monthNth ?? this.monthNth,
      monthWeekday: monthWeekday ?? this.monthWeekday,
      dueDate: dueDate ?? this.dueDate,
      dueTimes: dueTimes ?? this.dueTimes,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      archived: archived ?? this.archived,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (recurrenceType.present) {
      map['recurrence_type'] = Variable<String>(
        $TasksTable.$converterrecurrenceType.toSql(recurrenceType.value),
      );
    }
    if (weeklyDays.present) {
      map['weekly_days'] = Variable<String>(
        $TasksTable.$converterweeklyDaysn.toSql(weeklyDays.value),
      );
    }
    if (monthlyMode.present) {
      map['monthly_mode'] = Variable<String>(
        $TasksTable.$convertermonthlyModen.toSql(monthlyMode.value),
      );
    }
    if (monthDay.present) {
      map['month_day'] = Variable<int>(monthDay.value);
    }
    if (monthNth.present) {
      map['month_nth'] = Variable<int>(monthNth.value);
    }
    if (monthWeekday.present) {
      map['month_weekday'] = Variable<int>(monthWeekday.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<String>(
        $TasksTable.$converterdueDaten.toSql(dueDate.value),
      );
    }
    if (dueTimes.present) {
      map['due_times'] = Variable<String>(
        $TasksTable.$converterdueTimes.toSql(dueTimes.value),
      );
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(
        $TasksTable.$converterstartDate.toSql(startDate.value),
      );
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(
        $TasksTable.$converterendDaten.toSql(endDate.value),
      );
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('recurrenceType: $recurrenceType, ')
          ..write('weeklyDays: $weeklyDays, ')
          ..write('monthlyMode: $monthlyMode, ')
          ..write('monthDay: $monthDay, ')
          ..write('monthNth: $monthNth, ')
          ..write('monthWeekday: $monthWeekday, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueTimes: $dueTimes, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('archived: $archived, ')
          ..write('userId: $userId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CompletionsTable extends Completions
    with TableInfo<$CompletionsTable, Completion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompletionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate, String>
  occurrenceDate = GeneratedColumn<String>(
    'occurrence_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<LocalDate>($CompletionsTable.$converteroccurrenceDate);
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<int> slot = GeneratedColumn<int>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proofPhotoPathMeta = const VerificationMeta(
    'proofPhotoPath',
  );
  @override
  late final GeneratedColumn<String> proofPhotoPath = GeneratedColumn<String>(
    'proof_photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ProofSource?, String>
  proofSource = GeneratedColumn<String>(
    'proof_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<ProofSource?>($CompletionsTable.$converterproofSourcen);
  static const VerificationMeta _photoTakenAtMeta = const VerificationMeta(
    'photoTakenAt',
  );
  @override
  late final GeneratedColumn<int> photoTakenAt = GeneratedColumn<int>(
    'photo_taken_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<VerificationStatus, String>
  verificationStatus =
      GeneratedColumn<String>(
        'verification_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('none'),
      ).withConverter<VerificationStatus>(
        $CompletionsTable.$converterverificationStatus,
      );
  static const VerificationMeta _verificationMetaMeta = const VerificationMeta(
    'verificationMeta',
  );
  @override
  late final GeneratedColumn<String> verificationMeta = GeneratedColumn<String>(
    'verification_meta',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pointsAwardedMeta = const VerificationMeta(
    'pointsAwarded',
  );
  @override
  late final GeneratedColumn<int> pointsAwarded = GeneratedColumn<int>(
    'points_awarded',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    occurrenceDate,
    slot,
    completedAt,
    proofPhotoPath,
    proofSource,
    photoTakenAt,
    verificationStatus,
    verificationMeta,
    pointsAwarded,
    userId,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'completions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Completion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    if (data.containsKey('proof_photo_path')) {
      context.handle(
        _proofPhotoPathMeta,
        proofPhotoPath.isAcceptableOrUnknown(
          data['proof_photo_path']!,
          _proofPhotoPathMeta,
        ),
      );
    }
    if (data.containsKey('photo_taken_at')) {
      context.handle(
        _photoTakenAtMeta,
        photoTakenAt.isAcceptableOrUnknown(
          data['photo_taken_at']!,
          _photoTakenAtMeta,
        ),
      );
    }
    if (data.containsKey('verification_meta')) {
      context.handle(
        _verificationMetaMeta,
        verificationMeta.isAcceptableOrUnknown(
          data['verification_meta']!,
          _verificationMetaMeta,
        ),
      );
    }
    if (data.containsKey('points_awarded')) {
      context.handle(
        _pointsAwardedMeta,
        pointsAwarded.isAcceptableOrUnknown(
          data['points_awarded']!,
          _pointsAwardedMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Completion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Completion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      occurrenceDate: $CompletionsTable.$converteroccurrenceDate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}occurrence_date'],
        )!,
      ),
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      )!,
      proofPhotoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proof_photo_path'],
      ),
      proofSource: $CompletionsTable.$converterproofSourcen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}proof_source'],
        ),
      ),
      photoTakenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}photo_taken_at'],
      ),
      verificationStatus: $CompletionsTable.$converterverificationStatus
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}verification_status'],
            )!,
          ),
      verificationMeta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verification_meta'],
      ),
      pointsAwarded: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points_awarded'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CompletionsTable createAlias(String alias) {
    return $CompletionsTable(attachedDatabase, alias);
  }

  static TypeConverter<LocalDate, String> $converteroccurrenceDate =
      const LocalDateConverter();
  static JsonTypeConverter2<ProofSource, String, String> $converterproofSource =
      const EnumNameConverter<ProofSource>(ProofSource.values);
  static JsonTypeConverter2<ProofSource?, String?, String?>
  $converterproofSourcen = JsonTypeConverter2.asNullable($converterproofSource);
  static JsonTypeConverter2<VerificationStatus, String, String>
  $converterverificationStatus = const EnumNameConverter<VerificationStatus>(
    VerificationStatus.values,
  );
}

class Completion extends DataClass implements Insertable<Completion> {
  /// Client-generated UUID v7.
  final String id;
  final String taskId;

  /// ISO date in the user's local timezone.
  final LocalDate occurrenceDate;

  /// Index into the task's due_times (0 for untimed/single).
  final int slot;
  final int completedAt;
  final String? proofPhotoPath;
  final ProofSource? proofSource;

  /// From asset metadata (recency check, later phase).
  final int? photoTakenAt;
  final VerificationStatus verificationStatus;

  /// JSON from Gemini (later phase).
  final String? verificationMeta;

  /// Metres earned by this completion.
  final int pointsAwarded;
  final String? userId;
  final int updatedAt;
  final int? deletedAt;
  const Completion({
    required this.id,
    required this.taskId,
    required this.occurrenceDate,
    required this.slot,
    required this.completedAt,
    this.proofPhotoPath,
    this.proofSource,
    this.photoTakenAt,
    required this.verificationStatus,
    this.verificationMeta,
    required this.pointsAwarded,
    this.userId,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    {
      map['occurrence_date'] = Variable<String>(
        $CompletionsTable.$converteroccurrenceDate.toSql(occurrenceDate),
      );
    }
    map['slot'] = Variable<int>(slot);
    map['completed_at'] = Variable<int>(completedAt);
    if (!nullToAbsent || proofPhotoPath != null) {
      map['proof_photo_path'] = Variable<String>(proofPhotoPath);
    }
    if (!nullToAbsent || proofSource != null) {
      map['proof_source'] = Variable<String>(
        $CompletionsTable.$converterproofSourcen.toSql(proofSource),
      );
    }
    if (!nullToAbsent || photoTakenAt != null) {
      map['photo_taken_at'] = Variable<int>(photoTakenAt);
    }
    {
      map['verification_status'] = Variable<String>(
        $CompletionsTable.$converterverificationStatus.toSql(
          verificationStatus,
        ),
      );
    }
    if (!nullToAbsent || verificationMeta != null) {
      map['verification_meta'] = Variable<String>(verificationMeta);
    }
    map['points_awarded'] = Variable<int>(pointsAwarded);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  CompletionsCompanion toCompanion(bool nullToAbsent) {
    return CompletionsCompanion(
      id: Value(id),
      taskId: Value(taskId),
      occurrenceDate: Value(occurrenceDate),
      slot: Value(slot),
      completedAt: Value(completedAt),
      proofPhotoPath: proofPhotoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(proofPhotoPath),
      proofSource: proofSource == null && nullToAbsent
          ? const Value.absent()
          : Value(proofSource),
      photoTakenAt: photoTakenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(photoTakenAt),
      verificationStatus: Value(verificationStatus),
      verificationMeta: verificationMeta == null && nullToAbsent
          ? const Value.absent()
          : Value(verificationMeta),
      pointsAwarded: Value(pointsAwarded),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Completion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Completion(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      occurrenceDate: serializer.fromJson<LocalDate>(json['occurrenceDate']),
      slot: serializer.fromJson<int>(json['slot']),
      completedAt: serializer.fromJson<int>(json['completedAt']),
      proofPhotoPath: serializer.fromJson<String?>(json['proofPhotoPath']),
      proofSource: $CompletionsTable.$converterproofSourcen.fromJson(
        serializer.fromJson<String?>(json['proofSource']),
      ),
      photoTakenAt: serializer.fromJson<int?>(json['photoTakenAt']),
      verificationStatus: $CompletionsTable.$converterverificationStatus
          .fromJson(serializer.fromJson<String>(json['verificationStatus'])),
      verificationMeta: serializer.fromJson<String?>(json['verificationMeta']),
      pointsAwarded: serializer.fromJson<int>(json['pointsAwarded']),
      userId: serializer.fromJson<String?>(json['userId']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'occurrenceDate': serializer.toJson<LocalDate>(occurrenceDate),
      'slot': serializer.toJson<int>(slot),
      'completedAt': serializer.toJson<int>(completedAt),
      'proofPhotoPath': serializer.toJson<String?>(proofPhotoPath),
      'proofSource': serializer.toJson<String?>(
        $CompletionsTable.$converterproofSourcen.toJson(proofSource),
      ),
      'photoTakenAt': serializer.toJson<int?>(photoTakenAt),
      'verificationStatus': serializer.toJson<String>(
        $CompletionsTable.$converterverificationStatus.toJson(
          verificationStatus,
        ),
      ),
      'verificationMeta': serializer.toJson<String?>(verificationMeta),
      'pointsAwarded': serializer.toJson<int>(pointsAwarded),
      'userId': serializer.toJson<String?>(userId),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  Completion copyWith({
    String? id,
    String? taskId,
    LocalDate? occurrenceDate,
    int? slot,
    int? completedAt,
    Value<String?> proofPhotoPath = const Value.absent(),
    Value<ProofSource?> proofSource = const Value.absent(),
    Value<int?> photoTakenAt = const Value.absent(),
    VerificationStatus? verificationStatus,
    Value<String?> verificationMeta = const Value.absent(),
    int? pointsAwarded,
    Value<String?> userId = const Value.absent(),
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => Completion(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    occurrenceDate: occurrenceDate ?? this.occurrenceDate,
    slot: slot ?? this.slot,
    completedAt: completedAt ?? this.completedAt,
    proofPhotoPath: proofPhotoPath.present
        ? proofPhotoPath.value
        : this.proofPhotoPath,
    proofSource: proofSource.present ? proofSource.value : this.proofSource,
    photoTakenAt: photoTakenAt.present ? photoTakenAt.value : this.photoTakenAt,
    verificationStatus: verificationStatus ?? this.verificationStatus,
    verificationMeta: verificationMeta.present
        ? verificationMeta.value
        : this.verificationMeta,
    pointsAwarded: pointsAwarded ?? this.pointsAwarded,
    userId: userId.present ? userId.value : this.userId,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Completion copyWithCompanion(CompletionsCompanion data) {
    return Completion(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      occurrenceDate: data.occurrenceDate.present
          ? data.occurrenceDate.value
          : this.occurrenceDate,
      slot: data.slot.present ? data.slot.value : this.slot,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      proofPhotoPath: data.proofPhotoPath.present
          ? data.proofPhotoPath.value
          : this.proofPhotoPath,
      proofSource: data.proofSource.present
          ? data.proofSource.value
          : this.proofSource,
      photoTakenAt: data.photoTakenAt.present
          ? data.photoTakenAt.value
          : this.photoTakenAt,
      verificationStatus: data.verificationStatus.present
          ? data.verificationStatus.value
          : this.verificationStatus,
      verificationMeta: data.verificationMeta.present
          ? data.verificationMeta.value
          : this.verificationMeta,
      pointsAwarded: data.pointsAwarded.present
          ? data.pointsAwarded.value
          : this.pointsAwarded,
      userId: data.userId.present ? data.userId.value : this.userId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Completion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('slot: $slot, ')
          ..write('completedAt: $completedAt, ')
          ..write('proofPhotoPath: $proofPhotoPath, ')
          ..write('proofSource: $proofSource, ')
          ..write('photoTakenAt: $photoTakenAt, ')
          ..write('verificationStatus: $verificationStatus, ')
          ..write('verificationMeta: $verificationMeta, ')
          ..write('pointsAwarded: $pointsAwarded, ')
          ..write('userId: $userId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    occurrenceDate,
    slot,
    completedAt,
    proofPhotoPath,
    proofSource,
    photoTakenAt,
    verificationStatus,
    verificationMeta,
    pointsAwarded,
    userId,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Completion &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.occurrenceDate == this.occurrenceDate &&
          other.slot == this.slot &&
          other.completedAt == this.completedAt &&
          other.proofPhotoPath == this.proofPhotoPath &&
          other.proofSource == this.proofSource &&
          other.photoTakenAt == this.photoTakenAt &&
          other.verificationStatus == this.verificationStatus &&
          other.verificationMeta == this.verificationMeta &&
          other.pointsAwarded == this.pointsAwarded &&
          other.userId == this.userId &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CompletionsCompanion extends UpdateCompanion<Completion> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<LocalDate> occurrenceDate;
  final Value<int> slot;
  final Value<int> completedAt;
  final Value<String?> proofPhotoPath;
  final Value<ProofSource?> proofSource;
  final Value<int?> photoTakenAt;
  final Value<VerificationStatus> verificationStatus;
  final Value<String?> verificationMeta;
  final Value<int> pointsAwarded;
  final Value<String?> userId;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const CompletionsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.occurrenceDate = const Value.absent(),
    this.slot = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.proofPhotoPath = const Value.absent(),
    this.proofSource = const Value.absent(),
    this.photoTakenAt = const Value.absent(),
    this.verificationStatus = const Value.absent(),
    this.verificationMeta = const Value.absent(),
    this.pointsAwarded = const Value.absent(),
    this.userId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompletionsCompanion.insert({
    required String id,
    required String taskId,
    required LocalDate occurrenceDate,
    this.slot = const Value.absent(),
    required int completedAt,
    this.proofPhotoPath = const Value.absent(),
    this.proofSource = const Value.absent(),
    this.photoTakenAt = const Value.absent(),
    this.verificationStatus = const Value.absent(),
    this.verificationMeta = const Value.absent(),
    this.pointsAwarded = const Value.absent(),
    this.userId = const Value.absent(),
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       occurrenceDate = Value(occurrenceDate),
       completedAt = Value(completedAt),
       updatedAt = Value(updatedAt);
  static Insertable<Completion> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? occurrenceDate,
    Expression<int>? slot,
    Expression<int>? completedAt,
    Expression<String>? proofPhotoPath,
    Expression<String>? proofSource,
    Expression<int>? photoTakenAt,
    Expression<String>? verificationStatus,
    Expression<String>? verificationMeta,
    Expression<int>? pointsAwarded,
    Expression<String>? userId,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (occurrenceDate != null) 'occurrence_date': occurrenceDate,
      if (slot != null) 'slot': slot,
      if (completedAt != null) 'completed_at': completedAt,
      if (proofPhotoPath != null) 'proof_photo_path': proofPhotoPath,
      if (proofSource != null) 'proof_source': proofSource,
      if (photoTakenAt != null) 'photo_taken_at': photoTakenAt,
      if (verificationStatus != null) 'verification_status': verificationStatus,
      if (verificationMeta != null) 'verification_meta': verificationMeta,
      if (pointsAwarded != null) 'points_awarded': pointsAwarded,
      if (userId != null) 'user_id': userId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompletionsCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<LocalDate>? occurrenceDate,
    Value<int>? slot,
    Value<int>? completedAt,
    Value<String?>? proofPhotoPath,
    Value<ProofSource?>? proofSource,
    Value<int?>? photoTakenAt,
    Value<VerificationStatus>? verificationStatus,
    Value<String?>? verificationMeta,
    Value<int>? pointsAwarded,
    Value<String?>? userId,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CompletionsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      slot: slot ?? this.slot,
      completedAt: completedAt ?? this.completedAt,
      proofPhotoPath: proofPhotoPath ?? this.proofPhotoPath,
      proofSource: proofSource ?? this.proofSource,
      photoTakenAt: photoTakenAt ?? this.photoTakenAt,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationMeta: verificationMeta ?? this.verificationMeta,
      pointsAwarded: pointsAwarded ?? this.pointsAwarded,
      userId: userId ?? this.userId,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (occurrenceDate.present) {
      map['occurrence_date'] = Variable<String>(
        $CompletionsTable.$converteroccurrenceDate.toSql(occurrenceDate.value),
      );
    }
    if (slot.present) {
      map['slot'] = Variable<int>(slot.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (proofPhotoPath.present) {
      map['proof_photo_path'] = Variable<String>(proofPhotoPath.value);
    }
    if (proofSource.present) {
      map['proof_source'] = Variable<String>(
        $CompletionsTable.$converterproofSourcen.toSql(proofSource.value),
      );
    }
    if (photoTakenAt.present) {
      map['photo_taken_at'] = Variable<int>(photoTakenAt.value);
    }
    if (verificationStatus.present) {
      map['verification_status'] = Variable<String>(
        $CompletionsTable.$converterverificationStatus.toSql(
          verificationStatus.value,
        ),
      );
    }
    if (verificationMeta.present) {
      map['verification_meta'] = Variable<String>(verificationMeta.value);
    }
    if (pointsAwarded.present) {
      map['points_awarded'] = Variable<int>(pointsAwarded.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompletionsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('slot: $slot, ')
          ..write('completedAt: $completedAt, ')
          ..write('proofPhotoPath: $proofPhotoPath, ')
          ..write('proofSource: $proofSource, ')
          ..write('photoTakenAt: $photoTakenAt, ')
          ..write('verificationStatus: $verificationStatus, ')
          ..write('verificationMeta: $verificationMeta, ')
          ..write('pointsAwarded: $pointsAwarded, ')
          ..write('userId: $userId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $CompletionsTable completions = $CompletionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [tasks, completions];
}

typedef $$TasksTableCreateCompanionBuilder =
    TasksCompanion Function({
      required String id,
      required String title,
      Value<String?> description,
      required RecurrenceType recurrenceType,
      Value<List<int>?> weeklyDays,
      Value<MonthlyMode?> monthlyMode,
      Value<int?> monthDay,
      Value<int?> monthNth,
      Value<int?> monthWeekday,
      Value<LocalDate?> dueDate,
      Value<List<String>> dueTimes,
      required LocalDate startDate,
      Value<LocalDate?> endDate,
      Value<bool> archived,
      Value<String?> userId,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$TasksTableUpdateCompanionBuilder =
    TasksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> description,
      Value<RecurrenceType> recurrenceType,
      Value<List<int>?> weeklyDays,
      Value<MonthlyMode?> monthlyMode,
      Value<int?> monthDay,
      Value<int?> monthNth,
      Value<int?> monthWeekday,
      Value<LocalDate?> dueDate,
      Value<List<String>> dueTimes,
      Value<LocalDate> startDate,
      Value<LocalDate?> endDate,
      Value<bool> archived,
      Value<String?> userId,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

final class $$TasksTableReferences
    extends BaseReferences<_$AppDatabase, $TasksTable, Task> {
  $$TasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CompletionsTable, List<Completion>>
  _completionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.completions,
    aliasName: $_aliasNameGenerator(db.tasks.id, db.completions.taskId),
  );

  $$CompletionsTableProcessedTableManager get completionsRefs {
    final manager = $$CompletionsTableTableManager(
      $_db,
      $_db.completions,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_completionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RecurrenceType, RecurrenceType, String>
  get recurrenceType => $composableBuilder(
    column: $table.recurrenceType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<int>?, List<int>, String>
  get weeklyDays => $composableBuilder(
    column: $table.weeklyDays,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<MonthlyMode?, MonthlyMode, String>
  get monthlyMode => $composableBuilder(
    column: $table.monthlyMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get monthDay => $composableBuilder(
    column: $table.monthDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthNth => $composableBuilder(
    column: $table.monthNth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthWeekday => $composableBuilder(
    column: $table.monthWeekday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalDate?, LocalDate, String> get dueDate =>
      $composableBuilder(
        column: $table.dueDate,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get dueTimes => $composableBuilder(
    column: $table.dueTimes,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalDate, LocalDate, String> get startDate =>
      $composableBuilder(
        column: $table.startDate,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<LocalDate?, LocalDate, String> get endDate =>
      $composableBuilder(
        column: $table.endDate,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> completionsRefs(
    Expression<bool> Function($$CompletionsTableFilterComposer f) f,
  ) {
    final $$CompletionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.completions,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompletionsTableFilterComposer(
            $db: $db,
            $table: $db.completions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceType => $composableBuilder(
    column: $table.recurrenceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weeklyDays => $composableBuilder(
    column: $table.weeklyDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get monthlyMode => $composableBuilder(
    column: $table.monthlyMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthDay => $composableBuilder(
    column: $table.monthDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthNth => $composableBuilder(
    column: $table.monthNth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthWeekday => $composableBuilder(
    column: $table.monthWeekday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueTimes => $composableBuilder(
    column: $table.dueTimes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<RecurrenceType, String> get recurrenceType =>
      $composableBuilder(
        column: $table.recurrenceType,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<int>?, String> get weeklyDays =>
      $composableBuilder(
        column: $table.weeklyDays,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<MonthlyMode?, String> get monthlyMode =>
      $composableBuilder(
        column: $table.monthlyMode,
        builder: (column) => column,
      );

  GeneratedColumn<int> get monthDay =>
      $composableBuilder(column: $table.monthDay, builder: (column) => column);

  GeneratedColumn<int> get monthNth =>
      $composableBuilder(column: $table.monthNth, builder: (column) => column);

  GeneratedColumn<int> get monthWeekday => $composableBuilder(
    column: $table.monthWeekday,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<LocalDate?, String> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get dueTimes =>
      $composableBuilder(column: $table.dueTimes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalDate, String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalDate?, String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> completionsRefs<T extends Object>(
    Expression<T> Function($$CompletionsTableAnnotationComposer a) f,
  ) {
    final $$CompletionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.completions,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompletionsTableAnnotationComposer(
            $db: $db,
            $table: $db.completions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          Task,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (Task, $$TasksTableReferences),
          Task,
          PrefetchHooks Function({bool completionsRefs})
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<RecurrenceType> recurrenceType = const Value.absent(),
                Value<List<int>?> weeklyDays = const Value.absent(),
                Value<MonthlyMode?> monthlyMode = const Value.absent(),
                Value<int?> monthDay = const Value.absent(),
                Value<int?> monthNth = const Value.absent(),
                Value<int?> monthWeekday = const Value.absent(),
                Value<LocalDate?> dueDate = const Value.absent(),
                Value<List<String>> dueTimes = const Value.absent(),
                Value<LocalDate> startDate = const Value.absent(),
                Value<LocalDate?> endDate = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                title: title,
                description: description,
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
                userId: userId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> description = const Value.absent(),
                required RecurrenceType recurrenceType,
                Value<List<int>?> weeklyDays = const Value.absent(),
                Value<MonthlyMode?> monthlyMode = const Value.absent(),
                Value<int?> monthDay = const Value.absent(),
                Value<int?> monthNth = const Value.absent(),
                Value<int?> monthWeekday = const Value.absent(),
                Value<LocalDate?> dueDate = const Value.absent(),
                Value<List<String>> dueTimes = const Value.absent(),
                required LocalDate startDate,
                Value<LocalDate?> endDate = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                title: title,
                description: description,
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
                userId: userId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TasksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({completionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (completionsRefs) db.completions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (completionsRefs)
                    await $_getPrefetchedData<Task, $TasksTable, Completion>(
                      currentTable: table,
                      referencedTable: $$TasksTableReferences
                          ._completionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TasksTableReferences(db, table, p0).completionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.taskId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      Task,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (Task, $$TasksTableReferences),
      Task,
      PrefetchHooks Function({bool completionsRefs})
    >;
typedef $$CompletionsTableCreateCompanionBuilder =
    CompletionsCompanion Function({
      required String id,
      required String taskId,
      required LocalDate occurrenceDate,
      Value<int> slot,
      required int completedAt,
      Value<String?> proofPhotoPath,
      Value<ProofSource?> proofSource,
      Value<int?> photoTakenAt,
      Value<VerificationStatus> verificationStatus,
      Value<String?> verificationMeta,
      Value<int> pointsAwarded,
      Value<String?> userId,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$CompletionsTableUpdateCompanionBuilder =
    CompletionsCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<LocalDate> occurrenceDate,
      Value<int> slot,
      Value<int> completedAt,
      Value<String?> proofPhotoPath,
      Value<ProofSource?> proofSource,
      Value<int?> photoTakenAt,
      Value<VerificationStatus> verificationStatus,
      Value<String?> verificationMeta,
      Value<int> pointsAwarded,
      Value<String?> userId,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

final class $$CompletionsTableReferences
    extends BaseReferences<_$AppDatabase, $CompletionsTable, Completion> {
  $$CompletionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TasksTable _taskIdTable(_$AppDatabase db) => db.tasks.createAlias(
    $_aliasNameGenerator(db.completions.taskId, db.tasks.id),
  );

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CompletionsTableFilterComposer
    extends Composer<_$AppDatabase, $CompletionsTable> {
  $$CompletionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalDate, LocalDate, String>
  get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proofPhotoPath => $composableBuilder(
    column: $table.proofPhotoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ProofSource?, ProofSource, String>
  get proofSource => $composableBuilder(
    column: $table.proofSource,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get photoTakenAt => $composableBuilder(
    column: $table.photoTakenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<VerificationStatus, VerificationStatus, String>
  get verificationStatus => $composableBuilder(
    column: $table.verificationStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get verificationMeta => $composableBuilder(
    column: $table.verificationMeta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pointsAwarded => $composableBuilder(
    column: $table.pointsAwarded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CompletionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CompletionsTable> {
  $$CompletionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proofPhotoPath => $composableBuilder(
    column: $table.proofPhotoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proofSource => $composableBuilder(
    column: $table.proofSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get photoTakenAt => $composableBuilder(
    column: $table.photoTakenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verificationStatus => $composableBuilder(
    column: $table.verificationStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verificationMeta => $composableBuilder(
    column: $table.verificationMeta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pointsAwarded => $composableBuilder(
    column: $table.pointsAwarded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CompletionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompletionsTable> {
  $$CompletionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalDate, String> get occurrenceDate =>
      $composableBuilder(
        column: $table.occurrenceDate,
        builder: (column) => column,
      );

  GeneratedColumn<int> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get proofPhotoPath => $composableBuilder(
    column: $table.proofPhotoPath,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ProofSource?, String> get proofSource =>
      $composableBuilder(
        column: $table.proofSource,
        builder: (column) => column,
      );

  GeneratedColumn<int> get photoTakenAt => $composableBuilder(
    column: $table.photoTakenAt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<VerificationStatus, String>
  get verificationStatus => $composableBuilder(
    column: $table.verificationStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get verificationMeta => $composableBuilder(
    column: $table.verificationMeta,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pointsAwarded => $composableBuilder(
    column: $table.pointsAwarded,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CompletionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CompletionsTable,
          Completion,
          $$CompletionsTableFilterComposer,
          $$CompletionsTableOrderingComposer,
          $$CompletionsTableAnnotationComposer,
          $$CompletionsTableCreateCompanionBuilder,
          $$CompletionsTableUpdateCompanionBuilder,
          (Completion, $$CompletionsTableReferences),
          Completion,
          PrefetchHooks Function({bool taskId})
        > {
  $$CompletionsTableTableManager(_$AppDatabase db, $CompletionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompletionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompletionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompletionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<LocalDate> occurrenceDate = const Value.absent(),
                Value<int> slot = const Value.absent(),
                Value<int> completedAt = const Value.absent(),
                Value<String?> proofPhotoPath = const Value.absent(),
                Value<ProofSource?> proofSource = const Value.absent(),
                Value<int?> photoTakenAt = const Value.absent(),
                Value<VerificationStatus> verificationStatus =
                    const Value.absent(),
                Value<String?> verificationMeta = const Value.absent(),
                Value<int> pointsAwarded = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompletionsCompanion(
                id: id,
                taskId: taskId,
                occurrenceDate: occurrenceDate,
                slot: slot,
                completedAt: completedAt,
                proofPhotoPath: proofPhotoPath,
                proofSource: proofSource,
                photoTakenAt: photoTakenAt,
                verificationStatus: verificationStatus,
                verificationMeta: verificationMeta,
                pointsAwarded: pointsAwarded,
                userId: userId,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                required LocalDate occurrenceDate,
                Value<int> slot = const Value.absent(),
                required int completedAt,
                Value<String?> proofPhotoPath = const Value.absent(),
                Value<ProofSource?> proofSource = const Value.absent(),
                Value<int?> photoTakenAt = const Value.absent(),
                Value<VerificationStatus> verificationStatus =
                    const Value.absent(),
                Value<String?> verificationMeta = const Value.absent(),
                Value<int> pointsAwarded = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompletionsCompanion.insert(
                id: id,
                taskId: taskId,
                occurrenceDate: occurrenceDate,
                slot: slot,
                completedAt: completedAt,
                proofPhotoPath: proofPhotoPath,
                proofSource: proofSource,
                photoTakenAt: photoTakenAt,
                verificationStatus: verificationStatus,
                verificationMeta: verificationMeta,
                pointsAwarded: pointsAwarded,
                userId: userId,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CompletionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskId,
                                referencedTable: $$CompletionsTableReferences
                                    ._taskIdTable(db),
                                referencedColumn: $$CompletionsTableReferences
                                    ._taskIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CompletionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CompletionsTable,
      Completion,
      $$CompletionsTableFilterComposer,
      $$CompletionsTableOrderingComposer,
      $$CompletionsTableAnnotationComposer,
      $$CompletionsTableCreateCompanionBuilder,
      $$CompletionsTableUpdateCompanionBuilder,
      (Completion, $$CompletionsTableReferences),
      Completion,
      PrefetchHooks Function({bool taskId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$CompletionsTableTableManager get completions =>
      $$CompletionsTableTableManager(_db, _db.completions);
}
