import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../data/models/time_block.dart';
import 'focus_screen.dart';

class TimePlannerScreen extends StatefulWidget {
  const TimePlannerScreen({super.key});

  @override
  State<TimePlannerScreen> createState() => _TimePlannerScreenState();
}

class _TimePlannerScreenState extends State<TimePlannerScreen> {
  DateTime _selectedDate = DateTime.now();
  List<TimeBlock> _blocks = [];
  bool _isLoading = true;

  final List<String> _categories = [
    'Study',
    'Work',
    'Coding',
    'Reading',
    'Fitness',
    'Personal',
    'Meeting',
    'Break',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  String _dateString(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  Future<void> _loadBlocks() async {
    setState(() => _isLoading = true);
    final dateStr = _dateString(_selectedDate);
    final blocks = await DatabaseHelper.instance.getTimeBlocksForDate(dateStr);
    setState(() {
      _blocks = blocks;
      _isLoading = false;
    });
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

    if (targetDate.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot plan or schedule time blocks for past dates.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final titleController = TextEditingController(text: blockToEdit?.title ?? '');
    final notesController = TextEditingController(text: blockToEdit?.notes ?? '');
    String selectedCategory = blockToEdit?.category ?? 'Study';

    TimeOfDay startTime = blockToEdit != null
        ? _parseTimeOfDay(blockToEdit.startTime)
        : const TimeOfDay(hour: 9, minute: 0);

    TimeOfDay endTime = blockToEdit != null
        ? _parseTimeOfDay(blockToEdit.endTime)
        : const TimeOfDay(hour: 10, minute: 30);

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
                  Text(
                    'Time Slot',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryColor(context),
                    ),
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
                      color: AppColors.primary.withOpacity(0.1),
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

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
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

                        Navigator.pop(ctx);
                        _loadBlocks();
                      },
                      child: Text(
                        blockToEdit == null ? 'Add to Schedule' : 'Update Time Block',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
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

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final hm = parts[0].split(':');
      int h = int.parse(hm[0]);
      int m = int.parse(hm[1]);
      if (parts.length > 1) {
        final period = parts[1].toUpperCase();
        if (period == 'PM' && h < 12) h += 12;
        if (period == 'AM' && h == 12) h = 0;
      }
      return TimeOfDay(hour: h, minute: m);
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
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

  Future<void> _toggleBlockStatus(TimeBlock block) async {
    if (block.id == null) return;
    await DatabaseHelper.instance.toggleTimeBlock(block.id!, !block.isCompleted);
    _loadBlocks();
  }

  Future<void> _deleteBlock(int id) async {
    await DatabaseHelper.instance.deleteTimeBlock(id);
    _loadBlocks();
  }

  void _startFocusForBlock(TimeBlock block) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FocusScreen(
          initialTask: block.title,
          initialDurationMinutes: block.durationMinutes,
        ),
      ),
    );
  }

  void _addQuickPreset(String title, String category, int startHour, int startMin, int endHour, int endMin) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (targetDate.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot add tasks to past dates.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final block = TimeBlock(
      title: title,
      category: category,
      date: _dateString(_selectedDate),
      startTime: _formatTimeOfDay(TimeOfDay(hour: startHour, minute: startMin)),
      endTime: _formatTimeOfDay(TimeOfDay(hour: endHour, minute: endMin)),
      durationMinutes: _calculateDuration(
        TimeOfDay(hour: startHour, minute: startMin),
        TimeOfDay(hour: endHour, minute: endMin),
      ),
    );
    await DatabaseHelper.instance.insertTimeBlock(block);
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
                          // Daily Summary Card
                          _buildSummaryCard(totalMinutes, completedBlocks, progress, isDark),
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom checkbox
                InkWell(
                  onTap: () => _toggleBlockStatus(block),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isDone ? AppColors.success : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDone ? AppColors.success : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: isDone
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

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
                              color: catColor.withOpacity(0.12),
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
              color: AppColors.surfaceVariant(context).withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Quick Start Focus Session button
                InkWell(
                  onTap: () => _startFocusForBlock(block),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.play_circle_fill, size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Start Focus Timer',
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
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: AppColors.danger,
                      tooltip: 'Delete',
                      onPressed: () => _deleteBlock(block.id!),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
            ],
          ),
        ],
      ),
    );
  }
}
