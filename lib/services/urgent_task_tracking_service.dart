import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local/database_helper.dart';
import '../data/models/time_block.dart';
import '../data/models/time_sub_task.dart';

/// Service to track urgent interruptions, errands, or unexpected tasks in real time.
/// Operates with persistent timestamps so timing continues uninterrupted across app
/// restarts, navigation, backgrounding, or screen exits until explicitly stopped.
class UrgentTaskTrackingService extends ChangeNotifier {
  static final UrgentTaskTrackingService instance = UrgentTaskTrackingService._internal();

  UrgentTaskTrackingService._internal();

  static const String _prefKeyIsTracking = 'urgent_is_tracking';
  static const String _prefKeyStartTime = 'urgent_start_time_ms';
  static const String _prefKeyTitle = 'urgent_tracking_title';
  static const String _prefKeyParentBlockId = 'urgent_parent_block_id';
  static const String _prefKeyParentTaskName = 'urgent_parent_task_name';

  bool _isTracking = false;
  DateTime? _startTime;
  String _title = 'Urgent Task / Errand';
  int? _parentBlockId;
  String? _parentTaskName;
  bool _isInitialized = false;
  Timer? _ticker;

  bool get isTracking => _isTracking;
  DateTime? get startTime => _startTime;
  String get title => _title;
  int? get parentBlockId => _parentBlockId;
  String? get parentTaskName => _parentTaskName;
  bool get isInitialized => _isInitialized;

  /// Returns real elapsed seconds calculated against DateTime.now() and persisted start timestamp.
  /// Never resets to 0 even if the app was closed or backgrounded.
  int get currentElapsedSeconds {
    if (!_isTracking || _startTime == null) return 0;
    final diff = DateTime.now().difference(_startTime!).inSeconds;
    return diff > 0 ? diff : 0;
  }

  void _startInternalTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  void _stopInternalTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Initialize state from SharedPreferences on app launch or screen opening.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      _isTracking = prefs.getBool(_prefKeyIsTracking) ?? false;
      final startMs = prefs.getInt(_prefKeyStartTime);
      if (_isTracking && startMs != null) {
        _startTime = DateTime.fromMillisecondsSinceEpoch(startMs);
        _title = prefs.getString(_prefKeyTitle) ?? 'Urgent Task / Errand';
        _parentBlockId = prefs.getInt(_prefKeyParentBlockId);
        _parentTaskName = prefs.getString(_prefKeyParentTaskName);
        _startInternalTicker();
      } else {
        _isTracking = false;
        _startTime = null;
        _parentBlockId = null;
        _parentTaskName = null;
        _stopInternalTicker();
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing UrgentTaskTrackingService: $e');
    }
  }

  /// Start live tracking of an urgent task / unexpected interruption.
  Future<void> startTracking({
    String title = 'Urgent Task / Errand',
    int? parentBlockId,
    String? parentTaskName,
  }) async {
    _isTracking = true;
    _startTime = DateTime.now();
    _title = title.trim().isEmpty ? 'Urgent Task / Errand' : title.trim();
    _parentBlockId = parentBlockId;
    _parentTaskName = parentTaskName;

    _startInternalTicker();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyIsTracking, true);
      await prefs.setInt(_prefKeyStartTime, _startTime!.millisecondsSinceEpoch);
      await prefs.setString(_prefKeyTitle, _title);
      if (parentBlockId != null) {
        await prefs.setInt(_prefKeyParentBlockId, parentBlockId);
      } else {
        await prefs.remove(_prefKeyParentBlockId);
      }
      if (parentTaskName != null) {
        await prefs.setString(_prefKeyParentTaskName, parentTaskName);
      } else {
        await prefs.remove(_prefKeyParentTaskName);
      }
    } catch (e) {
      debugPrint('Error saving urgent task tracking start: $e');
    }

    notifyListeners();
  }

  /// Stop tracking, calculate actual duration, insert completed TimeBlock into SQLite,
  /// optionally link to parent task as sub-task, and clear tracking state.
  /// Existing past records are strictly preserved without deletion.
  Future<TimeBlock?> stopAndSaveTracking({DateTime? customDate, String? notes}) async {
    if (!_isTracking || _startTime == null) {
      await cancelTracking();
      return null;
    }

    final startDt = _startTime!;
    final endDt = DateTime.now();
    final elapsedSec = currentElapsedSeconds;
    int durationMin = (elapsedSec / 60).round();
    if (durationMin < 1) durationMin = 1;

    final dateStr = customDate != null
        ? DateFormat('yyyy-MM-dd').format(customDate)
        : DateFormat('yyyy-MM-dd').format(startDt);

    final m = elapsedSec ~/ 60;
    final s = elapsedSec % 60;
    final formattedStopwatch = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    final noteDetail = StringBuffer();
    noteDetail.write('Urgent Task recorded via Live Timer ($formattedStopwatch).');
    if (_parentTaskName != null && _parentTaskName!.isNotEmpty) {
      noteDetail.write(' Interrupted while working on: "$_parentTaskName".');
    }
    if (notes != null && notes.trim().isNotEmpty) {
      noteDetail.write(' $notes');
    }

    final block = TimeBlock(
      title: _title.isNotEmpty ? _title : 'Urgent Task / Errand',
      category: 'Other',
      date: dateStr,
      startTime: DateFormat('hh:mm a').format(startDt),
      endTime: DateFormat('hh:mm a').format(endDt),
      durationMinutes: durationMin,
      isCompleted: true,
      notes: noteDetail.toString(),
    );

    // Save into database safely preserving all other records
    await DatabaseHelper.instance.insertTimeBlock(block);

    // Also link under parent block if started from within a specific time block
    if (_parentBlockId != null) {
      try {
        final subTask = TimeSubTask(
          blockId: _parentBlockId!,
          title: '⚡ $_title',
          durationMinutes: durationMin,
          startTime: DateFormat('hh:mm a').format(startDt),
          endTime: DateFormat('hh:mm a').format(endDt),
          isCompleted: true,
          isUrgent: true,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await DatabaseHelper.instance.insertTimeSubTask(subTask);
      } catch (e) {
        debugPrint('Error inserting urgent sub-task: $e');
      }
    }

    await cancelTracking();
    return block;
  }

  /// Discard tracking without saving and clear persistent state.
  Future<void> cancelTracking() async {
    _isTracking = false;
    _startTime = null;
    _title = 'Urgent Task / Errand';
    _parentBlockId = null;
    _parentTaskName = null;
    _stopInternalTicker();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyIsTracking);
      await prefs.remove(_prefKeyStartTime);
      await prefs.remove(_prefKeyTitle);
      await prefs.remove(_prefKeyParentBlockId);
      await prefs.remove(_prefKeyParentTaskName);
    } catch (e) {
      debugPrint('Error clearing urgent tracking state: $e');
    }

    notifyListeners();
  }
}
