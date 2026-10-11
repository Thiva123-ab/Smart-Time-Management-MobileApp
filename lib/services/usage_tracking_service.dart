import 'dart:typed_data';
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

    // Return sample starter data only if permission is not granted yet
    if (!permitted) {
      return _getSampleData(dateStr, startOfDay, endOfDay);
    }

    return [];
  }

  static List<AppUsage> _getSampleData(String date, int startOfDay, int endOfDay) {
    return [
      AppUsage(
        packageName: 'com.google.android.youtube',
        appName: 'YouTube',
        category: AppCategoryManager.categoryEntertainment,
        startTime: startOfDay,
        endTime: endOfDay,
        durationMinutes: 85,
        date: date,
        launchCount: 14,
      ),
      AppUsage(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        category: AppCategoryManager.categorySocial,
        startTime: startOfDay,
        endTime: endOfDay,
        durationMinutes: 45,
        date: date,
        launchCount: 22,
      ),
      AppUsage(
        packageName: 'com.whatsapp',
        appName: 'WhatsApp',
        category: AppCategoryManager.categoryCommunication,
        startTime: startOfDay,
        endTime: endOfDay,
        durationMinutes: 40,
        date: date,
        launchCount: 28,
      ),
      AppUsage(
        packageName: 'org.coursera.android',
        appName: 'Coursera',
        category: AppCategoryManager.categoryEducation,
        startTime: startOfDay,
        endTime: endOfDay,
        durationMinutes: 75,
        date: date,
        launchCount: 4,
      ),
      AppUsage(
        packageName: 'notion.id',
        appName: 'Notion',
        category: AppCategoryManager.categoryProductivity,
        startTime: startOfDay,
        endTime: endOfDay,
        durationMinutes: 60,
        date: date,
        launchCount: 8,
      ),
      AppUsage(
        packageName: 'com.android.chrome',
        appName: 'Chrome',
        category: AppCategoryManager.categoryBrowser,
        startTime: startOfDay,
        endTime: endOfDay,
        durationMinutes: 30,
        date: date,
        launchCount: 11,
      ),
    ];
  }
}
