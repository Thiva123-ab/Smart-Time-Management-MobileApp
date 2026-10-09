import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../data/models/focus_session.dart';
import '../domain/pomodoro_engine.dart';
import '../services/usage_tracking_service.dart';

class FocusScreen extends StatefulWidget {
  final String? initialTask;
  final int? initialDurationMinutes;

  const FocusScreen({
    super.key,
    this.initialTask,
    this.initialDurationMinutes,
  });

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Focus Session State
  final FocusSessionManager _focusManager = FocusSessionManager();
  late TextEditingController _taskController;
  int _selectedDurationMinutes = 25;
  Timer? _focusTimer;
  bool _isFocusActive = false;
  bool _isFocusPaused = false;
  int _focusElapsedSeconds = 0;
  int _focusDistractions = 0;

  // Pomodoro State
  final PomodoroEngine _pomodoro = PomodoroEngine();
  Timer? _pomodoroTimer;

  final List<int> _durationPresets = [15, 25, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _taskController = TextEditingController(
      text: widget.initialTask != null && widget.initialTask!.isNotEmpty
          ? widget.initialTask!
          : 'Deep Work',
    );
    if (widget.initialDurationMinutes != null && widget.initialDurationMinutes! > 0) {
      _selectedDurationMinutes = widget.initialDurationMinutes!;
    }
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _pomodoroTimer?.cancel();
    _tabController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  // Focus Session Handlers
  void _startFocusSession() {
    final task = _taskController.text.trim().isEmpty ? 'Deep Work' : _taskController.text.trim();
    _focusManager.start(task, _selectedDurationMinutes);
    setState(() {
      _isFocusActive = true;
      _isFocusPaused = false;
      _focusElapsedSeconds = 0;
      _focusDistractions = 0;
    });

    _focusTimer?.cancel();
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isFocusPaused) {
        setState(() {
          _focusElapsedSeconds++;
        });

        if (_focusElapsedSeconds >= _selectedDurationMinutes * 60) {
          _finishFocusSession(true);
        }
      }
    });
  }

  void _pauseFocusSession() {
    setState(() => _isFocusPaused = !_isFocusPaused);
  }

  void _logDistraction() {
    setState(() => _focusDistractions++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Distraction logged. Take a deep breath & refocus! 🧘'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.surfaceVariant(context),
      ),
    );
  }

  Future<void> _finishFocusSession(bool completed) async {
    _focusTimer?.cancel();
    final duration = (_focusElapsedSeconds ~/ 60).clamp(1, 999);
    final now = DateTime.now().millisecondsSinceEpoch;

    final session = FocusSession(
      taskName: _taskController.text.trim().isEmpty ? 'Deep Work' : _taskController.text.trim(),
      startTime: now - (_focusElapsedSeconds * 1000),
      endTime: now,
      durationMinutes: duration,
      completed: completed,
      distractionCount: _focusDistractions,
      date: UsageTrackingService.todayDate,
    );

    await DatabaseHelper.instance.insertFocusSession(session);

    setState(() {
      _isFocusActive = false;
      _isFocusPaused = false;
      _focusElapsedSeconds = 0;
    });

    if (mounted) {
      _showCompletionDialog(session);
    }
  }

  void _showCompletionDialog(FocusSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(session.completed ? Icons.emoji_events : Icons.check_circle_outline, color: AppColors.accentCyan),
            const SizedBox(width: 10),
            Text(
              session.completed ? 'Session Complete! 🎉' : 'Session Saved',
              style: TextStyle(color: AppColors.textPrimaryColor(context)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Task: ${session.taskName}', style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Duration: ${session.durationMinutes} minutes', style: TextStyle(color: AppColors.textSecondaryColor(context))),
            Text('Distractions Logged: ${session.distractionCount}', style: TextStyle(color: AppColors.textSecondaryColor(context))),
            const SizedBox(height: 12),
            Text(
              'Great discipline! Your focus time has been added to your daily productivity score.',
              style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Awesome', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Pomodoro Handlers
  void _startPomodoro() {
    _pomodoro.start();
    setState(() {});
    _pomodoroTimer?.cancel();
    _pomodoroTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final phaseChanged = _pomodoro.tick();
      setState(() {});
      if (phaseChanged) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_pomodoro.currentPhase == PomodoroPhase.focus
                ? 'Break over! Focus session started.'
                : 'Focus completed! Take a well-deserved break.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    });
  }

  void _pausePomodoro() {
    _pomodoro.pause();
    setState(() {});
  }

  void _resetPomodoro() {
    _pomodoro.reset();
    _pomodoroTimer?.cancel();
    setState(() {});
  }

  String _formatSeconds(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Focus & Flow',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context)),
                      ),
                      const SizedBox(height: 4),
                      Text('Enter deep concentration mode', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder(context)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, color: isDark ? AppColors.accentCyan : AppColors.primary, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'DND Mode',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.accentCyan : AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: isDark ? AppColors.accentCyan : AppColors.primary,
              labelColor: isDark ? AppColors.accentCyan : AppColors.primary,
              unselectedLabelColor: AppColors.textSecondaryColor(context),
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Deep Focus Session'),
                Tab(text: 'Pomodoro Timer'),
              ],
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Deep Focus
                  _buildDeepFocusTab(),

                  // Tab 2: Pomodoro
                  _buildPomodoroTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeepFocusTab() {
    final totalSeconds = _selectedDurationMinutes * 60;
    final remainingSeconds = (totalSeconds - _focusElapsedSeconds).clamp(0, totalSeconds);
    final progress = totalSeconds > 0 ? (_focusElapsedSeconds / totalSeconds).clamp(0.0, 1.0) : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Task input
          if (!_isFocusActive) ...[
            TextField(
              controller: _taskController,
              style: TextStyle(color: AppColors.textPrimaryColor(context)),
              decoration: InputDecoration(
                labelText: 'Focus Task Name',
                hintText: 'e.g. Study Mathematics, Write Article',
                prefixIcon: Icon(Icons.edit_note, color: isDark ? AppColors.accentCyan : AppColors.primary),
                filled: true,
                fillColor: AppColors.surface(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.cardBorder(context))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.cardBorder(context))),
              ),
            ),
            const SizedBox(height: 16),

            // Presets
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Select Session Length', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _durationPresets.map((m) {
                final isSelected = m == _selectedDurationMinutes;
                return ChoiceChip(
                  label: Text('${m}m'),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface(context),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondaryColor(context),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(color: isSelected ? AppColors.primary : AppColors.cardBorder(context)),
                  onSelected: (val) {
                    if (val) setState(() => _selectedDurationMinutes = m);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          if (_isFocusActive) ...[
            Text(_taskController.text.trim(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context))),
            const SizedBox(height: 6),
            Text(
              _isFocusPaused ? 'Session Paused' : 'In Deep Work',
              style: TextStyle(color: _isFocusPaused ? AppColors.warning : (isDark ? AppColors.accentCyan : AppColors.primary), fontSize: 13),
            ),
            const SizedBox(height: 16),
          ],

          // Timer Dial
          Center(
            child: SizedBox(
              width: 230,
              height: 230,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 230,
                    height: 230,
                    child: CircularProgressIndicator(
                      value: _isFocusActive ? progress : 0.0,
                      strokeWidth: 12,
                      backgroundColor: AppColors.surfaceVariant(context),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isFocusActive ? _formatSeconds(remainingSeconds) : '${_selectedDurationMinutes}:00',
                        style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context), letterSpacing: 2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isFocusActive ? '${_formatSeconds(_focusElapsedSeconds)} elapsed' : 'Target Duration',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondaryColor(context)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Actions
          if (!_isFocusActive)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _startFocusSession,
              icon: const Icon(Icons.play_arrow, size: 28, color: Colors.white),
              label: const Text(
                'Start Deep Focus',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.warning),
                      foregroundColor: AppColors.warning,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _pauseFocusSession,
                    icon: Icon(_isFocusPaused ? Icons.play_arrow : Icons.pause),
                    label: Text(_isFocusPaused ? 'Resume' : 'Pause'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _finishFocusSession(false),
                    icon: const Icon(Icons.check),
                    label: const Text('Complete'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Distraction Logger
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.cardBorder(context)),
                foregroundColor: AppColors.textSecondaryColor(context),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _logDistraction,
              icon: const Icon(Icons.psychology_outlined, size: 20),
              label: Text('Log Distraction / Urge ($_focusDistractions)'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPomodoroTab() {
    final phaseColor = _pomodoro.currentPhase == PomodoroPhase.focus
        ? AppColors.primary
        : (_pomodoro.currentPhase == PomodoroPhase.shortBreak ? AppColors.accentCyan : AppColors.success);

    final phaseName = _pomodoro.currentPhase == PomodoroPhase.focus
        ? 'Focus Time'
        : (_pomodoro.currentPhase == PomodoroPhase.shortBreak ? 'Short Break' : 'Long Break');

    final totalSecs = (_pomodoro.currentPhase == PomodoroPhase.focus
            ? _pomodoro.focusMinutes
            : (_pomodoro.currentPhase == PomodoroPhase.shortBreak ? _pomodoro.breakMinutes : _pomodoro.longBreakMinutes)) *
        60;
    final progress = totalSecs > 0 ? (1.0 - (_pomodoro.remainingSeconds / totalSecs)).clamp(0.0, 1.0) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Phase Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: phaseColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: phaseColor),
            ),
            child: Text(phaseName, style: TextStyle(color: phaseColor, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(height: 24),

          // Dial
          Center(
            child: SizedBox(
              width: 230,
              height: 230,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 230,
                    height: 230,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: AppColors.surfaceVariant(context),
                      valueColor: AlwaysStoppedAnimation<Color>(phaseColor),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatSeconds(_pomodoro.remainingSeconds),
                        style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context), letterSpacing: 2),
                      ),
                      const SizedBox(height: 4),
                      Text('Cycle: ${_pomodoro.completedCycles + 1}', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryColor(context))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface(context),
                  padding: const EdgeInsets.all(16),
                ),
                icon: Icon(Icons.refresh, color: AppColors.textSecondaryColor(context)),
                onPressed: _resetPomodoro,
              ),
              const SizedBox(width: 20),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: phaseColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(20),
                ),
                icon: Icon(_pomodoro.isRunning ? Icons.pause : Icons.play_arrow, size: 32),
                onPressed: () {
                  if (_pomodoro.isRunning) {
                    _pausePomodoro();
                  } else {
                    _startPomodoro();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Preset options
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Presets', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.cardBorder(context)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _pomodoro.applyPreset(25, 5, 15)),
                  child: Text('Classic (25/5)', style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.cardBorder(context)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _pomodoro.applyPreset(50, 10, 20)),
                  child: Text('Extended (50/10)', style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
