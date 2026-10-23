class DailyHabitActivity {
  final String date; // 'yyyy-MM-dd'
  final int focusMinutes;
  final int completedTasks;
  final int completedGoals;
  final int productivityScore;
  final int productiveAppMinutes;

  DailyHabitActivity({
    required this.date,
    this.focusMinutes = 0,
    this.completedTasks = 0,
    this.completedGoals = 0,
    this.productivityScore = 0,
    this.productiveAppMinutes = 0,
  });

  bool get hasActivity =>
      focusMinutes > 0 ||
      completedTasks > 0 ||
      completedGoals > 0 ||
      productivityScore > 0 ||
      productiveAppMinutes > 0;

  int get totalProductiveMinutes => focusMinutes + productiveAppMinutes;

  /// Returns 0..4 intensity level for the heatmap cell.
  int get intensityLevel {
    final effectiveMins = totalProductiveMinutes;
    if (effectiveMins >= 120 || productivityScore >= 85) return 4;
    if (effectiveMins >= 60 || productivityScore >= 70) return 3;
    if (effectiveMins >= 30 || productivityScore >= 50 || completedTasks >= 2) return 2;
    if (effectiveMins > 0 || completedTasks > 0 || completedGoals > 0 || productivityScore > 0) return 1;
    return 0;
  }
}

class HabitHeatmapStats {
  final Map<String, DailyHabitActivity> activityMap;
  final int totalDays;
  final int activeDaysCount;
  final int currentStreak;
  final int longestStreak;
  final int totalFocusMinutes;
  final double averageDailyScore;

  HabitHeatmapStats({
    required this.activityMap,
    required this.totalDays,
    required this.activeDaysCount,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalFocusMinutes,
    required this.averageDailyScore,
  });

  double get activityRate => totalDays > 0 ? (activeDaysCount / totalDays) * 100 : 0.0;
}
