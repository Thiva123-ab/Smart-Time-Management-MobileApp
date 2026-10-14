import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../data/models/time_block.dart';
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
    await DatabaseHelper.instance.toggleTimeBlock(block.id!, willComplete);
    ScheduleNotificationService.instance.rescheduleNativeAlarms();
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
    await DatabaseHelper.instance.deleteTimeBlock(id);
    ScheduleNotificationService.instance.rescheduleNativeAlarms();
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

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          'Time Planner & Schedule',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'Pick Date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
                firstDate: today,
                lastDate: today.add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadBlocks();
              }
            },
          ),
          if (!isPastDate)
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
              tooltip: 'Add Time Block',
              onPressed: () => _showAddOrEditDialog(),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Date Selector Strip
            _buildDateStrip(),

            if (isPastDate)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.amber.withOpacity(0.15),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Past Date (Read-Only) - New scheduling is disabled for past days.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.amber[200] : Colors.amber[900],
                        ),
                      ),
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
                          _buildTransportTrackerCard(isDark),
                          const SizedBox(height: 18),

                          // Section Title
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Scheduled Time Blocks',
                                style: TextStyle(
                                  fontSize: 18,
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

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: isPastDate
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Time Block', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showAddOrEditDialog(),
            ),
    );
  }

  Widget _buildDateStrip() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(bottom: BorderSide(color: AppColors.cardBorder(context), width: 0.5)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 14,
        itemBuilder: (ctx, index) {
          final day = today.add(Duration(days: index));
          final isSelected = day.year == _selectedDate.year &&
              day.month == _selectedDate.month &&
              day.day == _selectedDate.day;
          final isCurrentDay = day.year == now.year && day.month == now.month && day.day == now.day;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = day);
              _loadBlocks();
            },
            child: Container(
              width: 58,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isCurrentDay ? AppColors.surfaceVariant(context) : Colors.transparent),
                borderRadius: BorderRadius.circular(16),
                border: isCurrentDay && !isSelected
                    ? Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(day),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white70
                          : AppColors.textSecondaryColor(context),
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
                ],
              ),
            ),
          );
        },
      ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone
              ? AppColors.success.withOpacity(0.3)
              : AppColors.cardBorder(context),
          width: isDone ? 1.5 : 1,
        ),
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
                        // Time badge and Category
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
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context).withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dedicated Tick / Mark Complete Button
                  InkWell(
                    onTap: () => _toggleBlockStatus(block),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: isDone ? AppColors.success : (isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isDone ? 'Completed ✓' : 'Mark Done',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDone ? AppColors.success : AppColors.textPrimaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Quick Start Focus Session button
                  InkWell(
                    onTap: () => _startFocusForBlock(block),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.play_circle_fill, size: 18, color: AppColors.primary),
                          const SizedBox(width: 5),
                          Text(
                            'Focus Timer',
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

                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: AppColors.textSecondaryColor(context),
                        tooltip: 'Edit',
                        onPressed: () => _showAddOrEditDialog(blockToEdit: block),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: AppColors.danger,
                        tooltip: 'Delete',
                        onPressed: () => _deleteBlock(block.id!),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    ],
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
}
