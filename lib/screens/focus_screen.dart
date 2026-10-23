import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../data/models/focus_session.dart';
import '../domain/pomodoro_engine.dart';
import '../services/usage_tracking_service.dart';
import '../services/urgent_task_tracking_service.dart';
import '../services/focus_audio_service.dart';
import '../widgets/ambient_sound_player_sheet.dart';

class FocusScreen extends StatefulWidget {
  final String? initialTask;
  final int? initialDurationMinutes;
  final int? initialElapsedSeconds;
  final int? goalId;
  final bool autoStartFocus;

  const FocusScreen({
    super.key,
    this.initialTask,
    this.initialDurationMinutes,
    this.initialElapsedSeconds,
    this.goalId,
    this.autoStartFocus = false,
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
    if (widget.initialElapsedSeconds != null && widget.initialElapsedSeconds! > 0) {
      _focusElapsedSeconds = widget.initialElapsedSeconds!;
    }
    if (widget.autoStartFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startFocusSession(resume: _focusElapsedSeconds > 0);
        }
      });
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

  Future<void> _saveGoalProgress({bool markCompleted = false}) async {
    if (widget.goalId != null && _focusElapsedSeconds > 0) {
      final completedMinutes = (_focusElapsedSeconds ~/ 60);
      final isDone = markCompleted || (completedMinutes >= _selectedDurationMinutes && _selectedDurationMinutes > 0);
      await DatabaseHelper.instance.updateGoalProgress(
        widget.goalId!,
        completedMinutes,
        markCompleted: isDone,
      );
    }
  }

