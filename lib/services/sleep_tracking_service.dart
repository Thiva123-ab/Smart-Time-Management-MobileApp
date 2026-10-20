import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local/database_helper.dart';
import '../data/models/time_block.dart';

class SleepTrackingService extends ChangeNotifier {
  static final SleepTrackingService instance = SleepTrackingService._internal();

  SleepTrackingService._internal();

  static const String _prefKeyIsTracking = 'sleep_is_tracking';
  static const String _prefKeyStartTime = 'sleep_start_time_ms';
  static const String _prefKeyTitle = 'sleep_tracking_title';
  static const String _prefKeyNotes = 'sleep_tracking_notes';

  bool _isTracking = false;
  DateTime? _startTime;
  String _title = 'Night Sleep';
  String? _notes;
  bool _isInitialized = false;
  Timer? _ticker;

  bool get isTracking => _isTracking;
  DateTime? get startTime => _startTime;
  String get title => _title;
  String? get notes => _notes;
  bool get isInitialized => _isInitialized;

  /// Returns true elapsed seconds calculated against real DateTime.now().
  /// Ensures that even if phone is locked, screen off, or app closed overnight,
  /// the sleep duration is 100% accurate.
  int get currentElapsedSeconds {
    if (!_isTracking || _startTime == null) return 0;
    final diff = DateTime.now().difference(_startTime!).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Formatted elapsed time string, e.g. "7h 45m" or "45m 12s"
  String get formattedElapsed {
    final totalSeconds = currentElapsedSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
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

  /// Initialize state from SharedPreferences on app launch
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      _isTracking = prefs.getBool(_prefKeyIsTracking) ?? false;
      final startMs = prefs.getInt(_prefKeyStartTime);
      if (_isTracking && startMs != null) {
        _startTime = DateTime.fromMillisecondsSinceEpoch(startMs);
        _title = prefs.getString(_prefKeyTitle) ?? 'Night Sleep';
        _notes = prefs.getString(_prefKeyNotes);
        _startInternalTicker();
      } else {
        _isTracking = false;
        _startTime = null;
        _notes = null;
        _stopInternalTicker();
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing SleepTrackingService: $e');
    }
  }

  /// Start live sleep tracking (when going to bed)
  Future<void> startSleep({String title = 'Night Sleep', String? notes}) async {
    _isTracking = true;
    _startTime = DateTime.now();
    _title = title.trim().isEmpty ? 'Night Sleep' : title.trim();
    _notes = notes;
    _startInternalTicker();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyIsTracking, true);
      await prefs.setInt(_prefKeyStartTime, _startTime!.millisecondsSinceEpoch);
      await prefs.setString(_prefKeyTitle, _title);
      if (_notes != null) {
        await prefs.setString(_prefKeyNotes, _notes!);
      } else {
        await prefs.remove(_prefKeyNotes);
      }
    } catch (e) {
      debugPrint('Error saving sleep tracking start: $e');
    }

    notifyListeners();
  }

  /// Stop sleep tracking (when waking up), calculate duration accurately,
  /// and save TimeBlock into database.
  Future<TimeBlock?> wakeUpAndSave({DateTime? customDate, String? qualityNote}) async {
    if (!_isTracking || _startTime == null) {
      await cancelSleep();
      return null;
    }

    final startDt = _startTime!;
    final endDt = DateTime.now();
    final elapsedSec = currentElapsedSeconds;
    int durationMin = (elapsedSec / 60).round();
    if (durationMin < 1) durationMin = 1;

    // Use current wake-up date for today's schedule
    final dateStr = customDate != null
        ? DateFormat('yyyy-MM-dd').format(customDate)
        : DateFormat('yyyy-MM-dd').format(endDt);

    final hours = elapsedSec ~/ 3600;
    final mins = (elapsedSec % 3600) ~/ 60;
    final durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    final fullNotes = [
      'Recorded via live Sleep Tracker ($durationStr)',
      if (qualityNote != null && qualityNote.isNotEmpty) 'Quality: $qualityNote',
      if (_notes != null && _notes!.isNotEmpty) _notes,
    ].join(' • ');

    final block = TimeBlock(
      title: _title,
      category: 'Sleep',
      date: dateStr,
      startTime: DateFormat('hh:mm a').format(startDt),
      endTime: DateFormat('hh:mm a').format(endDt),
      durationMinutes: durationMin,
      isCompleted: true,
      notes: fullNotes,
    );

    try {
      await DatabaseHelper.instance.insertTimeBlock(block);
    } catch (e) {
      debugPrint('Error inserting sleep time block: $e');
    }

    await cancelSleep();
    return block;
  }

  /// Cancel sleep tracking without saving
  Future<void> cancelSleep() async {
    _isTracking = false;
    _startTime = null;
    _notes = null;
    _stopInternalTicker();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyIsTracking);
      await prefs.remove(_prefKeyStartTime);
      await prefs.remove(_prefKeyTitle);
      await prefs.remove(_prefKeyNotes);
    } catch (e) {
      debugPrint('Error clearing sleep tracking preferences: $e');
    }

    notifyListeners();
  }

  /// Manually log past sleep (bedtime & wake-up time), accurately calculating duration
  /// even across midnight.
  Future<TimeBlock?> logManualSleep({
    required DateTime sleepStart,
    required DateTime wakeUp,
    String title = 'Night Sleep',
    String? qualityNote,
  }) async {
    // If wakeUp is before sleepStart, wakeUp occurred the next morning
    DateTime effectiveEnd = wakeUp;
    if (effectiveEnd.isBefore(sleepStart)) {
      effectiveEnd = effectiveEnd.add(const Duration(days: 1));
    }

    final durationMin = effectiveEnd.difference(sleepStart).inMinutes;
    if (durationMin <= 0) return null;

    final dateStr = DateFormat('yyyy-MM-dd').format(effectiveEnd);
    final hours = durationMin ~/ 60;
    final mins = durationMin % 60;
    final durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    final notes = [
      'Manually logged sleep ($durationStr)',
      if (qualityNote != null && qualityNote.isNotEmpty) 'Quality: $qualityNote',
    ].join(' • ');

    final block = TimeBlock(
      title: title.trim().isEmpty ? 'Night Sleep' : title.trim(),
      category: 'Sleep',
      date: dateStr,
      startTime: DateFormat('hh:mm a').format(sleepStart),
      endTime: DateFormat('hh:mm a').format(effectiveEnd),
      durationMinutes: durationMin,
      isCompleted: true,
      notes: notes,
    );

    try {
      await DatabaseHelper.instance.insertTimeBlock(block);
    } catch (e) {
      debugPrint('Error inserting manual sleep block: $e');
    }

    notifyListeners();
    return block;
  }
}
