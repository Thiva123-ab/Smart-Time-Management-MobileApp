class TimeBlock {
  final int? id;
  final String title;
  final String category;
  final String date; // YYYY-MM-DD
  final String startTime; // '08:30 AM' or '08:30'
  final String endTime; // '10:00 AM' or '10:00'
  final int durationMinutes;
  final bool isCompleted;
  final String? notes;

  TimeBlock({
    this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.isCompleted = false,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'durationMinutes': durationMinutes,
      'isCompleted': isCompleted ? 1 : 0,
      'notes': notes,
    };
  }

  factory TimeBlock.fromMap(Map<String, dynamic> map) {
    return TimeBlock(
      id: map['id'],
      title: map['title'] ?? '',
      category: map['category'] ?? 'General',
      date: map['date'] ?? '',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      durationMinutes: map['durationMinutes'] ?? 30,
      isCompleted: (map['isCompleted'] ?? 0) == 1,
      notes: map['notes'],
    );
  }

  TimeBlock copyWith({
    int? id,
    String? title,
    String? category,
    String? date,
    String? startTime,
    String? endTime,
    int? durationMinutes,
    bool? isCompleted,
    String? notes,
  }) {
    return TimeBlock(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
    );
  }
}
