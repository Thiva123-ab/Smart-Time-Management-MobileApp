import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/models/app_usage.dart';
import '../data/local/database_helper.dart';
import '../domain/app_category_manager.dart';

class UsageTrackingService {
  static const MethodChannel _channel = MethodChannel('com.focusflow.app/usage');
  static final Map<String, Uint8List> _iconCache = {};

  static String get todayDate => DateFormat('yyyy-MM-dd').format(DateTime.now());

  static Uint8List? getCachedIcon(String packageName) => _iconCache[packageName];

  static Future<bool> hasPermission() async {
    try {
      final bool result = await _channel.invokeMethod('hasUsagePermission');
      return result;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openPermissionSettings() async {
    try {
      await _channel.invokeMethod('openUsageSettings');
    } catch (_) {}
  }

  static Future<bool> hasOverlayPermission() async {
    try {
      final bool result = await _channel.invokeMethod('hasOverlayPermission');
      return result;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  static Future<void> syncLimitsToNative(Map<String, int> limits) async {
    try {
      await _channel.invokeMethod('updateAppLimits', {'limits': limits});
    } catch (_) {}
  }

  static Future<void> setHardcoreStrictMode(bool enabled) async {
    try {
      await _channel.invokeMethod('setHardcoreStrictMode', {'enabled': enabled});
    } catch (_) {}
  }

  static Future<bool> getHardcoreStrictMode() async {
    try {
      final bool? result = await _channel.invokeMethod('getHardcoreStrictMode');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> grantTemporaryPass(String packageName, {int minutes = 5}) async {
    try {
      await _channel.invokeMethod('grantTempPass', {
        'packageName': packageName,
        'minutes': minutes,
      });
    } catch (_) {}
  }

  static Future<int> getTempPassRemainingMinutes(String packageName) async {
    try {
      final int? result = await _channel.invokeMethod('getTempPassRemainingMinutes', {
        'packageName': packageName,
      });
      return result ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> startBlockerService() async {
    try {
      await _channel.invokeMethod('startBlockerService');
    } catch (_) {}
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String subText = 'Schedule Reminder',
  }) async {
    try {
      await _channel.invokeMethod('showNotification', {
        'id': id,
        'title': title,
        'body': body,
        'subText': subText,
      });
    } catch (_) {}
  }

  static Future<bool> hasNotificationPermission() async {
    try {
      final bool? result = await _channel.invokeMethod('hasNotificationPermission');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestNotificationPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (_) {}
  }

  static Future<void> scheduleAlarm({
    required int id,
    required int timeMillis,
    required String title,
    required String body,
    String subText = 'Schedule Reminder',
  }) async {
    try {
      await _channel.invokeMethod('scheduleAlarm', {
        'id': id,
        'timeMillis': timeMillis,
        'title': title,
        'body': body,
        'subText': subText,
      });
    } catch (_) {}
  }

  static Future<void> cancelAlarm(int id) async {
    try {
      await _channel.invokeMethod('cancelAlarm', {'id': id});
    } catch (_) {}
  }

  static Future<void> cancelTaskAlarms(int blockId) async {
    try {
      await _channel.invokeMethod('cancelTaskAlarms', {'blockId': blockId});
    } catch (_) {}
  }

  static Future<Uint8List?> fetchAppIcon(String packageName) async {
    if (_iconCache.containsKey(packageName)) {
      return _iconCache[packageName];
    }
    try {
      final Uint8List? icon = await _channel.invokeMethod('getAppIcon', {'packageName': packageName});
      if (icon != null && icon.isNotEmpty) {
        _iconCache[packageName] = icon;
      }
      return icon;
    } catch (_) {
      return null;
    }
  }

  static Future<List<AppUsage>> fetchTodayUsage() => fetchUsageForDate(DateTime.now());

  static Future<List<AppUsage>> fetchUsageForDate(DateTime targetDate) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    final now = DateTime.now();
    final isToday = targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day;

    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0).millisecondsSinceEpoch;
    final endOfDay = isToday
        ? now.millisecondsSinceEpoch
        : DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59, 999).millisecondsSinceEpoch;

    final permitted = await hasPermission();

    if (permitted) {
      try {
        final List<dynamic>? rawStats = await _channel.invokeMethod('getUsageStats', {
          'startTime': startOfDay,
          'endTime': endOfDay,
        });

        if (rawStats != null && rawStats.isNotEmpty) {
          final list = rawStats.map((item) {
            final pkg = item['packageName'] as String;
            final name = item['appName'] as String;
            final duration = item['durationMinutes'] as int;
            final launches = item['launchCount'] as int? ?? 1;
            final iconBytes = item['appIcon'] as Uint8List?;

            if (iconBytes != null && iconBytes.isNotEmpty) {
              _iconCache[pkg] = iconBytes;
            }

            return AppUsage(
              packageName: pkg,
              appName: name,
              category: AppCategoryManager.getCategoryForPackage(pkg),
              startTime: startOfDay,
              endTime: endOfDay,
              durationMinutes: duration,
              date: dateStr,
              launchCount: launches,
              appIcon: iconBytes ?? _iconCache[pkg],
            );
          }).toList();

          return list;
        } else if (isToday) {
          // Permitted and it is today, but rawStats is empty (e.g. just after 12:00 midnight)
          // Return empty list so today starts fresh from 0!
          return [];
        }
      } catch (_) {}
    }

    // Fallback: check SQLite database for historical saved usage for that date
    try {
      final dbList = await DatabaseHelper.instance.getUsageForDate(dateStr);
      if (dbList.isNotEmpty) {
        return dbList.map((app) {
          final cachedIcon = _iconCache[app.packageName];
          if (cachedIcon != null && app.appIcon == null) {
            return app.copyWith(appIcon: cachedIcon);
          }
          return app;
        }).toList();
      }
    } catch (_) {}

    // Do not return fake sample data; return empty list if not permitted
    return [];
  }
}
