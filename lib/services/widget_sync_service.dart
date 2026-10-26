import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/local/database_helper.dart';

/// Service responsible for keeping the Android home screen widget synchronized
/// with the user's latest focus time, daily productivity score, streaks, and targets.
class WidgetSyncService {
  WidgetSyncService._internal();
  static final WidgetSyncService instance = WidgetSyncService._internal();

  static const MethodChannel _channel = MethodChannel('com.focusflow.app/usage');

  bool _isInitialized = false;
  Function(String action)? _onWidgetActionCallback;

  /// Initializes the service and registers callback for real-time widget intent actions
  void initialize({Function(String action)? onAction}) {
    if (_isInitialized) {
      if (onAction != null) _onWidgetActionCallback = onAction;
      return;
    }
    _isInitialized = true;
    _onWidgetActionCallback = onAction;

    if (Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onWidgetActionTriggered') {
          final action = call.arguments as String?;
          if (action != null && _onWidgetActionCallback != null) {
            _onWidgetActionCallback!(action);
          }
        }
      });
    }
  }

  /// Queries SQLite analytics and updates the native Android widget
  Future<void> syncWidgetData({
    int? overrideScore,
    int? overrideFocusMins,
    bool isFocusing = false,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      final db = DatabaseHelper.instance;
      final heatmapStats = await db.getHabitHeatmapStats(daysCount: 30);

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final todayActivity = heatmapStats.activityMap[todayStr];

      // 1. Focus duration
      final focusMins = overrideFocusMins ?? (todayActivity?.focusMinutes ?? 0);

      // 2. Productivity score
      int score;
      if (overrideScore != null) {
        score = overrideScore;
      } else if (todayActivity != null && todayActivity.hasActivity) {
        score = todayActivity.productivityScore;
      } else {
        score = heatmapStats.averageDailyScore > 0
            ? heatmapStats.averageDailyScore.round()
            : 80;
      }
      if (score < 0) score = 0;
      if (score > 100) score = 100;

      // 3. Grade
      final grade = score >= 90
          ? 'Grade A+'
          : (score >= 80
              ? 'Grade A'
              : (score >= 70
                  ? 'Grade B'
                  : (score >= 60 ? 'Grade C' : 'Developing')));

      // 4. Streak & completed targets
      final streakDays = heatmapStats.currentStreak > 0 ? heatmapStats.currentStreak : 1;
      final tasksDone = (todayActivity?.completedTasks ?? 0) + (todayActivity?.completedGoals ?? 0);

      // 5. Formatted timestamp
      final timeStr = DateFormat('h:mm a').format(now);

      await _channel.invokeMethod('updateWidgetData', {
        'score': score,
        'grade': grade,
        'focusMinutes': focusMins,
        'streakDays': streakDays,
        'completedTasks': tasksDone,
        'isFocusing': isFocusing,
        'lastSync': timeStr,
      });
    } catch (_) {
      // Gracefully silent on widget update errors
    }
  }

  /// Checks if the app was launched by tapping "Start Focus" on the widget
  Future<String?> checkInitialWidgetAction() async {
    if (!Platform.isAndroid) return null;
    try {
      final action = await _channel.invokeMethod<String>('getInitialWidgetAction');
      return action;
    } catch (_) {
      return null;
    }
  }
}
