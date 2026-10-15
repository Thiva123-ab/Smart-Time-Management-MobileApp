class DailyNote {
  final int? id;
  final String date; // yyyy-MM-dd
  final String title;
  final String content;
  final String category; // Idea, Note, Important, Reflection, Todo
  final String? colorHex;
  final bool isPinned;
  final int createdAt;
  final int updatedAt;

  DailyNote({
    this.id,
    required this.date,
    required this.title,
    required this.content,
    this.category = 'Idea',
    this.colorHex,
    this.isPinned = false,
    int? createdAt,
    int? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'title': title,
      'content': content,
      'category': category,
      'colorHex': colorHex,
      'isPinned': isPinned ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory DailyNote.fromMap(Map<String, dynamic> map) {
    return DailyNote(
      id: map['id'],
      date: map['date'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      category: map['category'] ?? 'Idea',
      colorHex: map['colorHex'],
      isPinned: (map['isPinned'] ?? 0) == 1,
      createdAt: map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  DailyNote copyWith({
    int? id,
    String? date,
    String? title,
    String? content,
    String? category,
    String? colorHex,
    bool? isPinned,
    int? createdAt,
    int? updatedAt,
  }) {
    return DailyNote(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      colorHex: colorHex ?? this.colorHex,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
