import 'dart:convert';
import '../data/local/database_helper.dart';
import 'usage_tracking_service.dart';

class DataExportService {
  /// Exports all database tables as a comprehensive JSON string
  static Future<String> exportAllDataAsJson() async {
    final db = DatabaseHelper.instance;
    final today = UsageTrackingService.todayDate;

    final usages = await db.getUsageForDate(today);
    final goals = await db.getGoalsForDate(today);
    final focusSessions = await db.getFocusSessionsForDate(today);
    final budgets = await db.getAllBudgets();
    final achievements = await db.getAllAchievements();
    final recentScores = await db.getRecentScores(30);

    final exportPayload = {
      'app': 'FocusFlow',
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'usages': usages.map((u) => u.toMap()).toList(),
      'goals': goals.map((g) => g.toMap()).toList(),
      'focusSessions': focusSessions.map((s) => s.toMap()).toList(),
      'budgets': budgets.map((b) => b.toMap()).toList(),
      'recentScores': recentScores.map((s) => s.toMap()).toList(),
      'achievements': achievements.map((a) => a.toMap()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(exportPayload);
  }

  /// Exports today's app usage as a CSV formatted string
  static Future<String> exportUsageAsCsv() async {
    final db = DatabaseHelper.instance;
    final today = UsageTrackingService.todayDate;
    final usages = await db.getUsageForDate(today);

    final buffer = StringBuffer();
    buffer.writeln('Date,App Name,Package Name,Category,Duration (Minutes),Launch Count');

    for (var u in usages) {
      buffer.writeln(
        '${u.date},"${u.appName}","${u.packageName}","${u.category}",${u.durationMinutes},${u.launchCount}',
      );
    }

    return buffer.toString();
  }
}
