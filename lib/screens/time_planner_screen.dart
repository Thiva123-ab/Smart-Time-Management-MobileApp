import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../data/models/time_block.dart';
import '../data/models/time_sub_task.dart';
import '../data/models/daily_note.dart';
import '../data/models/focus_session.dart';
import '../services/usage_tracking_service.dart';
import '../services/schedule_notification_service.dart';
import '../services/transport_tracking_service.dart';
import 'focus_screen.dart';

class TimePlannerScreen extends StatefulWidget {
  const TimePlannerScreen({super.key});

  @override
  State<TimePlannerScreen> createState() => _TimePlannerScreenState();
}

class _TimePlannerScreenState extends State<TimePlannerScreen> {
  DateTime _selectedDate = DateTime.now();
  List<TimeBlock> _blocks = [];
  Map<int, List<TimeSubTask>> _subTasks = {};
  List<DailyNote> _dailyNotes = [];
  List<FocusSession> _focusSessions = [];
  bool _isLoading = true;
  bool _hasNotificationPermission = true;

  // Transport live tracker service & state
  final TransportTrackingService _transportService = TransportTrackingService.instance;
  bool _isTrackingTransport = false;
  DateTime? _transportStartTime;
  int _transportElapsedSeconds = 0;
  Timer? _transportTimer;
  late ScrollController _dateScrollController;

