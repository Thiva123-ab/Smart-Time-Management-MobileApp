class Goal {
  final int? id;
  final String title;
  final String category;
  final int targetMinutes;
  final int completedMinutes;
  final String date;
  final String status; // 'IN_PROGRESS', 'COMPLETED'

  Goal({
    this.id,
    required this.title,
    required this.category,
    required this.targetMinutes,
    this.completedMinutes = 0,
    required this.date,
    this.status = 'IN_PROGRESS',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'targetMinutes': targetMinutes,
      'completedMinutes': completedMinutes,
      'date': date,
      'status': status,
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'],
      title: map['title'],
      category: map['category'],
      targetMinutes: map['targetMinutes'],
      completedMinutes: map['completedMinutes'] ?? 0,
      date: map['date'],
      status: map['status'] ?? 'IN_PROGRESS',
    );
  }

  Goal copyWith({int? completedMinutes, String? status}) {
    return Goal(
      id: id,
      title: title,
      category: category,
      targetMinutes: targetMinutes,
      completedMinutes: completedMinutes ?? this.completedMinutes,
      date: date,
      status: status ?? this.status,
    );
  }
}
