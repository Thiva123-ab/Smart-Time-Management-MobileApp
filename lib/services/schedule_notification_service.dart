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
    // Run an initial check immediately
    _checkScheduleAndNotify();
    // Run periodically every 20 seconds to be precise
    _checkerTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _checkScheduleAndNotify();
    });
  }

  void stop() {
    _checkerTimer?.cancel();
    _checkerTimer = null;
  }

  Future<void> _checkScheduleAndNotify() async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final currentMinutes = now.hour * 60 + now.minute;

    // Fetch today's scheduled time blocks
    final blocks = await DatabaseHelper.instance.getTimeBlocksForDate(todayStr);
    if (blocks.isEmpty) return;

    // Filter incomplete tasks and sort by start time
    final activeBlocks = blocks.where((b) => !b.isCompleted).toList();
    activeBlocks.sort((a, b) {
      final aMin = _parseTimeToMinutes(a.startTime);
      final bMin = _parseTimeToMinutes(b.startTime);
      return aMin.compareTo(bMin);
    });

    for (int i = 0; i < activeBlocks.length; i++) {
      final block = activeBlocks[i];
      final startMin = _parseTimeToMinutes(block.startTime);
      final endMin = _parseTimeToMinutes(block.endTime);

      // 1. Task start notification (at task start time)
      if (currentMinutes == startMin) {
        final key = '${block.id}_start_${now.day}_$startMin';
        if (!_notifiedKeys.contains(key)) {
          _notifiedKeys.add(key);
          await UsageTrackingService.showNotification(
            id: (block.id ?? 1) * 10,
            title: '⏰ Task Started: ${block.title}',
            body: '${block.category} session from ${block.startTime} to ${block.endTime}. Stay focused!',
            subText: 'Scheduled Task',
          );
        }
      }

      // 2. Periodic every 30-minute interval notifications while the task is ongoing
      if (currentMinutes > startMin && currentMinutes < endMin) {
        final elapsed = currentMinutes - startMin;
        if (elapsed > 0 && elapsed % 30 == 0) {
          final key = '${block.id}_interval_${now.day}_$elapsed';
          if (!_notifiedKeys.contains(key)) {
            _notifiedKeys.add(key);
            final remainingMin = endMin - currentMinutes;
            await UsageTrackingService.showNotification(
              id: (block.id ?? 1) * 10 + (elapsed ~/ 30),
              title: '⏱️ In Progress (${elapsed}m): ${block.title}',
              body: 'You have been working for $elapsed mins. $remainingMin mins remaining until completion.',
              subText: '30-Minute Checkpoint',
            );
          }
        }
      }

      // 3. 5-minute pre-end notification with next upcoming task preview
      final fiveMinBefore = endMin - 5;
      if (currentMinutes == fiveMinBefore && fiveMinBefore > startMin) {
        final key = '${block.id}_ending_soon_${now.day}_$fiveMinBefore';
        if (!_notifiedKeys.contains(key)) {
          _notifiedKeys.add(key);

          // Find the next task in schedule
          String nextTaskInfo = 'No more tasks scheduled for today. Great job!';
          if (i + 1 < activeBlocks.length) {
            final nextBlock = activeBlocks[i + 1];
            nextTaskInfo = 'Next Up: "${nextBlock.title}" at ${nextBlock.startTime} (${nextBlock.category})';
          }

          await UsageTrackingService.showNotification(
            id: (block.id ?? 1) * 10 + 99,
            title: '⚠️ 5 Mins Remaining: "${block.title}"',
            body: 'Task ends at ${block.endTime}!\n$nextTaskInfo',
            subText: 'Almost Finished',
          );
        }
      }
    }
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