  final List<String> _categories = [
    'Study',
    'Work',
    'Coding',
    'Reading',
    'Fitness',
    'Transport',
    'Personal',
    'Meeting',
    'Break',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _dateScrollController = ScrollController();
    _checkNotificationPermission();
    _syncTransportFromService();
    _transportService.addListener(_onTransportServiceChanged);
    _loadBlocks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
    });
  }

  void _scrollToSelectedDate() {
    if (!_dateScrollController.hasClients) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(const Duration(days: 15));
    final targetDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final dayIndex = targetDate.difference(startDate).inDays;
    if (dayIndex >= 0 && dayIndex <= 30) {
      final screenWidth = MediaQuery.of(context).size.width;
      final targetOffset = (dayIndex * 66.0) - (screenWidth / 2) + 33.0;
      _dateScrollController.animateTo(
        targetOffset.clamp(0.0, _dateScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _syncTransportFromService() {
    final isTracking = _transportService.isTracking;
    final startTime = _transportService.startTime;
    final elapsed = _transportService.currentElapsedSeconds;

    if (mounted) {
      setState(() {
        _isTrackingTransport = isTracking;
        _transportStartTime = startTime;
        _transportElapsedSeconds = elapsed;
      });
    }

    if (isTracking) {
      _startUiTimer();
    } else {
      _transportTimer?.cancel();
      _transportTimer = null;
    }
  }

  void _onTransportServiceChanged() {
    if (mounted) {
      _syncTransportFromService();
    }
  }

  void _startUiTimer() {
    _transportTimer?.cancel();
    _transportTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_transportService.isTracking) {
          setState(() {
            _transportElapsedSeconds = _transportService.currentElapsedSeconds;
            _transportStartTime = _transportService.startTime;
            _isTrackingTransport = true;
          });
        } else {
          _transportTimer?.cancel();
          setState(() {
            _isTrackingTransport = false;
            _transportElapsedSeconds = 0;
            _transportStartTime = null;
          });
        }
      }
    });
  }

  Future<void> _checkNotificationPermission() async {
    final hasPerm = await UsageTrackingService.hasNotificationPermission();
    if (mounted) {
      setState(() => _hasNotificationPermission = hasPerm);
    }
  }

  @override
  void dispose() {
    _transportTimer?.cancel();
    _transportService.removeListener(_onTransportServiceChanged);
    _dateScrollController.dispose();
    super.dispose();
  }

  String _dateString(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  Future<void> _loadBlocks() async {
    setState(() => _isLoading = true);
    final dateStr = _dateString(_selectedDate);
    final blocks = await DatabaseHelper.instance.getTimeBlocksForDate(dateStr);
    final sessions = await DatabaseHelper.instance.getFocusSessionsForDate(dateStr);
    final subTasks = await DatabaseHelper.instance.getSubTasksForDate(dateStr);
    final notes = await DatabaseHelper.instance.getDailyNotesForDate(dateStr);

    // Smart priority sorting:
    // 1. Incomplete/Pending tasks FIRST (sorted by start time)
    // 2. Completed tasks LAST (moved to bottom)
    blocks.sort((a, b) {
      if (!a.isCompleted && b.isCompleted) return -1;
      if (a.isCompleted && !b.isCompleted) return 1;

      // Both incomplete or both completed -> sort by start time
      final aTod = _parseTimeOfDay(a.startTime);
      final bTod = _parseTimeOfDay(b.startTime);
      final aMin = aTod.hour * 60 + aTod.minute;
      final bMin = bTod.hour * 60 + bTod.minute;
      return aMin.compareTo(bMin);
    });

    if (mounted) {
      setState(() {
        _blocks = blocks;
        _subTasks = subTasks;
        _dailyNotes = notes;
        _focusSessions = sessions;
        _isLoading = false;
      });
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'study':
        return const Color(0xFF6C5CE7);
      case 'work':
        return const Color(0xFF0984E3);
      case 'coding':
        return const Color(0xFF00CEC9);
      case 'reading':
        return const Color(0xFFE17055);
      case 'fitness':
        return const Color(0xFF00B894);
      case 'transport':
        return const Color(0xFF00B4D8);
      case 'personal':
        return const Color(0xFFFD79A8);
      case 'meeting':
        return const Color(0xFFFFA502);
      case 'break':
        return const Color(0xFFA29BFE);
      default:
        return AppColors.primary;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'study':
        return Icons.school_outlined;
      case 'work':
        return Icons.work_outline;
      case 'coding':
        return Icons.code_rounded;
      case 'reading':
        return Icons.menu_book_outlined;
      case 'fitness':
        return Icons.fitness_center_outlined;
      case 'transport':
        return Icons.directions_bus_rounded;
      case 'personal':
        return Icons.person_outline;
      case 'meeting':
        return Icons.groups_outlined;
      case 'break':
        return Icons.coffee_outlined;
      default:
        return Icons.task_alt_outlined;
    }
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  void _showAddOrEditDialog({TimeBlock? blockToEdit}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final isPast = targetDate.isBefore(today);

    final titleController = TextEditingController(text: blockToEdit?.title ?? '');
    final notesController = TextEditingController(text: blockToEdit?.notes ?? '');
    String selectedCategory = blockToEdit?.category ?? 'Study';

    final isToday = targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day;

    TimeOfDay defaultStart;
    TimeOfDay defaultEnd;
    if (blockToEdit != null) {
      defaultStart = _parseTimeOfDay(blockToEdit.startTime);
      defaultEnd = _parseTimeOfDay(blockToEdit.endTime);
    } else {
      // Find the next available non-conflicting time slot!
      int candidateStart = isToday
          ? (now.hour * 60 + ((now.minute / 5).ceil()) * 5)
          : (9 * 60);

      // Sort existing blocks by start time
      final sortedBlocks = List<TimeBlock>.from(_blocks);
      sortedBlocks.sort((a, b) => _timeToMinutes(a.startTime).compareTo(_timeToMinutes(b.startTime)));

      // If the candidate start time conflicts with any existing block, push it after that block's end!
      bool foundSlot = false;
      int candidateDuration = 60; // 1 hour default
      int searchLoops = 0;
      while (!foundSlot && candidateStart + 15 < 24 * 60 && searchLoops < 30) {
        searchLoops++;
        int candidateEnd = candidateStart + candidateDuration;
        TimeBlock? conflict;
        for (final b in sortedBlocks) {
          int bStart = _timeToMinutes(b.startTime);
          int bEnd = _timeToMinutes(b.endTime);
          if (bEnd <= bStart) bEnd += 24 * 60;
          if (candidateStart < bEnd && candidateEnd > bStart) {
            conflict = b;
            break;
          }
        }
        if (conflict == null) {
          foundSlot = true;
        } else {
          // Push candidateStart to this conflicting block's end time!
          int bEnd = _timeToMinutes(conflict.endTime);
          candidateStart = ((bEnd / 5).ceil()) * 5;
        }
      }

      if (candidateStart >= 24 * 60) {
        candidateStart = now.hour * 60 + now.minute;
      }
      int candidateEnd = candidateStart + candidateDuration;
      if (candidateEnd > 24 * 60) candidateEnd = 24 * 60;

      defaultStart = TimeOfDay(hour: (candidateStart ~/ 60) % 24, minute: candidateStart % 60);
      defaultEnd = TimeOfDay(hour: (candidateEnd ~/ 60) % 24, minute: candidateEnd % 60);
    }

    TimeOfDay startTime = defaultStart;
    TimeOfDay endTime = defaultEnd;

    int calculatedDuration = _calculateDuration(startTime, endTime);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        blockToEdit == null ? 'Schedule Time Block' : 'Edit Time Block',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                        color: AppColors.textMutedColor(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Task Title
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: AppColors.textPrimaryColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Task / Activity Name',
                      hintText: 'e.g. Flutter Study Session',
                      labelStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
                      hintStyle: TextStyle(color: AppColors.textMutedColor(context)),
                      prefixIcon: const Icon(Icons.edit_calendar, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Selector
                  Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSelected = selectedCategory == cat;
                      final catColor = _getCategoryColor(cat);
                      return ChoiceChip(
                        avatar: Icon(
                          _getCategoryIcon(cat),
                          size: 16,
                          color: isSelected ? Colors.white : catColor,
                        ),
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: catColor,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimaryColor(context),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: AppColors.surfaceVariant(context),
                        onSelected: (val) {
                          if (val) setSheetState(() => selectedCategory = cat);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Time Selection (Start Time -> End Time)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Time Slot',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                      if (isToday)
                        Text(
                          'Current: ${DateFormat('hh:mm a').format(DateTime.now())}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentCyan,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Start Time Card
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: startTime,
                            );
                            if (picked != null) {
                              final currentTime = DateTime.now();
                              final pickedMinutes = picked.hour * 60 + picked.minute;
                              final currentMinutes = currentTime.hour * 60 + currentTime.minute;

                              if (isToday && pickedMinutes < currentMinutes) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cannot select a past time for today. Start time must be from current time onwards.'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              setSheetState(() {
                                startTime = picked;
                                calculatedDuration = _calculateDuration(startTime, endTime);
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant(context),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorder(context)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Start Time', style: TextStyle(fontSize: 11, color: AppColors.textMutedColor(context))),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatTimeOfDay(startTime),
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimaryColor(context)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 18, color: Colors.grey),
                      ),
                      // End Time Card
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: endTime,
                            );
                            if (picked != null) {
                              final currentTime = DateTime.now();
                              final pickedMinutes = picked.hour * 60 + picked.minute;
                              final currentMinutes = currentTime.hour * 60 + currentTime.minute;

                              if (isToday && pickedMinutes <= currentMinutes) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('End time cannot be in the past.'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              setSheetState(() {
                                endTime = picked;
                                calculatedDuration = _calculateDuration(startTime, endTime);
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant(context),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorder(context)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('End Time', style: TextStyle(fontSize: 11, color: AppColors.textMutedColor(context))),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_filled, size: 16, color: AppColors.accentCyan),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatTimeOfDay(endTime),
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimaryColor(context)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timelapse, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Allocated Duration: ${_formatMinutes(calculatedDuration)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.accentTeal : AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Real-time live conflict warning inside the modal
                  Builder(
                    builder: (ctx) {
                      final curStart = startTime.hour * 60 + startTime.minute;
                      final curEnd = endTime.hour * 60 + endTime.minute;
                      final liveConflict = _findConflictingBlock(curStart, curEnd, excludeId: blockToEdit?.id);
                      if (liveConflict == null) return const SizedBox.shrink();

                      return Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Time Slot Conflict!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Overlaps with "${liveConflict.title}" (${liveConflict.startTime} - ${liveConflict.endTime}). You cannot allocate the same time slot.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.red[200] : Colors.red[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[700],
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.fast_forward, size: 14),
                                label: const Text(
                                  'Allocate Next Free Slot',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                onPressed: () {
                                  final conflictEnd = _timeToMinutes(liveConflict.endTime);
                                  final newStartMin = ((conflictEnd / 5).ceil()) * 5;
                                  int newEndMin = newStartMin + calculatedDuration;
                                  if (newEndMin > 24 * 60) newEndMin = 24 * 60;
                                  setSheetState(() {
                                    startTime = TimeOfDay(hour: (newStartMin ~/ 60) % 24, minute: newStartMin % 60);
                                    endTime = TimeOfDay(hour: (newEndMin ~/ 60) % 24, minute: newEndMin % 60);
                                    calculatedDuration = _calculateDuration(startTime, endTime);
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Already Booked Slots Chips
                  if (_blocks.where((b) => blockToEdit?.id == null || b.id != blockToEdit?.id).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Booked Slots Today:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMutedColor(context)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _blocks.where((b) => blockToEdit?.id == null || b.id != blockToEdit?.id).map((b) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            '🔒 ${b.startTime} - ${b.endTime}: ${b.title}',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondaryColor(context)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Notes TextField
                  TextField(
                    controller: notesController,
                    style: TextStyle(color: AppColors.textPrimaryColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Notes / Goal (Optional)',
                      hintText: 'e.g. Chapter 4 exercises & review notes',
                      labelStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
                      hintStyle: TextStyle(color: AppColors.textMutedColor(context)),
                      prefixIcon: const Icon(Icons.notes_outlined, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Save Button with real-time conflict handling
                  Builder(
                    builder: (ctx) {
                      final curStart = startTime.hour * 60 + startTime.minute;
                      final curEnd = endTime.hour * 60 + endTime.minute;
                      final hasConflict = _findConflictingBlock(curStart, curEnd, excludeId: blockToEdit?.id) != null;

                      return SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasConflict ? Colors.grey.shade700 : AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            final title = titleController.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a task name')),
                              );
                              return;
                            }

                            // Check past time validation on submit for today
                            final currentTime = DateTime.now();
                            final startMinutes = startTime.hour * 60 + startTime.minute;
                            final currentMinutes = currentTime.hour * 60 + currentTime.minute;
                            final endMinutes = endTime.hour * 60 + endTime.minute;

                            if (isToday && startMinutes < currentMinutes) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Start time cannot be in the past. Please select current time or later.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return;
                            }

                            if (endMinutes <= startMinutes) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('End time must be after start time.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return;
                            }

                            // Strictly check time slot conflict from memory and database
                            final conflict = _findConflictingBlock(startMinutes, endMinutes, excludeId: blockToEdit?.id);
                            if (conflict != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '⚠️ Time slot already occupied!\n"${conflict.title}" is already scheduled (${conflict.startTime} - ${conflict.endTime}). Please allocate another time slot.',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  backgroundColor: Colors.red.shade700,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                              return;
                            }

                        final block = TimeBlock(
                          id: blockToEdit?.id,
                          title: title,
                          category: selectedCategory,
                          date: _dateString(_selectedDate),
                          startTime: _formatTimeOfDay(startTime),
                          endTime: _formatTimeOfDay(endTime),
                          durationMinutes: calculatedDuration,
                          isCompleted: blockToEdit?.isCompleted ?? false,
                          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        );

                        if (blockToEdit == null) {
                          await DatabaseHelper.instance.insertTimeBlock(block);
                        } else {
                          await DatabaseHelper.instance.updateTimeBlock(block);
                        }

                        ScheduleNotificationService.instance.rescheduleNativeAlarms();

                        Navigator.pop(ctx);
                        _loadBlocks();
                      },
                      child: Text(
                        blockToEdit == null ? 'Add to Schedule' : 'Update Time Block',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  );
                },
              ),
            ],
              ),
            ),
          );
        },
      ),
    );
  }

  int _timeToMinutes(String timeStr) {
    try {
      final clean = timeStr.replaceAll(RegExp(r'\s+'), ' ').trim();
      final match = RegExp(r'^(\d{1,2}):(\d{2})(?:\s*([APap][Mm]))?').firstMatch(clean);
      if (match != null) {
        int h = int.parse(match.group(1)!);
        int m = int.parse(match.group(2)!);
        final period = match.group(3)?.toUpperCase();
        if (period == 'PM' && h < 12) h += 12;
        if (period == 'AM' && h == 12) h = 0;
        return h * 60 + m;
      }
    } catch (_) {}
    return 0;
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    final totalMin = _timeToMinutes(timeStr);
    return TimeOfDay(hour: (totalMin ~/ 60) % 24, minute: totalMin % 60);
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  int _calculateDuration(TimeOfDay start, TimeOfDay end) {
    int startMinutes = start.hour * 60 + start.minute;
    int endMinutes = end.hour * 60 + end.minute;
    if (endMinutes < startMinutes) {
      endMinutes += 24 * 60; // Next day wrap
    }
    final diff = endMinutes - startMinutes;
    return diff > 0 ? diff : 30;
  }

  TimeBlock? _findConflictingBlock(int startMin, int endMin, {int? excludeId}) {
    for (final b in _blocks) {
      if (excludeId != null && b.id == excludeId) continue;
      int bStart = _timeToMinutes(b.startTime);
      int bEnd = _timeToMinutes(b.endTime);
      if (bEnd <= bStart) bEnd += 24 * 60;

      int testStart = startMin;
      int testEnd = endMin;
      if (testEnd <= testStart) testEnd += 24 * 60;

      // Overlap: [testStart, testEnd) and [bStart, bEnd) overlap if testStart < bEnd && testEnd > bStart
      if (testStart < bEnd && testEnd > bStart) {
        return b;
      }
    }
    return null;
  }

  Future<void> _toggleBlockStatus(TimeBlock block) async {
    if (block.id == null) return;
    final willComplete = !block.isCompleted;
    if (willComplete) {
      await ScheduleNotificationService.instance.cancelAlarmsForBlock(block.id!);
    }
    await DatabaseHelper.instance.toggleTimeBlock(block.id!, willComplete);
    await ScheduleNotificationService.instance.rescheduleNativeAlarms();
    _loadBlocks();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willComplete
                ? '✅ "${block.title}" marked as COMPLETED!'
                : '↩️ "${block.title}" marked as PENDING.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: willComplete ? AppColors.success : Colors.blueGrey,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteBlock(int id) async {
    await ScheduleNotificationService.instance.cancelAlarmsForBlock(id);
    await DatabaseHelper.instance.deleteTimeBlock(id);
    await ScheduleNotificationService.instance.rescheduleNativeAlarms();
    _loadBlocks();
  }

  void _startFocusForBlock(TimeBlock block) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FocusScreen(
          initialTask: block.title,
          initialDurationMinutes: block.durationMinutes,
          autoStartFocus: true,
        ),
      ),
    );
  }

  Future<void> _toggleSubTask(TimeSubTask subTask) async {
    if (subTask.id == null) return;
    final willComplete = !subTask.isCompleted;
    await DatabaseHelper.instance.toggleTimeSubTask(subTask.id!, willComplete);
    _loadBlocks();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willComplete
                ? '✅ Urgent task "${subTask.title}" marked as COMPLETED!'
                : '↩️ Urgent task "${subTask.title}" marked as PENDING.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: willComplete ? AppColors.success : Colors.blueGrey,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteSubTask(TimeSubTask subTask) async {
    if (subTask.id == null) return;
    await DatabaseHelper.instance.deleteTimeSubTask(subTask.id!);
    _loadBlocks();
  }

  void _startFocusForSubTask(TimeSubTask subTask, TimeBlock parentBlock) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FocusScreen(
          initialTask: '[Urgent] ${subTask.title}',
          initialDurationMinutes: subTask.durationMinutes,
          autoStartFocus: true,
        ),
      ),
    );
  }

  void _showAllocateUrgentTimeDialog(TimeBlock parentBlock) {
    final titleController = TextEditingController();
    int selectedDuration = 15;
    bool focusImmediately = false;

    // Calculate time in parent block
    final existingSubtasks = _subTasks[parentBlock.id] ?? [];
    final alreadyAllocated = existingSubtasks.fold<int>(0, (sum, item) => sum + item.durationMinutes);
    final remainingParentMins = (parentBlock.durationMinutes - alreadyAllocated).clamp(0, 9999);

    final presetTasks = [
      {'title': 'Urgent Call', 'duration': 10, 'icon': Icons.phone_in_talk_rounded},
      {'title': 'Emergency Fix', 'duration': 20, 'icon': Icons.build_rounded},
      {'title': 'Urgent Email', 'duration': 15, 'icon': Icons.mail_rounded},
      {'title': 'Quick Break', 'duration': 10, 'icon': Icons.coffee_rounded},
      {'title': 'Urgent Errand', 'duration': 15, 'icon': Icons.directions_run_rounded},
      {'title': 'Quick Review', 'duration': 10, 'icon': Icons.rate_review_rounded},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
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
                          color: Colors.amber.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Allocate Urgent Time',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryColor(context),
                              ),
                            ),
                            Text(
                              'Inside: ${parentBlock.title} (${parentBlock.startTime} - ${parentBlock.endTime})',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryColor(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                        color: AppColors.textMutedColor(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Remaining time pill
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sudden work during this block. Total: ${parentBlock.durationMinutes}m | Remaining: ${remainingParentMins}m',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.amber[200] : Colors.amber[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick preset chips
                  Text(
                    'Quick Presets (Hadisiye Vada):',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presetTasks.map((preset) {
                      final isSelected = titleController.text == preset['title'];
                      return InkWell(
                        onTap: () {
                          setSheetState(() {
                            titleController.text = preset['title'] as String;
                            selectedDuration = preset['duration'] as int;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.amber
                                : AppColors.surfaceVariant(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? Colors.amber : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                preset['icon'] as IconData,
                                size: 14,
                                color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${preset['title']} (${preset['duration']}m)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.black : AppColors.textPrimaryColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Task Title TextField
                  Text(
                    'Urgent Task Title',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: AppColors.textPrimaryColor(context)),
                    decoration: InputDecoration(
                      hintText: 'e.g., Quick phone call with client',
                      hintStyle: TextStyle(color: AppColors.textMutedColor(context)),
                      filled: true,
                      fillColor: AppColors.surfaceVariant(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Duration selection
                  Text(
                    'Urgent Duration: $selectedDuration minutes',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [5, 10, 15, 20, 30, 45].map((dur) {
                      final isSel = selectedDuration == dur;
                      return ChoiceChip(
                        label: Text('${dur}m'),
                        selected: isSel,
                        selectedColor: Colors.amber,
                        backgroundColor: AppColors.surfaceVariant(context),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.black : AppColors.textPrimaryColor(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setSheetState(() => selectedDuration = dur);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Checkbox: Start Focus Immediately
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: Colors.amber,
                    checkColor: Colors.black,
                    title: const Text(
                      'Start Focus Timer immediately for this urgent task',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    value: focusImmediately,
                    onChanged: (val) {
                      setSheetState(() => focusImmediately = val ?? false);
                    },
                  ),
                  const SizedBox(height: 20),

                  // Save Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: Icon(focusImmediately ? Icons.play_arrow_rounded : Icons.check_circle_rounded),
                      label: Text(
                        focusImmediately ? 'Save & Start Focus Now' : 'Save Urgent Time in Block',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter an urgent task title')),
                          );
                          return;
                        }

                        final now = DateTime.now();
                        final startStr = DateFormat('hh:mm a').format(now);
                        final endStr = DateFormat('hh:mm a').format(now.add(Duration(minutes: selectedDuration)));

                        final newSubTask = TimeSubTask(
                          blockId: parentBlock.id!,
                          title: title,
                          durationMinutes: selectedDuration,
                          startTime: startStr,
                          endTime: endStr,
                          isUrgent: true,
                        );

                        await DatabaseHelper.instance.insertTimeSubTask(newSubTask);
                        if (mounted) {
                          Navigator.pop(ctx);
                          _loadBlocks();

                          if (focusImmediately) {
                            _startFocusForSubTask(newSubTask, parentBlock);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('⚡ Urgent task "$title" (${selectedDuration}m) saved in "${parentBlock.title}"!'),
                                backgroundColor: Colors.amber.shade800,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _startTransportTracking() async {
    await _transportService.startTracking();
    _syncTransportFromService();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚌 Transport timer started! Time keeps running continuously in background.'),
          backgroundColor: Color(0xFF00B4D8),
        ),
      );
    }
  }

  Future<void> _stopAndSaveTransportTracking() async {
    final block = await _transportService.stopAndSaveTracking(customDate: _selectedDate);
    _syncTransportFromService();
    _loadBlocks();

    if (mounted && block != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Transport completed: ${block.durationMinutes} mins logged to Schedule!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _cancelTransportTracking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Transport Tracking?'),
        content: const Text('Are you sure you want to stop transport tracking without saving this trip?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Tracking')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _transportService.cancelTracking();
      _syncTransportFromService();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transport tracking discarded.')),
        );
      }
    }
  }

  String _formatStopwatch(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _addQuickPreset(String title, String category, int startHour, int startMin, int endHour, int endMin) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final isPast = targetDate.isBefore(today);
    final isToday = targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day;
    int finalStartHour = startHour;
    int finalStartMin = startMin;
    int finalEndHour = endHour;
    int finalEndMin = endMin;

    if (isToday) {
      final currentTotalMin = now.hour * 60 + now.minute;
      final presetStartMin = startHour * 60 + startMin;

      // If preset time is already past today, shift start time to now + 5 minutes
      if (presetStartMin < currentTotalMin) {
        int nextMinute = ((now.minute / 5).ceil()) * 5;
        int nextHour = now.hour;
        if (nextMinute >= 60) {
          nextHour = (nextHour + 1) % 24;
          nextMinute = 0;
        }
        finalStartHour = nextHour;
        finalStartMin = nextMinute;

        final duration = _calculateDuration(
          TimeOfDay(hour: startHour, minute: startMin),
          TimeOfDay(hour: endHour, minute: endMin),
        );
        int endTotalMin = (finalStartHour * 60 + finalStartMin + duration) % (24 * 60);
        finalEndHour = endTotalMin ~/ 60;
        finalEndMin = endTotalMin % 60;
      }
    }

    final testStartMin = finalStartHour * 60 + finalStartMin;
    int testEndMin = finalEndHour * 60 + finalEndMin;
    if (testEndMin <= testStartMin) testEndMin += 24 * 60;
    final conflict = _findConflictingBlock(testStartMin, testEndMin);
    if (conflict != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Time slot conflict!\nCannot add "$title". "${conflict.title}" is already scheduled (${conflict.startTime} - ${conflict.endTime}).',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final block = TimeBlock(
      title: title,
      category: category,
      date: _dateString(_selectedDate),
      startTime: _formatTimeOfDay(TimeOfDay(hour: finalStartHour, minute: finalStartMin)),
      endTime: _formatTimeOfDay(TimeOfDay(hour: finalEndHour, minute: finalEndMin)),
      durationMinutes: _calculateDuration(
        TimeOfDay(hour: finalStartHour, minute: finalStartMin),
        TimeOfDay(hour: finalEndHour, minute: finalEndMin),
      ),
    );
    await DatabaseHelper.instance.insertTimeBlock(block);
    ScheduleNotificationService.instance.rescheduleNativeAlarms();
    _loadBlocks();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalMinutes = _blocks.fold<int>(0, (sum, b) => sum + b.durationMinutes);
    final completedBlocks = _blocks.where((b) => b.isCompleted).length;
    final progress = _blocks.isNotEmpty ? (completedBlocks / _blocks.length) : 0.0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final isPastDate = targetDate.isBefore(today);
    final isToday = targetDate.year == today.year && targetDate.month == today.month && targetDate.day == today.day;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time Planner & Schedule',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
            Text(
              isToday
                  ? "Today's Schedule"
                  : (isPastDate
                      ? "Past Activity History"
                      : "Upcoming Schedule"),
              style: TextStyle(
                fontSize: 11,
                color: isToday
                    ? AppColors.primary
                    : (isPastDate ? Colors.amber : AppColors.accentCyan),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          if (!isToday)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.today, size: 14),
                label: const Text('Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: () {
                  setState(() => _selectedDate = DateTime.now());
                  _loadBlocks();
                  _scrollToSelectedDate();
                },
              ),
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Pick Any Date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: today.subtract(const Duration(days: 365)),
                lastDate: today.add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadBlocks();
                _scrollToSelectedDate();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 26),
            tooltip: 'Add Note / Idea',
            onPressed: () => _showAddOrEditNoteDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
            tooltip: isPastDate ? 'Log Past Activity' : 'Add Time Block',
            onPressed: () => _showAddOrEditDialog(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Date Selector Strip (supports 15 days in past + today + 15 days in future)
            _buildDateStrip(),

            if (isPastDate)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  border: Border(bottom: BorderSide(color: Colors.amber.withOpacity(0.25))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 20, color: Colors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Activity History: ${DateFormat('EEEE, MMM d, yyyy').format(_selectedDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amber[200] : Colors.amber[900],
                            ),
                          ),
                          Text(
                            'All activities, commutes, and sessions for this date are shown below.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.amber[100] : Colors.amber[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: isDark ? Colors.amber[200] : Colors.amber[900],
                      ),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Log Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      onPressed: () => _showAddOrEditDialog(),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : RefreshIndicator(
                      onRefresh: _loadBlocks,
                      color: AppColors.accentCyan,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        children: [
                          if (!_hasNotificationPermission) ...[
                            _buildNotificationPermissionBanner(isDark),
                            const SizedBox(height: 16),
                          ],

                          // Daily Summary Card
                          _buildSummaryCard(totalMinutes, completedBlocks, progress, isDark),
                          const SizedBox(height: 18),

                          // Live Transport Commute Tracker Card
                          // Always show when tracking is active, or when viewing today
                          if (_isTrackingTransport || isToday) ...[
                            _buildTransportTrackerCard(isDark),
                            const SizedBox(height: 18),
                          ],

                          // Section Title: Scheduled Time Blocks
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isPastDate ? 'Recorded Time Blocks & Activities' : 'Scheduled Time Blocks',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryColor(context),
                                ),
                              ),
                              Text(
                                '${_blocks.length} Tasks',
                                style: TextStyle(
                                  color: AppColors.textSecondaryColor(context),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Blocks List or Empty State
                          if (_blocks.isEmpty)
                            _buildEmptyState(isDark)
                          else
                            ..._blocks.map((block) => _buildTimeBlockCard(block, isDark)),

                          // Day Notes & Ideas Section
                          _buildDailyNotesSection(isDark),

                          // Focus Sessions on this date (Deep Work & Pomodoros)
                          _buildFocusSessionsSection(isDark),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isPastDate ? Colors.amber.shade800 : AppColors.primary,
        foregroundColor: Colors.white,
        icon: Icon(isPastDate ? Icons.history_edu_rounded : Icons.add),
        label: Text(
          isPastDate ? 'Log Past Activity' : 'Add Time Block',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showAddOrEditDialog(),
      ),
    );
  }

  Widget _buildDateStrip() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(const Duration(days: 15));

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(bottom: BorderSide(color: AppColors.cardBorder(context), width: 0.5)),
      ),
      child: ListView.builder(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 31,
        itemBuilder: (ctx, index) {
          final day = startDate.add(Duration(days: index));
          final isSelected = day.year == _selectedDate.year &&
              day.month == _selectedDate.month &&
              day.day == _selectedDate.day;
          final isCurrentDay = day.year == now.year && day.month == now.month && day.day == now.day;
          final isPast = day.isBefore(today);

          String dayLabel = DateFormat('E').format(day);
          if (isCurrentDay) {
            dayLabel = 'Today';
          } else if (day.year == today.year && day.month == today.month && day.day == today.day - 1) {
            dayLabel = 'Yest.';
          }

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = day);
              _loadBlocks();
              _scrollToSelectedDate();
            },
            child: Container(
              width: 58,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isCurrentDay
                        ? AppColors.surfaceVariant(context)
                        : (isPast
                            ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E2A) : const Color(0xFFF3F4F6))
                            : Colors.transparent)),
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? Border.all(color: AppColors.primary, width: 2)
                    : (isCurrentDay
                        ? Border.all(color: AppColors.primary.withOpacity(0.6), width: 1.5)
                        : Border.all(color: AppColors.cardBorder(context).withOpacity(0.5), width: 0.8)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: (isSelected || isCurrentDay) ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isCurrentDay
                              ? AppColors.primary
                              : AppColors.textSecondaryColor(context)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimaryColor(context),
                    ),
                  ),
                  if (day.day == 1)
                    Text(
                      DateFormat('MMM').format(day),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white70 : AppColors.accentCyan,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFocusSessionsSection(bool isDark) {
    if (_focusSessions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 20, color: AppColors.accentCyan),
                const SizedBox(width: 8),
                Text(
                  'Focus Sessions on this Day',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_focusSessions.length} Sessions',
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._focusSessions.map((session) {
          final startTimeStr = DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(session.startTime));
          final endTimeStr = DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(session.endTime));

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder(context)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (session.completed ? AppColors.success : Colors.orange).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    session.completed ? Icons.check_circle_outline : Icons.timelapse,
                    color: session.completed ? AppColors.success : Colors.orange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.taskName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$startTimeStr - $endTimeStr • ${session.durationMinutes} mins',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (session.distractionCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${session.distractionCount} dist.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNotificationPermissionBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade700.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications Not Enabled',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.amber[200] : Colors.amber[900],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Turn on notifications to receive 5-min task warnings & 30-min checkpoints.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              await UsageTrackingService.requestNotificationPermission();
              await Future.delayed(const Duration(milliseconds: 600));
              _checkNotificationPermission();
            },
            child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int totalMinutes, int completedBlocks, double progress, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.schedule, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d').format(_selectedDate),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    Text(
                      'Total Allocated: ${_formatMinutes(totalMinutes)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: completedBlocks == _blocks.length && _blocks.isNotEmpty
                      ? AppColors.success.withOpacity(0.15)
                      : AppColors.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(progress * 100).toInt()}% Done',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: completedBlocks == _blocks.length && _blocks.isNotEmpty
                        ? AppColors.success
                        : (isDark ? AppColors.accentCyan : AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                completedBlocks == _blocks.length && _blocks.isNotEmpty
                    ? AppColors.success
                    : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Completed: $completedBlocks / ${_blocks.length} Blocks',
                style: TextStyle(fontSize: 12, color: AppColors.textMutedColor(context)),
              ),
              Text(
                'Remaining: ${_blocks.length - completedBlocks}',
                style: TextStyle(fontSize: 12, color: AppColors.textMutedColor(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransportTrackerCard(bool isDark) {
    const transportColor = Color(0xFF00B4D8);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isTrackingTransport
            ? transportColor.withOpacity(0.12)
            : AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isTrackingTransport
              ? transportColor
              : AppColors.cardBorder(context),
          width: _isTrackingTransport ? 1.8 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: transportColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_bus_filled_rounded,
                  color: transportColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Live Transport Tracker',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                        if (_isTrackingTransport) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isTrackingTransport
                          ? 'Calculating travel duration in real-time...'
                          : 'Unpredictable travel time? Start when you leave, end on arrival.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryColor(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_isTrackingTransport) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 20, color: transportColor),
                      const SizedBox(width: 8),
                      Text(
                        'Travel Time: ',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondaryColor(context)),
                      ),
                      Text(
                        _formatStopwatch(_transportElapsedSeconds),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: transportColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Started: ${_transportStartTime != null ? DateFormat('hh:mm a').format(_transportStartTime!) : ''}',
                    style: TextStyle(fontSize: 11, color: AppColors.textMutedColor(context)),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.stop_circle, size: 20),
                label: const Text('End & Save Transport Block', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _stopAndSaveTransportTracking,
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                onPressed: _cancelTransportTracking,
                child: Text(
                  'Discard trip without saving',
                  style: TextStyle(
                    color: AppColors.textMutedColor(context),
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: transportColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Start Transport Commute', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _startTransportTracking,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeBlockCard(TimeBlock block, bool isDark) {
    final catColor = _getCategoryColor(block.category);
    final isDone = block.isCompleted;

    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    final currentMin = now.hour * 60 + now.minute;
    final startMin = _timeToMinutes(block.startTime);
    int endMin = _timeToMinutes(block.endTime);
    if (endMin <= startMin) endMin += 24 * 60;
    final isRunningNow = isToday && !block.isCompleted && (currentMin >= startMin && currentMin < endMin);

    final subTasks = _subTasks[block.id] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRunningNow
            ? (isDark ? const Color(0xFF1E2838) : const Color(0xFFF0F7FF))
            : AppColors.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRunningNow
              ? Colors.amber
              : (isDone ? AppColors.success.withOpacity(0.3) : AppColors.cardBorder(context)),
          width: isRunningNow ? 2.0 : (isDone ? 1.5 : 1),
        ),
        boxShadow: isRunningNow
            ? [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _toggleBlockStatus(block),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prominent, interactive Checkbox with large touch target
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggleBlockStatus(block),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, top: 2),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDone ? AppColors.success : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDone ? AppColors.success : (isDark ? Colors.grey[400]! : Colors.grey[500]!),
                            width: 2.2,
                          ),
                          boxShadow: isDone
                              ? [
                                  BoxShadow(
                                    color: AppColors.success.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: isDone
                            ? const Icon(Icons.check_rounded, size: 22, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Time badge, Category and Running Now indicator
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getCategoryIcon(block.category), size: 12, color: catColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    block.category,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: catColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.access_time, size: 13, color: AppColors.textMutedColor(context)),
                            const SizedBox(width: 4),
                            Text(
                              '${block.startTime} - ${block.endTime}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondaryColor(context),
                              ),
                            ),
                            if (isRunningNow) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.fiber_manual_record, size: 7, color: Colors.redAccent),
                                    SizedBox(width: 3),
                                    Text(
                                      'RUNNING NOW',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.redAccent,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant(context),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatMinutes(block.durationMinutes),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryColor(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Title
                        Text(
                          block.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDone
                                ? AppColors.textMutedColor(context)
                                : AppColors.textPrimaryColor(context),
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),

                        if (block.notes != null && block.notes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            block.notes!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMutedColor(context),
                            ),
                          ),
                        ],

                        // Urgent Sub-Tasks list inside block
                        if (subTasks.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E222A) : const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                                width: 0.8,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.flash_on_rounded, size: 14, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Urgent In-Block Tasks (${subTasks.where((s) => s.isCompleted).length}/${subTasks.length})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.amber[200] : Colors.amber[900],
                                      ),
                                    ),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () => _showAllocateUrgentTimeDialog(block),
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.add, size: 12, color: AppColors.primary),
                                            Text(
                                              'Add',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? AppColors.accentCyan : AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ...subTasks.map((subTask) {
                                  final isSubDone = subTask.isCompleted;
                                  return Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSubDone
                                          ? (isDark ? Colors.green.withOpacity(0.08) : Colors.green.withOpacity(0.05))
                                          : AppColors.surface(context),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _toggleSubTask(subTask),
                                          child: Icon(
                                            isSubDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                            size: 16,
                                            color: isSubDone ? AppColors.success : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            subTask.title,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              decoration: isSubDone ? TextDecoration.lineThrough : null,
                                              color: isSubDone
                                                  ? AppColors.textMutedColor(context)
                                                  : AppColors.textPrimaryColor(context),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '⚡ ${subTask.durationMinutes}m',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.amber[200] : Colors.amber[900],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.play_circle_outline, size: 18),
                                          color: AppColors.primary,
                                          tooltip: 'Focus on this task',
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _startFocusForSubTask(subTask, block),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 14),
                                          color: AppColors.textMutedColor(context),
                                          tooltip: 'Remove',
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _deleteSubTask(subTask),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],

                        // Quick banner if running now and no subtasks yet
                        if (isRunningNow && subTasks.isEmpty) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _showAllocateUrgentTimeDialog(block),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.withOpacity(0.35)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.flash_on, size: 16, color: Colors.amber),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Running now! Urgent work came up?',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.amber[200] : Colors.amber[900],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '+ Allocate Time',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context).withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  // Quick Start Focus Session button
                  InkWell(
                    onTap: () => _startFocusForBlock(block),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_fill, size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Focus',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.accentCyan : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Urgent Time Slot Allocation Button
                  InkWell(
                    onTap: () => _showAllocateUrgentTimeDialog(block),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on_rounded, size: 15, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            '+ Urgent',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amber[300] : Colors.amber[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Edit Button
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppColors.textSecondaryColor(context),
                    tooltip: 'Edit',
                    onPressed: () => _showAddOrEditDialog(blockToEdit: block),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),

                  const SizedBox(width: 6),

                  // Delete Button - strictly inside card box with safe spacing
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppColors.danger,
                    tooltip: 'Delete',
                    onPressed: () => _deleteBlock(block.id!),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_month, color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 14),
          Text(
            'No Time Blocks Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Plan your day by assigning dedicated time slots to study, work, or activities.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Quick Suggested Blocks:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMutedColor(context),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ActionChip(
                avatar: const Icon(Icons.school, size: 14, color: AppColors.primary),
                label: const Text('Study (08:30 - 10:00 AM)'),
                labelStyle: const TextStyle(fontSize: 11),
                onPressed: () => _addQuickPreset('Morning Study Session', 'Study', 8, 30, 10, 0),
              ),
              ActionChip(
                avatar: const Icon(Icons.code, size: 14, color: AppColors.accentCyan),
                label: const Text('Coding (10:30 AM - 12:00 PM)'),
                labelStyle: const TextStyle(fontSize: 11),
                onPressed: () => _addQuickPreset('App Development / Coding', 'Coding', 10, 30, 12, 0),
              ),
              ActionChip(
                avatar: const Icon(Icons.fitness_center, size: 14, color: AppColors.success),
                label: const Text('Workout (05:00 - 06:00 PM)'),
                labelStyle: const TextStyle(fontSize: 11),
                onPressed: () => _addQuickPreset('Workout & Exercise', 'Fitness', 17, 0, 18, 0),
              ),
              ActionChip(
                avatar: const Icon(Icons.directions_bus_rounded, size: 14, color: Color(0xFF00B4D8)),
                label: const Text('Live Transport Tracker'),
                labelStyle: const TextStyle(fontSize: 11),
                onPressed: _startTransportTracking,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String? hexString) {
    if (hexString == null) return const Color(0xFF6C5CE7);
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF6C5CE7);
    }
  }

  IconData _getNoteCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'idea':
        return Icons.lightbulb_outline_rounded;
      case 'important':
        return Icons.push_pin_outlined;
      case 'reflection':
        return Icons.psychology_outlined;
      case 'todo':
        return Icons.checklist_rounded;
      default:
        return Icons.edit_note_rounded;
    }
  }

  Future<void> _deleteDailyNote(DailyNote note) async {
    if (note.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note / Idea?'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteDailyNote(note.id!);
      _loadBlocks();
    }
  }

  void _showAddOrEditNoteDialog({DailyNote? noteToEdit}) {
    final titleController = TextEditingController(text: noteToEdit?.title ?? '');
    final contentController = TextEditingController(text: noteToEdit?.content ?? '');
    String selectedCategory = noteToEdit?.category ?? 'Idea';
    String selectedColorHex = noteToEdit?.colorHex ?? '#FFD166';
    bool isPinned = noteToEdit?.isPinned ?? false;

    final categories = [
      {'name': 'Idea', 'icon': Icons.lightbulb_outline_rounded, 'color': '#FFD166'},
      {'name': 'Note', 'icon': Icons.edit_note_rounded, 'color': '#06D6A0'},
      {'name': 'Important', 'icon': Icons.push_pin_outlined, 'color': '#EF476F'},
      {'name': 'Reflection', 'icon': Icons.psychology_outlined, 'color': '#7209B7'},
      {'name': 'Todo', 'icon': Icons.checklist_rounded, 'color': '#118AB2'},
    ];

    final colorOptions = [
      '#FFD166', // Amber / Idea
      '#06D6A0', // Emerald / Note
      '#118AB2', // Ocean Cyan
      '#EF476F', // Coral / Important
      '#7209B7', // Purple / Deep Reflection
      '#FF8C00', // Orange
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
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
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          noteToEdit == null ? Icons.lightbulb_rounded : Icons.edit_note_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              noteToEdit == null ? 'Add Day Note or Idea' : 'Edit Note / Idea',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryColor(context),
                              ),
                            ),
                            Text(
                              DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                        color: AppColors.textMutedColor(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category selector chips
                  Text(
                    'Category / Type:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = selectedCategory == cat['name'];
                      return ChoiceChip(
                        avatar: Icon(
                          cat['icon'] as IconData,
                          size: 16,
                          color: isSelected ? Colors.black : AppColors.primary,
                        ),
                        label: Text(cat['name'] as String),
                        selected: isSelected,
                        selectedColor: AppColors.accentCyan,
                        backgroundColor: AppColors.surfaceVariant(context),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : AppColors.textPrimaryColor(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setSheetState(() {
                              selectedCategory = cat['name'] as String;
                              selectedColorHex = cat['color'] as String;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Title TextField
                  Text(
                    'Title or Topic',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: AppColors.textPrimaryColor(context)),
                    decoration: InputDecoration(
                      hintText: 'e.g., Creative app feature idea, Day reflection...',
                      hintStyle: TextStyle(color: AppColors.textMutedColor(context)),
                      filled: true,
                      fillColor: AppColors.surfaceVariant(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Content multiline TextField
                  Text(
                    'Note / Idea Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    minLines: 3,
                    style: TextStyle(color: AppColors.textPrimaryColor(context)),
                    decoration: InputDecoration(
                      hintText: 'Jot down thoughts, notes, bullet points, or reflections for this day...',
                      hintStyle: TextStyle(color: AppColors.textMutedColor(context)),
                      filled: true,
                      fillColor: AppColors.surfaceVariant(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Color and Pin row
                  Row(
                    children: [
                      Text(
                        'Tag Color: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...colorOptions.map((hex) {
                        final color = _hexToColor(hex);
                        final isSel = selectedColorHex == hex;
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedColorHex = hex),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSel
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSel
                                ? const Icon(Icons.check, size: 14, color: Colors.black87)
                                : null,
                          ),
                        );
                      }),
                      const Spacer(),
                      // Pin toggle
                      InkWell(
                        onTap: () => setSheetState(() => isPinned = !isPinned),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                size: 18,
                                color: isPinned ? Colors.amber : AppColors.textMutedColor(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPinned ? 'Pinned' : 'Pin',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isPinned ? Colors.amber : AppColors.textMutedColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: Text(
                        noteToEdit == null ? 'Save Note for This Day' : 'Update Note',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final content = contentController.text.trim();
                        if (title.isEmpty && content.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a note title or content')),
                          );
                          return;
                        }

                        final dateStr = _dateString(_selectedDate);
                        if (noteToEdit == null) {
                          final newNote = DailyNote(
                            date: dateStr,
                            title: title.isEmpty ? 'Quick Note' : title,
                            content: content,
                            category: selectedCategory,
                            colorHex: selectedColorHex,
                            isPinned: isPinned,
                          );
                          await DatabaseHelper.instance.insertDailyNote(newNote);
                        } else {
                          final updated = noteToEdit.copyWith(
                            title: title.isEmpty ? 'Quick Note' : title,
                            content: content,
                            category: selectedCategory,
                            colorHex: selectedColorHex,
                            isPinned: isPinned,
                            updatedAt: DateTime.now().millisecondsSinceEpoch,
                          );
                          await DatabaseHelper.instance.updateDailyNote(updated);
                        }

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
                          _loadBlocks();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                noteToEdit == null ? '💡 Day Note & Idea saved!' : '✅ Note updated!',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyNotesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_rounded, size: 20, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Day Notes & Ideas',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                if (_dailyNotes.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_dailyNotes.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.amber[200] : Colors.amber[900],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
              label: Text(
                'Add Note/Idea',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.accentCyan : AppColors.primary,
                ),
              ),
              onPressed: () => _showAddOrEditNoteDialog(),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_dailyNotes.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder(context)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tips_and_updates_outlined, color: Colors.amber, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Notes or Ideas for this day yet',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Record your daily insights, quick ideas, key thoughts, or reflections.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
                  tooltip: 'Add Note',
                  onPressed: () => _showAddOrEditNoteDialog(),
                ),
              ],
            ),
          )
        else
          ..._dailyNotes.map((note) => _buildNoteCard(note, isDark)),
      ],
    );
  }

  Widget _buildNoteCard(DailyNote note, bool isDark) {
    final noteColor = _hexToColor(note.colorHex);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: note.isPinned ? Colors.amber.withValues(alpha: 0.6) : AppColors.cardBorder(context),
          width: note.isPinned ? 1.5 : 1.0,
        ),
        boxShadow: note.isPinned
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showAddOrEditNoteDialog(noteToEdit: note),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: noteColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: noteColor.withValues(alpha: 0.3), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getNoteCategoryIcon(note.category),
                          size: 13,
                          color: noteColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          note.category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: noteColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (note.isPinned)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      child: const Icon(Icons.push_pin, size: 16, color: Colors.amber),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    color: AppColors.textMutedColor(context),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Edit',
                    onPressed: () => _showAddOrEditNoteDialog(noteToEdit: note),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: AppColors.danger.withValues(alpha: 0.8),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Delete',
                    onPressed: () => _deleteDailyNote(note),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              if (note.content.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  note.content,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryColor(context),
                    height: 1.35,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

