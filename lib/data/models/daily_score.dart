class DailyScore {
  final String date;
  final int score;
  final int productiveMinutes;
  final int distractingMinutes;
  final int goalCompletionPercentage;
  final int focusMinutes;

  DailyScore({
    required this.date,
    required this.score,
    required this.productiveMinutes,
    required this.distractingMinutes,
    required this.goalCompletionPercentage,
    required this.focusMinutes,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'score': score,
      'productiveMinutes': productiveMinutes,
      'distractingMinutes': distractingMinutes,
      'goalCompletionPercentage': goalCompletionPercentage,
      'focusMinutes': focusMinutes,
    };
  }

  factory DailyScore.fromMap(Map<String, dynamic> map) {
    return DailyScore(
      date: map['date'],
      score: map['score'],
      productiveMinutes: map['productiveMinutes'],
      distractingMinutes: map['distractingMinutes'],
      goalCompletionPercentage: map['goalCompletionPercentage'],
      focusMinutes: map['focusMinutes'],
    );
  }
}

class Achievement {
  final String achievementId;
  final String title;
  final String description;
  final bool isUnlocked;
  final int? unlockedDate;

  Achievement({
    required this.achievementId,
    required this.title,
    required this.description,
    this.isUnlocked = false,
    this.unlockedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'achievementId': achievementId,
      'title': title,
      'description': description,
      'isUnlocked': isUnlocked ? 1 : 0,
      'unlockedDate': unlockedDate,
    };
  }

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      achievementId: map['achievementId'],
      title: map['title'],
      description: map['description'],
      isUnlocked: (map['isUnlocked'] ?? 0) == 1,
      unlockedDate: map['unlockedDate'],
    );
  }

  Achievement copyWith({bool? isUnlocked, int? unlockedDate}) {
    return Achievement(
      achievementId: achievementId,
      title: title,
      description: description,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedDate: unlockedDate ?? this.unlockedDate,
    );
  }
}