  // Focus Session Handlers
  void _startFocusSession({bool resume = false}) {
    final task = _taskController.text.trim().isEmpty ? 'Deep Work' : _taskController.text.trim();
    final startSeconds = (resume || _focusElapsedSeconds > 0) ? _focusElapsedSeconds : 0;
    _focusManager.start(task, _selectedDurationMinutes, initialElapsedSeconds: startSeconds);
    setState(() {
      _isFocusActive = true;
      _isFocusPaused = false;
      _focusElapsedSeconds = startSeconds;
      _focusDistractions = 0;
    });

    _focusTimer?.cancel();
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isFocusPaused) {
        setState(() {
          _focusElapsedSeconds++;
        });

        if (_focusElapsedSeconds % 30 == 0) {
          _saveGoalProgress();
        }

        if (_focusElapsedSeconds >= _selectedDurationMinutes * 60) {
          _finishFocusSession(true);
        }
      }
    });
  }

  Future<void> _pauseFocusSession() async {
    setState(() => _isFocusPaused = !_isFocusPaused);
    if (_isFocusPaused) {
      await _saveGoalProgress();
      if (mounted) {
        final completedMins = _focusElapsedSeconds ~/ 60;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Session paused & progress saved ($completedMins mins completed) 💾'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.surfaceVariant(context),
          ),
        );
      }
    }
  }

  Future<void> _resetFocusSession() async {
    _focusTimer?.cancel();
    FocusAudioService.instance.stop();
    setState(() {
      _isFocusActive = false;
      _isFocusPaused = false;
      _focusElapsedSeconds = 0;
      _focusDistractions = 0;
    });
    if (widget.goalId != null) {
      await DatabaseHelper.instance.updateGoalProgress(widget.goalId!, 0, markCompleted: false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Timer reset to 0:00 ⏱️'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.surfaceVariant(context),
        ),
      );
    }
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
    FocusAudioService.instance.stop();
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
    await _saveGoalProgress(markCompleted: completed);

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

  void _startUrgentInterruption() async {
    // Automatically pause active focus session so progress is safely preserved
    if (_isFocusActive && !_isFocusPaused) {
      await _pauseFocusSession();
    }
    if (_pomodoro.isRunning) {
      _pausePomodoro();
    }

    final currentTaskName = _taskController.text.trim().isNotEmpty
        ? _taskController.text.trim()
        : 'Deep Work';

    final textCtrl = TextEditingController(text: 'Urgent Errand');

    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final presets = ['Urgent Call', 'Emergency Errand', 'Family Matter', 'Quick Review', 'Urgent Fix'];
        return Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Urgent Task Timer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                        Text(
                          'Interrupted while working on: "$currentTaskName"',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryColor(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Urgent Task / Errand Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.edit, color: Colors.amber),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((p) => ActionChip(
                  label: Text(p, style: const TextStyle(fontSize: 12)),
                  avatar: const Icon(Icons.flash_on, size: 14, color: Colors.amber),
                  onPressed: () => textCtrl.text = p,
                )).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Urgent Stopwatch Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.pop(ctx, textCtrl.text.trim()),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && selected.isNotEmpty) {
      await UrgentTaskTrackingService.instance.startTracking(
        title: selected,
        parentTaskName: currentTaskName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Urgent timer running: "$selected". Original task is paused!'),
            backgroundColor: Colors.amber.shade800,
          ),
        );
      }
    }
  }

  Widget _buildUrgentTrackingBanner(bool isDark) {
    return Consumer<UrgentTaskTrackingService>(
      builder: (ctx, urgentService, _) {
        if (!urgentService.isTracking) return const SizedBox.shrink();
        final elapsedSec = urgentService.currentElapsedSeconds;
        final h = elapsedSec ~/ 3600;
        final m = (elapsedSec % 3600) ~/ 60;
        final s = elapsedSec % 60;
        final timeStr = h > 0
            ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
            : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(isDark ? 0.18 : 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade700, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            urgentService.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.amber[200] : Colors.amber[900],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                          child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    Text(
                      'Running: $timeStr • Original task paused',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondaryColor(context)),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () async {
                  final block = await urgentService.stopAndSaveTracking();
                  if (ctx.mounted && block != null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('✅ Urgent task completed: ${block.durationMinutes} mins logged!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                child: const Text('Stop & Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        );
      },
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _saveGoalProgress();
        if (mounted) {
          Navigator.pop(context, true);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (Navigator.canPop(context)) ...[
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            tooltip: 'Back',
                            onPressed: () async {
                              await _saveGoalProgress();
                              if (mounted) Navigator.pop(context, true);
                            },
                          ),
                          const SizedBox(width: 4),
                        ],
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Focus & Flow',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context)),
                            ),
                            const SizedBox(height: 2),
                            Text('Enter deep concentration mode', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Consumer<FocusAudioService>(
                          builder: (context, audio, _) {
                            final isPlaying = audio.isPlaying;
                            return InkWell(
                              onTap: () => AmbientSoundPlayerSheet.show(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isPlaying
                                      ? (isDark ? AppColors.accentCyan.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.12))
                                      : AppColors.surface(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isPlaying
                                        ? (isDark ? AppColors.accentCyan : AppColors.primary)
                                        : AppColors.cardBorder(context),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isPlaying ? Icons.graphic_eq_rounded : Icons.headphones_rounded,
                                      color: isPlaying
                                          ? (isDark ? AppColors.accentCyan : AppColors.primary)
                                          : AppColors.textSecondaryColor(context),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isPlaying ? (audio.activeTrack?.name ?? 'Playing') : 'Sound',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isPlaying
                                            ? (isDark ? AppColors.accentCyan : AppColors.primary)
                                            : AppColors.textPrimaryColor(context),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
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
                  ],
                ),
              ),

              // Live Urgent Tracking Banner
              _buildUrgentTrackingBanner(isDark),

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
          if (!_isFocusActive) ...[
            if (_focusElapsedSeconds > 0)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _startFocusSession(resume: true),
                      icon: const Icon(Icons.play_arrow, size: 26, color: Colors.white),
                      label: const Text(
                        'Resume Deep Focus',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _resetFocusSession,
                      child: const Tooltip(
                        message: 'Reset Timer',
                        child: Icon(Icons.restart_alt, size: 24),
                      ),
                    ),
                  ),
                ],
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => _startFocusSession(resume: false),
                icon: const Icon(Icons.play_arrow, size: 28, color: Colors.white),
                label: const Text(
                  'Start Deep Focus',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
          ] else ...[
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
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.cardBorder(context)),
                      foregroundColor: AppColors.textSecondaryColor(context),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _logDistraction,
                    icon: const Icon(Icons.psychology_outlined, size: 20),
                    label: Text('Distraction ($_focusDistractions)'),
                  ),
                ),
                if (_isFocusPaused) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      foregroundColor: Colors.redAccent,
                      minimumSize: const Size(100, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _resetFocusSession,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Reset'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _startUrgentInterruption,
                icon: const Icon(Icons.flash_on_rounded, size: 20),
                label: const Text('Urgent Work Came Up? Start Urgent Timer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
          _buildAmbientAudioCard(),
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
          _buildAmbientAudioCard(),
        ],
      ),
    );
  }

  Widget _buildAmbientAudioCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<FocusAudioService>(
      builder: (context, audio, _) {
        final isPlaying = audio.isPlaying;
        final active = audio.activeTrack;
        return Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131826) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPlaying
                  ? (isDark ? AppColors.accentCyan : AppColors.primary)
                  : AppColors.cardBorder(context),
              width: isPlaying ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: (isPlaying
                          ? (isDark ? AppColors.accentCyan : AppColors.primary)
                          : AppColors.textSecondaryColor(context))
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.graphic_eq_rounded : Icons.headphones_outlined,
                  color: isPlaying
                      ? (isDark ? AppColors.accentCyan : AppColors.primary)
                      : AppColors.textSecondaryColor(context),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPlaying && active != null ? active.name : 'Focus Soundscape',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    Text(
                      isPlaying ? 'Binaural / Ambient Audio Active' : '40Hz Gamma, Alpha & Nature Audio',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (isPlaying)
                IconButton(
                  icon: const Icon(Icons.pause_circle_filled_rounded),
                  color: isDark ? AppColors.accentCyan : AppColors.primary,
                  iconSize: 28,
                  tooltip: 'Pause Ambient Sound',
                  onPressed: () => audio.stop(),
                ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: AppColors.surfaceVariant(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.tune_rounded, size: 15),
                label: Text(
                  isPlaying ? 'Adjust' : 'Choose',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => AmbientSoundPlayerSheet.show(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
