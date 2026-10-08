class TimeBudget {
  final int? id;
  final String category;
  final int limitMinutes;
  final String date;
  final bool enabled;

  TimeBudget({
    this.id,
    required this.category,
    required this.limitMinutes,
    this.date = 'daily_default',
    this.enabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'limitMinutes': limitMinutes,
      'date': date,
      'enabled': enabled ? 1 : 0,
    };
  }

  factory TimeBudget.fromMap(Map<String, dynamic> map) {
    return TimeBudget(
      id: map['id'],
      category: map['category'],
      limitMinutes: map['limitMinutes'],
      date: map['date'] ?? 'daily_default',
      enabled: (map['enabled'] ?? 1) == 1,
    );
  }
}

class AppLimit {
  final int? id;
  final String packageName;
  final String appName;
  final int limitMinutes;
  final String date;
  final bool enabled;

  AppLimit({
    this.id,
    required this.packageName,
    required this.appName,
    required this.limitMinutes,
    this.date = 'daily_default',
    this.enabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'packageName': packageName,
      'appName': appName,
      'limitMinutes': limitMinutes,
      'date': date,
      'enabled': enabled ? 1 : 0,
    };
  }

  factory AppLimit.fromMap(Map<String, dynamic> map) {
    return AppLimit(
      id: map['id'],
      packageName: map['packageName'],
      appName: map['appName'],
      limitMinutes: map['limitMinutes'],
      date: map['date'] ?? 'daily_default',
      enabled: (map['enabled'] ?? 1) == 1,
    );
  }
}
