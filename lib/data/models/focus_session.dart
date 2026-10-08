class FocusSession {
  final int? id;
  final String taskName;
  final int startTime;
  final int endTime;
  final int durationMinutes;
  final bool completed;
  final int distractionCount;
  final String date;

  FocusSession({
    this.id,
    required this.taskName,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.completed,
    this.distractionCount = 0,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskName': taskName,
      'startTime': startTime,
      'endTime': endTime,
      'durationMinutes': durationMinutes,
      'completed': completed ? 1 : 0,
      'distractionCount': distractionCount,
      'date': date,
    };
  }

  factory FocusSession.fromMap(Map<String, dynamic> map) {
    return FocusSession(
      id: map['id'],
      taskName: map['taskName'],
      startTime: map['startTime'],
      endTime: map['endTime'],
      durationMinutes: map['durationMinutes'],
      completed: (map['completed'] ?? 1) == 1,
      distractionCount: map['distractionCount'] ?? 0,
      date: map['date'],
    );
  }
}

class PomodoroSession {
  final int? id;
  final int focusMinutes;
  final int breakMinutes;
  final int startTime;
  final int endTime;
  final bool completed;
  final String date;

  PomodoroSession({
    this.id,
    required this.focusMinutes,
    required this.breakMinutes,
    required this.startTime,
    required this.endTime,
    required this.completed,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'focusMinutes': focusMinutes,
      'breakMinutes': breakMinutes,
      'startTime': startTime,
      'endTime': endTime,
      'completed': completed ? 1 : 0,
      'date': date,
    };
  }

  factory PomodoroSession.fromMap(Map<String, dynamic> map) {
    return PomodoroSession(
      id: map['id'],
      focusMinutes: map['focusMinutes'],
      breakMinutes: map['breakMinutes'],
      startTime: map['startTime'],
      endTime: map['endTime'],
      completed: (map['completed'] ?? 1) == 1,
      date: map['date'],
    );
  }
}
