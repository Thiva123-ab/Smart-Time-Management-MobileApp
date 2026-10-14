class TimeSubTask {
  final int? id;
  final int blockId;
  final String title;
  final int durationMinutes;
  final String? startTime;
  final String? endTime;
  final bool isCompleted;
  final bool isUrgent;
  final int createdAt;

  TimeSubTask({
    this.id,
    required this.blockId,
    required this.title,
    required this.durationMinutes,
    this.startTime,
    this.endTime,
    this.isCompleted = false,
    this.isUrgent = true,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'blockId': blockId,
      'title': title,
      'durationMinutes': durationMinutes,
      'startTime': startTime,
      'endTime': endTime,
      'isCompleted': isCompleted ? 1 : 0,
      'isUrgent': isUrgent ? 1 : 0,
      'createdAt': createdAt,
    };
  }

  factory TimeSubTask.fromMap(Map<String, dynamic> map) {
    return TimeSubTask(
      id: map['id'],
      blockId: map['blockId'] ?? 0,
      title: map['title'] ?? '',
      durationMinutes: map['durationMinutes'] ?? 15,
      startTime: map['startTime'],
      endTime: map['endTime'],
      isCompleted: (map['isCompleted'] ?? 0) == 1,
      isUrgent: (map['isUrgent'] ?? 1) == 1,
      createdAt: map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  TimeSubTask copyWith({
    int? id,
    int? blockId,
    String? title,
    int? durationMinutes,
    String? startTime,
    String? endTime,
    bool? isCompleted,
    bool? isUrgent,
    int? createdAt,
  }) {
    return TimeSubTask(
      id: id ?? this.id,
      blockId: blockId ?? this.blockId,
      title: title ?? this.title,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isCompleted: isCompleted ?? this.isCompleted,
      isUrgent: isUrgent ?? this.isUrgent,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
