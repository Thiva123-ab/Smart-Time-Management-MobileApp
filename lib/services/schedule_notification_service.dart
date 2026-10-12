import 'dart:async';
import 'package:intl/intl.dart';
import '../data/local/database_helper.dart';
import 'usage_tracking_service.dart';

class ScheduleNotificationService {
  static final ScheduleNotificationService instance = ScheduleNotificationService._internal();

  ScheduleNotificationService._internal();

  Timer? _checkerTimer;
  final Set<String> _notifiedKeys = {};

  void start() {
    _checkerTimer?.cancel();
    // Run an initial check immediately and sync native alarms
    _checkScheduleAndNotify();
    rescheduleNativeAlarms();

    // Run periodically every 20 seconds for in-app real-time precision
    _checkerTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _checkScheduleAndNotify();
    });
  }

  void stop() {
    _checkerTimer?.cancel();
    _checkerTimer = null;
  }

  /// Re-syncs native AlarmManager exact alarms for all active tasks of today.
  /// This ensures notifications fire reliably even if the app is closed or phone is locked.
  Future<void> rescheduleNativeAlarms() async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    final blocks = await DatabaseHelper.instance.getTimeBlocksForDate(todayStr);
    if (blocks.isEmpty) return;

    final activeBlocks = blocks.where((b) => !b.isCompleted).toList();
    activeBlocks.sort((a, b) {
      final aMin = _parseTimeToMinutes(a.startTime);
      final bMin = _parseTimeToMinutes(b.startTime);
      return aMin.compareTo(bMin);
    });

    for (int i = 0; i < activeBlocks.length; i++) {
      final block = activeBlocks[i];
      final blockId = block.id ?? (i + 1);
      final startMin = _parseTimeToMinutes(block.startTime);
      final endMin = _parseTimeToMinutes(block.endTime);
      final duration = endMin > startMin ? (endMin - startMin) : block.durationMinutes;

      // 1. Alarm: 5 minutes BEFORE task starts
      final preStartMin = startMin - 5;
      if (preStartMin >= 0) {
        final preStartTime = DateTime(now.year, now.month, now.day, preStartMin ~/ 60, preStartMin % 60);
        if (preStartTime.isAfter(now)) {
          await UsageTrackingService.scheduleAlarm(
            id: blockId * 100 + 1,
            timeMillis: preStartTime.millisecondsSinceEpoch,
            title: '🔔 Upcoming Task: "${block.title}"',
            body: 'Starts in 5 minutes (at ${block.startTime}). Get ready to focus!',
            subText: 'Starting in 5 mins',
          );
        }
      }

      // 2. Alarm: At task start time
      final startTime = DateTime(now.year, now.month, now.day, startMin ~/ 60, startMin % 60);
      if (startTime.isAfter(now)) {
        await UsageTrackingService.scheduleAlarm(
          id: blockId * 100 + 2,
          timeMillis: startTime.millisecondsSinceEpoch,
          title: '⏰ Task Started: "${block.title}"',
          body: '${block.category} session from ${block.startTime} to ${block.endTime}. Stay focused!',
          subText: 'Task Started',
        );
      }

      // 3. Alarms: Every 30 minutes while task is in progress
      for (int elapsed = 30; elapsed < duration; elapsed += 30) {
        final checkMin = startMin + elapsed;
        final checkTime = DateTime(now.year, now.month, now.day, checkMin ~/ 60, checkMin % 60);
        if (checkTime.isAfter(now)) {
          final remaining = endMin - checkMin;
          final remainingStr = _formatRemaining(remaining);
          await UsageTrackingService.scheduleAlarm(
            id: blockId * 100 + 10 + (elapsed ~/ 30),
            timeMillis: checkTime.millisecondsSinceEpoch,
            title: '⏱️ In Progress (${elapsed}m): "${block.title}"',
            body: 'You have spent $elapsed mins on this task. Remaining time: $remainingStr (ends at ${block.endTime}).',
            subText: '30-Min Checkpoint',
          );
        }
      }

      // 4. Alarm: 5 minutes BEFORE task ends
      final preEndMin = endMin - 5;
      if (preEndMin > startMin) {
        final preEndTime = DateTime(now.year, now.month, now.day, preEndMin ~/ 60, preEndMin % 60);
        if (preEndTime.isAfter(now)) {
          String nextTaskInfo = 'No more tasks scheduled for today. Great job!';
          if (i + 1 < activeBlocks.length) {
            final nextBlock = activeBlocks[i + 1];
            nextTaskInfo = 'Next Up: "${nextBlock.title}" at ${nextBlock.startTime} (${nextBlock.category})';
          }
          await UsageTrackingService.scheduleAlarm(
            id: blockId * 100 + 99,
            timeMillis: preEndTime.millisecondsSinceEpoch,
            title: '⚠️ 5 Mins Remaining: "${block.title}"',
            body: 'Task ends at ${block.endTime}!\n$nextTaskInfo',
            subText: 'Almost Finished',
          );
        }
      }
    }
  }

  Future<void> _checkScheduleAndNotify() async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final currentMinutes = now.hour * 60 + now.minute;

    final blocks = await DatabaseHelper.instance.getTimeBlocksForDate(todayStr);
    if (blocks.isEmpty) return;

    final activeBlocks = blocks.where((b) => !b.isCompleted).toList();
    activeBlocks.sort((a, b) {
      final aMin = _parseTimeToMinutes(a.startTime);
      final bMin = _parseTimeToMinutes(b.startTime);
      return aMin.compareTo(bMin);
    });

    for (int i = 0; i < activeBlocks.length; i++) {
      final block = activeBlocks[i];
      final blockId = block.id ?? (i + 1);
      final startMin = _parseTimeToMinutes(block.startTime);
      final endMin = _parseTimeToMinutes(block.endTime);

      // 1. Notification: 5 minutes BEFORE task starts
      final preStartMin = startMin - 5;
      if (currentMinutes == preStartMin && preStartMin >= 0) {
        final key = '${blockId}_prestart_${now.day}_$preStartMin';
        if (!_notifiedKeys.contains(key)) {
          _notifiedKeys.add(key);
          await UsageTrackingService.showNotification(
            id: blockId * 100 + 1,
            title: '🔔 Upcoming Task: "${block.title}"',
            body: 'Starts in 5 minutes (at ${block.startTime}). Get ready to focus!',
            subText: 'Starting in 5 mins',
          );
        }
      }

      // 2. Notification: At task start time
      if (currentMinutes == startMin) {
        final key = '${blockId}_start_${now.day}_$startMin';
        if (!_notifiedKeys.contains(key)) {
          _notifiedKeys.add(key);
          await UsageTrackingService.showNotification(
            id: blockId * 100 + 2,
            title: '⏰ Task Started: "${block.title}"',
            body: '${block.category} session from ${block.startTime} to ${block.endTime}. Stay focused!',
            subText: 'Task Started',
          );
        }
      }

      // 3. Notification: Every 30 minutes while task is ongoing (with remaining time)
      if (currentMinutes > startMin && currentMinutes < endMin) {
        final elapsed = currentMinutes - startMin;
        if (elapsed > 0 && elapsed % 30 == 0) {
          final key = '${blockId}_interval_${now.day}_$elapsed';
          if (!_notifiedKeys.contains(key)) {
            _notifiedKeys.add(key);
            final remainingMin = endMin - currentMinutes;
            final remainingStr = _formatRemaining(remainingMin);
            await UsageTrackingService.showNotification(
              id: blockId * 100 + 10 + (elapsed ~/ 30),
              title: '⏱️ In Progress (${elapsed}m): "${block.title}"',
              body: 'You have spent $elapsed mins on this task. Remaining time: $remainingStr (ends at ${block.endTime}).',
              subText: '30-Min Checkpoint',
            );
          }
        }
      }

      // 4. Notification: 5 minutes BEFORE task ends (with next task preview)
      final preEndMin = endMin - 5;
      if (currentMinutes == preEndMin && preEndMin > startMin) {
        final key = '${blockId}_ending_soon_${now.day}_$preEndMin';
        if (!_notifiedKeys.contains(key)) {
          _notifiedKeys.add(key);

          String nextTaskInfo = 'No more tasks scheduled for today. Great job!';
          if (i + 1 < activeBlocks.length) {
            final nextBlock = activeBlocks[i + 1];
            nextTaskInfo = 'Next Up: "${nextBlock.title}" at ${nextBlock.startTime} (${nextBlock.category})';
          }

          await UsageTrackingService.showNotification(
            id: blockId * 100 + 99,
            title: '⚠️ 5 Mins Remaining: "${block.title}"',
            body: 'Task ends at ${block.endTime}!\n$nextTaskInfo',
            subText: 'Almost Finished',
          );
        }
      }
    }
  }

  String _formatRemaining(int minutes) {
    if (minutes <= 0) return '0 mins';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h hr $m mins';
    if (h > 0) return '$h hr';
    return '$m mins';
  }

  int _parseTimeToMinutes(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      final hm = parts[0].split(':');
      int h = int.parse(hm[0]);
      int m = int.parse(hm[1]);
      if (parts.length > 1) {
        final period = parts[1].toUpperCase();
        if (period == 'PM' && h < 12) h += 12;
        if (period == 'AM' && h == 12) h = 0;
      }
      return h * 60 + m;
    } catch (_) {
      return 0;
    }
  }
}
