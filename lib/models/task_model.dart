class Task {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final bool isCompleted;
  final int priority; // 1=Low, 2=Medium, 3=High
  final DateTime createdAt;

  // Alarm fields
  final bool alarmEnabled;
  final TimeOfDay? alarmTime;
  final String? alarmSoundPath;
  final String? alarmSoundName;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.isCompleted,
    required this.priority,
    required this.createdAt,
    this.alarmEnabled = false,
    this.alarmTime,
    this.alarmSoundPath,
    this.alarmSoundName,
  });

  // Get the full alarm DateTime by combining dueDate + alarmTime
  DateTime? get alarmDateTime {
    if (!alarmEnabled || alarmTime == null) return null;
    return DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      alarmTime!.hour,
      alarmTime!.minute,
    );
  }

  // Convert Task to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'isCompleted': isCompleted,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'alarmEnabled': alarmEnabled,
      'alarmHour': alarmTime?.hour,
      'alarmMinute': alarmTime?.minute,
      'alarmSoundPath': alarmSoundPath,
      'alarmSoundName': alarmSoundName,
    };
  }

  // Create Task from Map
  factory Task.fromMap(Map<String, dynamic> map) {
    TimeOfDay? alarmTime;
    if (map['alarmHour'] != null && map['alarmMinute'] != null) {
      alarmTime = TimeOfDay(hour: map['alarmHour'], minute: map['alarmMinute']);
    }

    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      dueDate: DateTime.parse(map['dueDate']),
      isCompleted: map['isCompleted'] ?? false,
      priority: map['priority'] ?? 2,
      createdAt: DateTime.parse(map['createdAt']),
      alarmEnabled: map['alarmEnabled'] ?? false,
      alarmTime: alarmTime,
      alarmSoundPath: map['alarmSoundPath'],
      alarmSoundName: map['alarmSoundName'],
    );
  }

  // Copy with changes
  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? isCompleted,
    int? priority,
    DateTime? createdAt,
    bool? alarmEnabled,
    TimeOfDay? alarmTime,
    bool clearAlarmTime = false,
    String? alarmSoundPath,
    bool clearAlarmSound = false,
    String? alarmSoundName,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      alarmTime: clearAlarmTime ? null : (alarmTime ?? this.alarmTime),
      alarmSoundPath: clearAlarmSound ? null : (alarmSoundPath ?? this.alarmSoundPath),
      alarmSoundName: clearAlarmSound ? null : (alarmSoundName ?? this.alarmSoundName),
    );
  }
}

// Simple TimeOfDay class (no Flutter dependency in model)
class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({required this.hour, required this.minute});

  String format() {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeOfDay && hour == other.hour && minute == other.minute;

  @override
  int get hashCode => hour.hashCode ^ minute.hashCode;
}
