import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'usage_tracking_service.dart';

class BedtimeRoutineService extends ChangeNotifier {
  static final BedtimeRoutineService instance = BedtimeRoutineService._internal();

  BedtimeRoutineService._internal();

  static const String _keyEnabled = 'bedtime_enabled';
  static const String _keyBedHour = 'bedtime_target_hour';
  static const String _keyBedMinute = 'bedtime_target_minute';
  static const String _keyWakeHour = 'wakeup_target_hour';
  static const String _keyWakeMinute = 'wakeup_target_minute';
  static const String _keyLeadMinutes = 'bedtime_lead_minutes';
  static const String _keyAlarms = 'bedtime_auto_alarms';

  bool _isEnabled = true;
  int _bedHour = 22;
  int _bedMinute = 30;
  int _wakeHour = 6;
  int _wakeMinute = 30;
  int _leadMinutes = 45; // 45 minutes wind-down window
  bool _autoAlarms = true;
  bool _isInitialized = false;

  bool get isEnabled => _isEnabled;
  int get bedHour => _bedHour;
  int get bedMinute => _bedMinute;
  int get wakeHour => _wakeHour;
  int get wakeMinute => _wakeMinute;
  int get leadMinutes => _leadMinutes;
  bool get autoAlarms => _autoAlarms;
  bool get isInitialized => _isInitialized;

  String get formattedBedtime {
    final dt = DateTime(2026, 1, 1, _bedHour, _bedMinute);
    return DateFormat('hh:mm a').format(dt);
  }

  String get formattedWakeup {
    final dt = DateTime(2026, 1, 1, _wakeHour, _wakeMinute);
    return DateFormat('hh:mm a').format(dt);
  }

  double get targetSleepDurationHours {
    int startMins = _bedHour * 60 + _bedMinute;
    int endMins = _wakeHour * 60 + _wakeMinute;
    if (endMins <= startMins) {
      endMins += 24 * 60;
    }
    return (endMins - startMins) / 60.0;
  }

  /// Calculates remaining minutes until target bedtime tonight.
  int get minutesUntilBedtime {
    final now = DateTime.now();
    var bedDateTime = DateTime(now.year, now.month, now.day, _bedHour, _bedMinute);
    if (now.isAfter(bedDateTime)) {
      // If past bedtime but before 4 AM, consider it 0 or already bed time
      if (now.hour < 4) return 0;
      bedDateTime = bedDateTime.add(const Duration(days: 1));
    }
    return bedDateTime.difference(now).inMinutes;
  }

  /// True if current time is within the wind-down period before sleep or during sleep.
  bool get isWindDownActive {
    if (!_isEnabled) return false;
    final mins = minutesUntilBedtime;
    final now = DateTime.now();
    final isLateNight = now.hour >= _bedHour || now.hour < _wakeHour;
    return isLateNight || (mins > 0 && mins <= _leadMinutes);
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_keyEnabled) ?? true;
      _bedHour = prefs.getInt(_keyBedHour) ?? 22;
      _bedMinute = prefs.getInt(_keyBedMinute) ?? 30;
      _wakeHour = prefs.getInt(_keyWakeHour) ?? 6;
      _wakeMinute = prefs.getInt(_keyWakeMinute) ?? 30;
      _leadMinutes = prefs.getInt(_keyLeadMinutes) ?? 45;
      _autoAlarms = prefs.getBool(_keyAlarms) ?? true;
      _isInitialized = true;
      notifyListeners();

      if (_isEnabled && _autoAlarms) {
        scheduleAlarms();
      }
    } catch (e) {
      debugPrint('Error initializing BedtimeRoutineService: $e');
    }
  }

  Future<void> updateSettings({
    bool? isEnabled,
    int? bedHour,
    int? bedMinute,
    int? wakeHour,
    int? wakeMinute,
    int? leadMinutes,
    bool? autoAlarms,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (isEnabled != null) {
      _isEnabled = isEnabled;
      await prefs.setBool(_keyEnabled, isEnabled);
    }
    if (bedHour != null) {
      _bedHour = bedHour;
      await prefs.setInt(_keyBedHour, bedHour);
    }
    if (bedMinute != null) {
      _bedMinute = bedMinute;
      await prefs.setInt(_keyBedMinute, bedMinute);
    }
    if (wakeHour != null) {
      _wakeHour = wakeHour;
      await prefs.setInt(_keyWakeHour, wakeHour);
    }
    if (wakeMinute != null) {
      _wakeMinute = wakeMinute;
      await prefs.setInt(_keyWakeMinute, wakeMinute);
    }
    if (leadMinutes != null) {
      _leadMinutes = leadMinutes;
      await prefs.setInt(_keyLeadMinutes, leadMinutes);
    }
    if (autoAlarms != null) {
      _autoAlarms = autoAlarms;
      await prefs.setBool(_keyAlarms, autoAlarms);
    }

    notifyListeners();

    if (_isEnabled && _autoAlarms) {
      scheduleAlarms();
    } else {
      cancelAlarms();
    }
  }

  void scheduleAlarms() {
    try {
      final now = DateTime.now();

      // 1. Wind-down alarm (e.g. 45 min before bed)
      var windDownTime = DateTime(now.year, now.month, now.day, _bedHour, _bedMinute)
          .subtract(Duration(minutes: _leadMinutes));
      if (windDownTime.isBefore(now)) {
        windDownTime = windDownTime.add(const Duration(days: 1));
      }

      UsageTrackingService.scheduleAlarm(
        id: 901,
        timeMillis: windDownTime.millisecondsSinceEpoch,
        title: '🌙 Wind-Down Routine Starting',
        body: 'Step away from bright screens, review today\'s wins, and prepare your sleep sanctuary.',
        subText: 'Sleep Routine',
      );

      // 2. Bedtime alarm
      var bedTime = DateTime(now.year, now.month, now.day, _bedHour, _bedMinute);
      if (bedTime.isBefore(now)) {
        bedTime = bedTime.add(const Duration(days: 1));
      }

      UsageTrackingService.scheduleAlarm(
        id: 902,
        timeMillis: bedTime.millisecondsSinceEpoch,
        title: '🛌 Bedtime Reached',
        body: 'Protect your restorative sleep. Start your sleep tracker in FocusFlow.',
        subText: 'Sleep Routine',
      );
    } catch (e) {
      debugPrint('Error scheduling bedtime alarms: $e');
    }
  }

  void cancelAlarms() {
    try {
      UsageTrackingService.cancelAlarm(901);
      UsageTrackingService.cancelAlarm(902);
    } catch (_) {}
  }
}
