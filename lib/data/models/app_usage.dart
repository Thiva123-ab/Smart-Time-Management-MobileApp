class AppUsage {
  final int? id;
  final String packageName;
  final String appName;
  final String category;
  final int startTime;
  final int endTime;
  final int durationMinutes;
  final String date; // yyyy-MM-dd
  final int launchCount;

  AppUsage({
    this.id,
    required this.packageName,
    required this.appName,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.date,
    this.launchCount = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'packageName': packageName,
      'appName': appName,
      'category': category,
      'startTime': startTime,
      'endTime': endTime,
      'durationMinutes': durationMinutes,
      'date': date,
      'launchCount': launchCount,
    };
  }

  factory AppUsage.fromMap(Map<String, dynamic> map) {
    return AppUsage(
      id: map['id'],
      packageName: map['packageName'],
      appName: map['appName'],
      category: map['category'],
      startTime: map['startTime'],
      endTime: map['endTime'],
      durationMinutes: map['durationMinutes'],
      date: map['date'],
      launchCount: map['launchCount'] ?? 1,
    );
  }

  AppUsage copyWith({String? category, int? durationMinutes, int? launchCount}) {
    return AppUsage(
      id: id,
      packageName: packageName,
      appName: appName,
      category: category ?? this.category,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      date: date,
      launchCount: launchCount ?? this.launchCount,
    );
  }
}
