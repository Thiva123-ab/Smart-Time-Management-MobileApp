import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local/database_helper.dart';
import '../data/models/time_block.dart';

class TransportTrackingService extends ChangeNotifier {
  static final TransportTrackingService instance = TransportTrackingService._internal();

  TransportTrackingService._internal();

  static const String _prefKeyIsTracking = 'transport_is_tracking';
  static const String _prefKeyStartTime = 'transport_start_time_ms';
  static const String _prefKeyTitle = 'transport_tracking_title';

  bool _isTracking = false;
  DateTime? _startTime;
  String _title = 'Transport / Commute';
  bool _isInitialized = false;

  bool get isTracking => _isTracking;
  DateTime? get startTime => _startTime;
  String get title => _title;
  bool get isInitialized => _isInitialized;

  /// Returns actual elapsed seconds calculated against true DateTime.now().
  /// This ensures that even if the app was closed, backgrounded, or phone restarted,
  /// the time will never reset from 0 and stays 100% accurate until stopped.
  int get currentElapsedSeconds {
    if (!_isTracking || _startTime == null) return 0;
    final diff = DateTime.now().difference(_startTime!).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Initialize service state from SharedPreferences on app launch or screen open.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isTracking = prefs.getBool(_prefKeyIsTracking) ?? false;
      final startMs = prefs.getInt(_prefKeyStartTime);
      if (_isTracking && startMs != null) {
        _startTime = DateTime.fromMillisecondsSinceEpoch(startMs);
        _title = prefs.getString(_prefKeyTitle) ?? 'Transport / Commute';
      } else {
        _isTracking = false;
        _startTime = null;
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing TransportTrackingService: $e');
    }
  }

  /// Start transport live tracking and persist the start timestamp.
  Future<void> startTracking({String title = 'Transport / Commute'}) async {
    _isTracking = true;
    _startTime = DateTime.now();
    _title = title;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyIsTracking, true);
      await prefs.setInt(_prefKeyStartTime, _startTime!.millisecondsSinceEpoch);
      await prefs.setString(_prefKeyTitle, _title);
    } catch (e) {
      debugPrint('Error saving transport tracking start: $e');
    }

    notifyListeners();
  }

  /// Stop transport tracking, calculate total duration, save TimeBlock into SQLite,
  /// and clear persistent tracking state.
  Future<TimeBlock?> stopAndSaveTracking({DateTime? customDate}) async {
    if (!_isTracking || _startTime == null) {
      await cancelTracking();
      return null;
    }

    final startDt = _startTime!;
    final endDt = DateTime.now();
    final elapsedSec = currentElapsedSeconds;
    int durationMin = (elapsedSec / 60).round();
    if (durationMin < 1) durationMin = 1;

    // Use the actual date the transport began, or customDate if provided
    final dateStr = customDate != null
        ? DateFormat('yyyy-MM-dd').format(customDate)
        : DateFormat('yyyy-MM-dd').format(startDt);

    final m = elapsedSec ~/ 60;
    final s = elapsedSec % 60;
    final formattedStopwatch = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    final block = TimeBlock(
      title: _title.isNotEmpty ? _title : 'Transport / Commute',
      category: 'Transport',
      date: dateStr,
      startTime: DateFormat('hh:mm a').format(startDt),
      endTime: DateFormat('hh:mm a').format(endDt),
      durationMinutes: durationMin,
      isCompleted: true,
      notes: 'Recorded via live Transport Timer ($formattedStopwatch)',
    );

    // Persist to SQLite database safely without modifying or clearing existing data
    await DatabaseHelper.instance.insertTimeBlock(block);

    // Clear saved tracking state
    await cancelTracking();

    return block;
  }

  /// Discard current tracking and clear persistent state without saving.
  Future<void> cancelTracking() async {
    _isTracking = false;
    _startTime = null;
    _title = 'Transport / Commute';

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyIsTracking);
      await prefs.remove(_prefKeyStartTime);
      await prefs.remove(_prefKeyTitle);
    } catch (e) {
      debugPrint('Error clearing transport tracking state: $e');
    }

    notifyListeners();
  }
}
