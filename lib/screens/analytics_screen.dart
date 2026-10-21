import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../data/models/app_usage.dart';
import '../data/models/goal.dart';
import '../data/models/time_block.dart';
import '../data/models/daily_note.dart';
import '../data/models/time_budget.dart';
import '../domain/app_category_manager.dart';
import '../domain/productivity_score_engine.dart';
import '../services/usage_tracking_service.dart';
import '../widgets/app_icon_widget.dart';
import '../services/sleep_tracking_service.dart';

class UnifiedNoteItem {
  final String id;
  final String date; // yyyy-MM-dd
  final String title;
  final String content;
  final String category; // Idea, Note, Important, Reflection, Todo, Task Note, Sleep, Transport
  final String? colorHex;
  final bool isPinned;
  final int timestamp;
  final DailyNote? dailyNote;
  final TimeBlock? timeBlock;

  UnifiedNoteItem({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
    required this.category,
    this.colorHex,
    this.isPinned = false,
    required this.timestamp,
    this.dailyNote,
    this.timeBlock,
  });
}

class DayAnalyticsData {
  final DateTime date;
  final String dateStr;
  final String dayName;
  final String shortDate;
  final int score;
  final ScoreResult scoreResult;
  final List<AppUsage> usages;
  final Map<String, int> categoryTotals;
  final int totalMinutes;
  final int productiveMinutes;
  final int distractingMinutes;
  final List<Goal> goals;
  final List<TimeBlock> timeBlocks;
  final List<DailyNote> notes;
  final int elapsedDayMinutes;
  final int sleepMinutes;
  final int offlineProductiveMinutes;
  final int phoneWastedMinutes;
  final int otherWastedMinutes;
  final int totalWastedMinutes;
  final List<AppUsage> topDistractingApps;

  DayAnalyticsData({
    required this.date,
    required this.dateStr,
    required this.dayName,
    required this.shortDate,
    required this.score,
    required this.scoreResult,
    required this.usages,
    required this.categoryTotals,
    required this.totalMinutes,
    required this.productiveMinutes,
    required this.distractingMinutes,
    required this.goals,
    required this.timeBlocks,
    required this.notes,
    this.elapsedDayMinutes = 1440,
    this.sleepMinutes = 0,
    this.offlineProductiveMinutes = 0,
    this.phoneWastedMinutes = 0,
    this.otherWastedMinutes = 0,
    this.totalWastedMinutes = 0,
    this.topDistractingApps = const [],
  });
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedPeriodIndex = 0; // 0: Today/Day, 1: This Week, 2: This Month
  int _selectedDayIndex = 6; // Default to last element (Today)
  bool _isLoading = true;

  int _analyticsMainTab = 0; // 0: Analytics Overview, 1: All Notes History
  List<DailyNote> _allDailyNotes = [];
  List<TimeBlock> _allTaskBlocksWithNotes = [];
  String _noteSearchQuery = '';
  String _selectedNoteCategory = 'All';
  final TextEditingController _noteSearchController = TextEditingController();

  List<DayAnalyticsData> _days = [];
  Map<String, TimeBudget> _budgetsMap = {};

  @override
  void initState() {
    super.initState();
    _loadAllAnalytics();
  }

  @override
  void dispose() {
    _noteSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllAnalytics() async {
    setState(() => _isLoading = true);

    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    final List<DayAnalyticsData> loadedDays = [];

    // Load budgets map
    final budgets = await db.getAllBudgets();
    final bMap = <String, TimeBudget>{};
    for (var b in budgets) {
      bMap[b.category] = b;
    }

    // Load 7 days: 6 days ago up to today
    for (int i = 6; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      final dayName = DateFormat('EEE').format(targetDate);
      final shortDate = DateFormat('MMM d').format(targetDate);

      // Fetch usages
      List<AppUsage> usages = [];
      if (i == 0) {
        usages = await UsageTrackingService.fetchTodayUsage();
      } else {
        usages = await UsageTrackingService.fetchUsageForDate(targetDate);
      }

      int total = 0;
      int prod = 0;
      int dist = 0;
      final catMap = <String, int>{};

      for (var u in usages) {
        total += u.durationMinutes;
        catMap[u.category] = (catMap[u.category] ?? 0) + u.durationMinutes;
        if (AppCategoryManager.isProductive(u.category)) {
          prod += u.durationMinutes;
        } else if (AppCategoryManager.isDistracting(u.category)) {
          dist += u.durationMinutes;
        }
      }

      // Fetch goals, blocks, and notes for this date
      final goals = await db.getGoalsForDate(dateStr);
      final blocks = await db.getTimeBlocksForDate(dateStr);
      final notes = await db.getDailyNotesForDate(dateStr);

      final isToday = (i == 0);
      final elapsedDayMinutes = isToday
          ? (now.hour * 60 + now.minute).clamp(1, 1440)
          : 1440;

      // Calculate Sleep minutes from TimeBlocks
      int sleepMins = blocks
          .where((b) => b.category.trim().toLowerCase() == 'sleep')
          .fold<int>(0, (sum, b) => sum + b.durationMinutes);

      // If it's today and live sleep tracking is currently ongoing, add elapsed
      if (isToday && SleepTrackingService.instance.isTracking) {
        sleepMins += (SleepTrackingService.instance.currentElapsedSeconds ~/ 60);
      }

      // Offline productive minutes (completed tasks: Study, Work, Coding, Reading, Fitness, Meeting, Transport, etc.)
      int offlineProdMins = blocks
          .where((b) =>
              b.isCompleted &&
              b.category.trim().toLowerCase() != 'sleep' &&
              b.category.trim().toLowerCase() != 'break' &&
              b.category.trim().toLowerCase() != 'idle' &&
              b.category.trim().toLowerCase() != 'entertainment')
          .fold<int>(0, (sum, b) => sum + b.durationMinutes);

      // Offline explicit distraction/break blocks
      int offlineDistMins = blocks
          .where((b) =>
              b.category.trim().toLowerCase() == 'break' ||
              b.category.trim().toLowerCase() == 'idle' ||
              b.category.trim().toLowerCase() == 'entertainment')
          .fold<int>(0, (sum, b) => sum + b.durationMinutes);

      // Phone wasted time = distracting phone apps
      int phoneWaste = dist;

      // Accounted intentional minutes:
      // Phone productive + offline productive + sleep + phone wasted + offline breaks
      int accountedMins = prod + offlineProdMins + sleepMins + phoneWaste + offlineDistMins;
      int untrackedIdleMins = (elapsedDayMinutes - accountedMins).clamp(0, elapsedDayMinutes);

      // Other wasted time (anekuth eevata): offline idle & procrastination + explicit distraction blocks
      int otherWaste = offlineDistMins + untrackedIdleMins;

      // Total wasted time for the day
      int totalWaste = phoneWaste + otherWaste;

      // Top distracting apps sorted by duration
      final distractingAppList = usages
          .where((u) =>
              AppCategoryManager.isDistracting(u.category) ||
              u.category == 'Social Media' ||
              u.category == 'Entertainment' ||
              u.category == 'Gaming')
          .where((u) => u.durationMinutes > 0)
          .toList()
        ..sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));

      final completedGoals = goals.where((g) => g.status == 'COMPLETED').length;
      final goalPct = goals.isNotEmpty
          ? (completedGoals * 100) ~/ goals.length
          : (blocks.isNotEmpty
              ? ((blocks.where((b) => b.isCompleted).length * 100) ~/ blocks.length)
              : 75);

      final scoreRes = ProductivityScoreEngine.calculateScore(
        goalCompletionPercentage: goalPct,
        productiveMinutes: prod,
        distractingMinutes: dist,
        focusMinutes: prod > 60 ? 60 : prod,
        streakDays: 4,
      );

      loadedDays.add(
        DayAnalyticsData(
          date: targetDate,
          dateStr: dateStr,
          dayName: dayName,
          shortDate: shortDate,
          score: scoreRes.totalScore,
          scoreResult: scoreRes,
          usages: usages,
          categoryTotals: catMap,
          totalMinutes: total,
          productiveMinutes: prod,
          distractingMinutes: dist,
          goals: goals,
          timeBlocks: blocks,
          notes: notes,
          elapsedDayMinutes: elapsedDayMinutes,
          sleepMinutes: sleepMins,
          offlineProductiveMinutes: offlineProdMins,
          phoneWastedMinutes: phoneWaste,
          otherWastedMinutes: otherWaste,
          totalWastedMinutes: totalWaste,
          topDistractingApps: distractingAppList,
        ),
      );
    }

    final allDailyNotes = await db.getAllDailyNotes();
    final allTaskBlocks = await db.getAllTimeBlocksWithNotes();

    if (mounted) {
      setState(() {
        _days = loadedDays;
        _budgetsMap = bMap;
        _allDailyNotes = allDailyNotes;
        _allTaskBlocksWithNotes = allTaskBlocks;
        _selectedDayIndex = loadedDays.isNotEmpty ? loadedDays.length - 1 : 0;
        _isLoading = false;
      });
    }
  }

  List<UnifiedNoteItem> get _unifiedNotes {
    final List<UnifiedNoteItem> items = [];

    for (final note in _allDailyNotes) {
      items.add(
        UnifiedNoteItem(
          id: 'daily_${note.id}',
          date: note.date,
          title: note.title.isNotEmpty ? note.title : 'Quick Note',
          content: note.content,
          category: note.category.isNotEmpty ? note.category : 'Idea',
          colorHex: note.colorHex,
          isPinned: note.isPinned,
          timestamp: note.createdAt,
          dailyNote: note,
        ),
      );
    }

    for (final block in _allTaskBlocksWithNotes) {
      final cat = block.category == 'Sleep'
          ? 'Sleep'
          : (block.category == 'Transport' ? 'Transport' : 'Task Note');
      DateTime? dt;
      try {
        dt = DateTime.parse(block.date);
      } catch (_) {}
      final ts = dt?.millisecondsSinceEpoch ?? 0;

      items.add(
        UnifiedNoteItem(
          id: 'block_${block.id}',
          date: block.date,
          title: block.title.isNotEmpty ? block.title : 'Activity Note',
          content: block.notes ?? '',
          category: cat,
          colorHex: null,
          isPinned: false,
          timestamp: ts,
          timeBlock: block,
        ),
      );
    }

    // Sort: 1) Date descending (most recent date on top)
    // 2) If same date, pinned first
    // 3) Timestamp descending
    items.sort((a, b) {
      final dateCmp = b.date.compareTo(a.date);
      if (dateCmp != 0) return dateCmp;
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.timestamp.compareTo(a.timestamp);
    });

    return items;
  }

  List<UnifiedNoteItem> get _filteredNotes {
    final all = _unifiedNotes;
    return all.where((item) {
      if (_selectedNoteCategory != 'All' && item.category != _selectedNoteCategory) {
        return false;
      }
      if (_noteSearchQuery.trim().isNotEmpty) {
        final q = _noteSearchQuery.toLowerCase().trim();
        final inTitle = item.title.toLowerCase().contains(q);
        final inContent = item.content.toLowerCase().contains(q);
        final inDate = item.date.toLowerCase().contains(q);
        final inCat = item.category.toLowerCase().contains(q);
        if (!inTitle && !inContent && !inDate && !inCat) return false;
      }
      return true;
    }).toList();
  }

  Color _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primary;
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Color _getNoteCategoryColor(String category, String? hex) {
    if (hex != null && hex.isNotEmpty) return _hexToColor(hex);
    switch (category) {
      case 'Idea':
        return Colors.amber;
      case 'Important':
        return const Color(0xFFEF4444);
      case 'Reflection':
        return const Color(0xFF8B5CF6);
      case 'Todo':
        return const Color(0xFF10B981);
      case 'Sleep':
        return const Color(0xFF6C5CE7);
      case 'Transport':
        return const Color(0xFFF97316);
      case 'Task Note':
        return const Color(0xFF06B6D4);
      case 'Note':
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _getNoteCategoryIcon(String category) {
    switch (category) {
      case 'Idea':
        return Icons.lightbulb_rounded;
      case 'Important':
        return Icons.star_rounded;
      case 'Reflection':
        return Icons.psychology_rounded;
      case 'Todo':
        return Icons.check_circle_outline_rounded;
      case 'Sleep':
        return Icons.bedtime_rounded;
      case 'Transport':
        return Icons.directions_car_rounded;
      case 'Task Note':
        return Icons.timelapse_rounded;
      case 'Note':
      default:
        return Icons.description_rounded;
    }
  }

  String _formatNoteDateHeader(String dateStr) {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

    DateTime? dt;
    try {
      dt = DateTime.parse(dateStr);
    } catch (_) {}

    final formatted = dt != null ? DateFormat('EEEE, MMM d, yyyy').format(dt) : dateStr;

    if (dateStr == todayStr) {
      return 'Today • $formatted';
    } else if (dateStr == yesterdayStr) {
      return 'Yesterday • $formatted';
    }
    return formatted;
  }

  String _formatTimestamp(int timestamp, String dateStr) {
    if (timestamp <= 0) return dateStr;
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('MMM d • hh:mm a').format(dt);
  }

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  DayAnalyticsData get _currentDay {
    if (_days.isEmpty) {
      final now = DateTime.now();
      final dummyScore = ProductivityScoreEngine.calculateScore(
        goalCompletionPercentage: 80,
        productiveMinutes: 120,
        distractingMinutes: 30,
        focusMinutes: 60,
      );
      return DayAnalyticsData(
        date: now,
        dateStr: DateFormat('yyyy-MM-dd').format(now),
        dayName: 'Today',
        shortDate: DateFormat('MMM d').format(now),
        score: dummyScore.totalScore,
        scoreResult: dummyScore,
        usages: [],
        categoryTotals: {},
        totalMinutes: 0,
        productiveMinutes: 0,
        distractingMinutes: 0,
        goals: [],
        timeBlocks: [],
        notes: [],
      );
    }
    final safeIndex = _selectedDayIndex.clamp(0, _days.length - 1);
    return _days[safeIndex];
  }

  // Aggregated data for Period modes
  int get _activeTotalMinutes {
    if (_selectedPeriodIndex == 0) return _currentDay.totalMinutes;
    if (_days.isEmpty) return 0;
    final multiplier = _selectedPeriodIndex == 2 ? 4.2 : 1.0;
    final weekSum = _days.fold<int>(0, (sum, d) => sum + d.totalMinutes);
    return (weekSum * multiplier).round();
  }

  int get _activeProductiveMinutes {
    if (_selectedPeriodIndex == 0) return _currentDay.productiveMinutes;
    if (_days.isEmpty) return 0;
    final multiplier = _selectedPeriodIndex == 2 ? 4.2 : 1.0;
    final weekSum = _days.fold<int>(0, (sum, d) => sum + d.productiveMinutes);
    return (weekSum * multiplier).round();
  }

  int get _activeDistractingMinutes {
    if (_selectedPeriodIndex == 0) return _currentDay.distractingMinutes;
    if (_days.isEmpty) return 0;
    final multiplier = _selectedPeriodIndex == 2 ? 4.2 : 1.0;
    final weekSum = _days.fold<int>(0, (sum, d) => sum + d.distractingMinutes);
    return (weekSum * multiplier).round();
  }

  int get _activePhoneWastedMinutes {
    if (_selectedPeriodIndex == 0) return _currentDay.phoneWastedMinutes;
    if (_days.isEmpty) return 0;
    final multiplier = _selectedPeriodIndex == 2 ? 4.2 : 1.0;
    final weekSum = _days.fold<int>(0, (sum, d) => sum + d.phoneWastedMinutes);
    return (weekSum * multiplier).round();
  }

  int get _activeOtherWastedMinutes {
    if (_selectedPeriodIndex == 0) return _currentDay.otherWastedMinutes;
    if (_days.isEmpty) return 0;
    final multiplier = _selectedPeriodIndex == 2 ? 4.2 : 1.0;
    final weekSum = _days.fold<int>(0, (sum, d) => sum + d.otherWastedMinutes);
    return (weekSum * multiplier).round();
  }

  int get _activeTotalWastedMinutes => _activePhoneWastedMinutes + _activeOtherWastedMinutes;

  int get _activeSleepMinutes {
    if (_selectedPeriodIndex == 0) return _currentDay.sleepMinutes;
    if (_days.isEmpty) return 0;
    final multiplier = _selectedPeriodIndex == 2 ? 4.2 : 1.0;
    final weekSum = _days.fold<int>(0, (sum, d) => sum + d.sleepMinutes);
    return (weekSum * multiplier).round();
  }

  int get _activeOfflineProdMinutes {
    if (_selectedPeriodIndex == 0) return _currentDay.offlineProductiveMinutes;
    if (_days.isEmpty) return 0;
    final multiplier = _selectedPeriodIndex == 2 ? 4.2 : 1.0;
    final weekSum = _days.fold<int>(0, (sum, d) => sum + d.offlineProductiveMinutes);
    return (weekSum * multiplier).round();
  }

  int get _activeElapsedMinutes {
    if (_selectedPeriodIndex == 0) return _currentDay.elapsedDayMinutes;
    if (_days.isEmpty) return 1440;
    final multiplier = _selectedPeriodIndex == 2 ? 4.2 : 1.0;
    final weekSum = _days.fold<int>(0, (sum, d) => sum + d.elapsedDayMinutes);
    return (weekSum * multiplier).round();
  }

  List<AppUsage> get _activeTopDistractingApps {
    if (_selectedPeriodIndex == 0) return _currentDay.topDistractingApps;
    final map = <String, AppUsage>{};
    for (var d in _days) {
      for (var u in d.topDistractingApps) {
        if (!map.containsKey(u.packageName)) {
          map[u.packageName] = u;
        } else {
          final existing = map[u.packageName]!;
          map[u.packageName] = existing.copyWith(
            durationMinutes: existing.durationMinutes + u.durationMinutes,
            launchCount: existing.launchCount + u.launchCount,
          );
        }
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));
    return list;
  }

  Map<String, int> get _activeCategoryTotals {
    if (_selectedPeriodIndex == 0) return _currentDay.categoryTotals;
    final merged = <String, int>{};
    for (var d in _days) {
      d.categoryTotals.forEach((k, v) {
        merged[k] = (merged[k] ?? 0) + v;
      });
    }
    if (_selectedPeriodIndex == 2) {
      merged.updateAll((key, value) => (value * 4.2).round());
    }
    return merged;
  }

  List<AppUsage> get _activeUsages {
    if (_selectedPeriodIndex == 0) return _currentDay.usages;
    final map = <String, AppUsage>{};
    for (var d in _days) {
      for (var u in d.usages) {
        if (!map.containsKey(u.packageName)) {
          map[u.packageName] = u;
        } else {
          final existing = map[u.packageName]!;
          map[u.packageName] = existing.copyWith(
            durationMinutes: existing.durationMinutes + u.durationMinutes,
            launchCount: existing.launchCount + u.launchCount,
          );
        }
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));
    return list;
  }

  int get _averageScore {
    if (_days.isEmpty) return 0;
    final sum = _days.fold<int>(0, (prev, d) => prev + d.score);
    return (sum / _days.length).round();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentDay = _currentDay;
    final totalMins = _activeTotalMinutes;
    final prodMins = _activeProductiveMinutes;
    final distMins = _activeDistractingMinutes;
    final prodRatio = totalMins > 0 ? ((prodMins / totalMins) * 100).toInt() : 0;
    final catTotals = _activeCategoryTotals;
    final activeApps = _activeUsages;

    final totalNotesCount = _unifiedNotes.length;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      floatingActionButton: _analyticsMainTab == 1
          ? FloatingActionButton.extended(
              onPressed: () => _showAddOrEditNoteDialog(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.note_add_rounded),
              label: const Text('Add Note', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _analyticsMainTab == 0 ? 'Productivity Analytics' : 'All Notes & Journal',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _analyticsMainTab == 0
                            ? 'Interactive insights & habits deep-dive'
                            : 'Continuous chronological history with dates',
                        style: TextStyle(
                          color: AppColors.textSecondaryColor(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _analyticsMainTab = _analyticsMainTab == 0 ? 1 : 0),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _analyticsMainTab == 1
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _analyticsMainTab == 1 ? Icons.insights_rounded : Icons.notes_rounded,
                              size: 16,
                              color: _analyticsMainTab == 1 ? Colors.white : AppColors.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _analyticsMainTab == 1 ? 'Charts' : 'Notes ($totalNotesCount)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _analyticsMainTab == 1 ? Colors.white : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: _loadAllAnalytics,
                      icon: const Icon(Icons.refresh_rounded),
                      color: AppColors.primary,
                      tooltip: 'Refresh Analytics',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Top Segmented Switcher
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder(context)),
              ),
              child: Row(
                children: [
                  _analyticsMainTabButton('📊 Overview & Habits', 0),
                  _analyticsMainTabButton('📝 Notes Timeline ($totalNotesCount)', 1),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_analyticsMainTab == 0) ...[
              // Timeframe Selector: Today / This Week / This Month
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder(context)),
                ),
                child: Row(
                  children: [
                    _timePeriodButton('Day / Date', 0),
                    _timePeriodButton('This Week', 1),
                    _timePeriodButton('This Month', 2),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Interactive 7-Day Trend Chart
              _buildInteractive7DayChart(isDark),
              const SizedBox(height: 16),

              // Selected Day In-Depth Quick Banner (Clickable!)
              _buildSelectedDayQuickCard(currentDay, isDark),
              const SizedBox(height: 16),

              // Time Distribution Ratio Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.cardBorder(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Productive Ratio',
                                style: TextStyle(
                                  color: AppColors.textSecondaryColor(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$prodRatio%',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(prodMins),
                            style: TextStyle(
                              color: AppColors.textMutedColor(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.cardBorder(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Distractions',
                                style: TextStyle(
                                  color: AppColors.textSecondaryColor(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${totalMins > 0 ? 100 - prodRatio : 0}%',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.danger,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(distMins),
                            style: TextStyle(
                              color: AppColors.textMutedColor(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Daily Wasted Time Breakdown Section (Phone vs Other Idle)
              _buildWastedTimeBreakdownSection(currentDay, isDark),
              const SizedBox(height: 22),

              // Hint banner for user interaction
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tap any day bar, category, or app below to open full deep-dive analysis!',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.accentCyan : AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Category Breakdown Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Time Breakdown by Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                  Text(
                    '${catTotals.length} Categories',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMutedColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (catTotals.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder(context)),
                  ),
                  child: Center(
                    child: Text(
                      'No category usage recorded for this timeframe.',
                      style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13),
                    ),
                  ),
                )
              else
                ...catTotals.entries.map((entry) {
                  final cat = entry.key;
                  final minutes = entry.value;
                  final pct = totalMins > 0 ? (minutes / totalMins) : 0.0;
                  final appsInCat = activeApps.where((a) => a.category == cat).toList();

                  return _buildCategoryCard(
                    category: cat,
                    minutes: minutes,
                    percentage: pct,
                    appsInCategory: appsInCat,
                    totalTime: totalMins,
                  );
                }),

              const SizedBox(height: 24),

              // Top Apps & Screen Time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Top Apps & Digital Habits',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                  Text(
                    '${activeApps.length} Apps',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMutedColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (activeApps.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder(context)),
                  ),
                  child: Center(
                    child: Text(
                      'No app activities recorded for this date.',
                      style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13),
                    ),
                  ),
                )
              else
                ...activeApps.take(8).map((app) {
                  return _buildAppItemCard(app, totalMins);
                }),

              const SizedBox(height: 24),

              // Notes & Journal Stream Section in Overview
              _buildRecentNotesPreviewSection(isDark),
            ] else ...[
              // Full Notes & Journal Timeline Stream
              _buildAllNotesTimelineView(isDark),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _analyticsMainTabButton(String title, int index) {
    final isSelected = _analyticsMainTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _analyticsMainTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondaryColor(context),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentNotesPreviewSection(bool isDark) {
    final totalNotes = _unifiedNotes.length;
    final recentList = _unifiedNotes.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.notes_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Saved Notes & Journal Stream',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => _analyticsMainTab = 1),
              child: Text(
                'View All ($totalNotes) →',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (recentList.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder(context)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No notes recorded yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Capture day ideas, reflections, and insights here or from Time Planner.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showAddOrEditNoteDialog(),
                  child: const Text('Add Note', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              ...recentList.map((item) => _buildNoteCard(item, isDark)),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => setState(() => _analyticsMainTab = 1),
                  icon: const Icon(Icons.history_edu_rounded, size: 18),
                  label: Text(
                    'Browse All $totalNotes Notes & Reflections with Dates',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAllNotesTimelineView(bool isDark) {
    final filtered = _filteredNotes;
    final totalCount = _unifiedNotes.length;
    final pinnedCount = _unifiedNotes.where((n) => n.isPinned).length;

    final Map<String, List<UnifiedNoteItem>> grouped = {};
    for (final note in filtered) {
      grouped.putIfAbsent(note.date, () => []).add(note);
    }

    final categories = [
      'All',
      'Idea',
      'Note',
      'Important',
      'Reflection',
      'Todo',
      'Task Note',
      'Sleep',
      'Transport'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primaryDark,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history_edu_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalCount Notes Recorded',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pinnedCount > 0
                          ? '$pinnedCount pinned • Across all dates'
                          : 'Continuous chronological history with dates',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showAddOrEditNoteDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Search bar
        TextField(
          controller: _noteSearchController,
          onChanged: (val) => setState(() => _noteSearchQuery = val),
          style: TextStyle(color: AppColors.textPrimaryColor(context)),
          decoration: InputDecoration(
            hintText: 'Search notes by keyword, title, date...',
            hintStyle: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _noteSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _noteSearchController.clear();
                      setState(() => _noteSearchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.surface(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.cardBorder(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.cardBorder(context)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSel = _selectedNoteCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSel,
                  showCheckmark: false,
                  avatar: cat != 'All'
                      ? Icon(
                          _getNoteCategoryIcon(cat),
                          size: 15,
                          color: isSel ? Colors.white : _getNoteCategoryColor(cat, null),
                        )
                      : null,
                  label: Text(cat == 'All' ? 'All ($totalCount)' : cat),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? Colors.white : AppColors.textPrimaryColor(context),
                  ),
                  backgroundColor: AppColors.surface(context),
                  selectedColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSel ? AppColors.primary : AppColors.cardBorder(context),
                    ),
                  ),
                  onSelected: (_) => setState(() => _selectedNoteCategory = cat),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder(context)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMutedColor(context)),
                  const SizedBox(height: 12),
                  Text(
                    _noteSearchQuery.isNotEmpty
                        ? 'No notes matching "$_noteSearchQuery"'
                        : 'No notes in "$_selectedNoteCategory"',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try another keyword or category filter.',
                    style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13),
                  ),
                  if (_noteSearchQuery.isNotEmpty || _selectedNoteCategory != 'All') ...[
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: () {
                        _noteSearchController.clear();
                        setState(() {
                          _noteSearchQuery = '';
                          _selectedNoteCategory = 'All';
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset Filters'),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          ...grouped.entries.map((group) {
            final dateStr = group.key;
            final notesOnDate = group.value;
            final headerTitle = _formatNoteDateHeader(dateStr);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Banner Header
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder(context)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 15, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        headerTitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${notesOnDate.length}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...notesOnDate.map((note) => _buildNoteCard(note, isDark)),
                const SizedBox(height: 8),
              ],
            );
          }),
      ],
    );
  }

  Widget _buildNoteCard(UnifiedNoteItem note, bool isDark) {
    final catColor = _getNoteCategoryColor(note.category, note.colorHex);
    final catIcon = _getNoteCategoryIcon(note.category);
    final timeStr = _formatTimestamp(note.timestamp, note.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: note.isPinned ? Colors.amber.withValues(alpha: 0.6) : AppColors.cardBorder(context),
          width: note.isPinned ? 1.5 : 1,
        ),
        boxShadow: note.isPinned
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left color accent bar
              Container(width: 5, color: catColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Category badge, timestamp, pin status, popup menu
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(catIcon, size: 13, color: catColor),
                                const SizedBox(width: 4),
                                Text(
                                  note.category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: catColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (note.isPinned) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.push_pin_rounded, size: 11, color: Colors.amber),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Pinned',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.amber[200] : Colors.amber[900],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMutedColor(context),
                            ),
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert_rounded,
                              size: 18,
                              color: AppColors.textSecondaryColor(context),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (value) async {
                              if (value == 'copy') {
                                final text = '${note.title}\n\n${note.content}';
                                await Clipboard.setData(ClipboardData(text: text));
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('📋 Note copied to clipboard')),
                                  );
                                }
                              } else if (value == 'pin' && note.dailyNote?.id != null) {
                                await _togglePinDailyNote(note.dailyNote!.id!, note.isPinned);
                              } else if (value == 'edit' && note.dailyNote != null) {
                                _showAddOrEditNoteDialog(noteToEdit: note.dailyNote);
                              } else if (value == 'delete' && note.dailyNote?.id != null) {
                                await _deleteDailyNote(note.dailyNote!.id!);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'copy',
                                child: Row(
                                  children: [
                                    Icon(Icons.copy_rounded, size: 16),
                                    SizedBox(width: 8),
                                    Text('Copy Text'),
                                  ],
                                ),
                              ),
                              if (note.dailyNote != null) ...[
                                PopupMenuItem(
                                  value: 'pin',
                                  child: Row(
                                    children: [
                                      Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, size: 16),
                                      const SizedBox(width: 8),
                                      Text(note.isPinned ? 'Unpin' : 'Pin to Top'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, size: 16),
                                      SizedBox(width: 8),
                                      Text('Edit Note'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        note.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      if (note.content.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          note.content,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryColor(context),
                            height: 1.4,
                          ),
                        ),
                      ],

                      // If linked to a task block
                      if (note.timeBlock != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.cardBorder(context)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule_rounded, size: 13, color: AppColors.primary),
                              const SizedBox(width: 5),
                              Text(
                                '${note.timeBlock!.title} (${note.timeBlock!.durationMinutes}m)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondaryColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddOrEditNoteDialog({DailyNote? noteToEdit, String? defaultDate}) {
    final titleController = TextEditingController(text: noteToEdit?.title ?? '');
    final contentController = TextEditingController(text: noteToEdit?.content ?? '');
    String selectedDate = noteToEdit?.date ?? defaultDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    String selectedCategory = noteToEdit?.category ?? 'Idea';
    String? selectedColorHex = noteToEdit?.colorHex ?? '#6366F1';
    bool isPinned = noteToEdit?.isPinned ?? false;

    final categories = ['Idea', 'Note', 'Important', 'Reflection', 'Todo'];
    final colorOptions = ['#6366F1', '#EC4899', '#10B981', '#F59E0B', '#3B82F6', '#8B5CF6'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        noteToEdit == null ? 'Add Day Note & Idea' : 'Edit Note',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Date picker row
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Date: $selectedDate',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final parsed = DateTime.tryParse(selectedDate) ?? DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: parsed,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setSheetState(() {
                              selectedDate = DateFormat('yyyy-MM-dd').format(picked);
                            });
                          }
                        },
                        child: const Text('Change Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Category Selector chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: categories.map((cat) {
                      final isSel = selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSel,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: isSel ? Colors.white : AppColors.textPrimaryColor(context),
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => setSheetState(() => selectedCategory = cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // Title
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: AppColors.textPrimaryColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g., Focus insight, morning idea...',
                      filled: true,
                      fillColor: AppColors.surfaceVariant(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Content
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    minLines: 3,
                    style: TextStyle(color: AppColors.textPrimaryColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Content',
                      hintText: 'Enter your notes, ideas, or reflections...',
                      filled: true,
                      fillColor: AppColors.surfaceVariant(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Pin toggle and color picker row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: isPinned,
                            activeColor: AppColors.primary,
                            onChanged: (val) => setSheetState(() => isPinned = val ?? false),
                          ),
                          Text(
                            'Pin to top',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimaryColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: colorOptions.map((hex) {
                          final isSel = selectedColorHex == hex;
                          return GestureDetector(
                            onTap: () => setSheetState(() => selectedColorHex = hex),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _hexToColor(hex),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSel ? Colors.white : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

                        final db = DatabaseHelper.instance;
                        if (noteToEdit == null) {
                          final newNote = DailyNote(
                            date: selectedDate,
                            title: title.isEmpty ? 'Quick Note' : title,
                            content: content,
                            category: selectedCategory,
                            colorHex: selectedColorHex,
                            isPinned: isPinned,
                          );
                          await db.insertDailyNote(newNote);
                        } else {
                          final updated = noteToEdit.copyWith(
                            date: selectedDate,
                            title: title.isEmpty ? 'Quick Note' : title,
                            content: content,
                            category: selectedCategory,
                            colorHex: selectedColorHex,
                            isPinned: isPinned,
                            updatedAt: DateTime.now().millisecondsSinceEpoch,
                          );
                          await db.updateDailyNote(updated);
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadAllAnalytics();
                      },
                      child: Text(
                        noteToEdit == null ? 'Save Note' : 'Update Note',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteDailyNote(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('Are you sure you want to permanently delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteDailyNote(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Note deleted successfully')),
        );
        _loadAllAnalytics();
      }
    }
  }

  Future<void> _togglePinDailyNote(int id, bool currentPinned) async {
    await DatabaseHelper.instance.togglePinDailyNote(id, !currentPinned);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentPinned ? '📌 Note unpinned' : '📌 Note pinned to top'),
        ),
      );
      _loadAllAnalytics();
    }
  }

  // --------------------------------------------------------------------------
  // Interactive 7-Day Chart
  // --------------------------------------------------------------------------
  Widget _buildInteractive7DayChart(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '7-Day Score Trend',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap any day bar to inspect detailed data',
                    style: TextStyle(
                      color: AppColors.textMutedColor(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '7D Avg: $_averageScore/100',
                  style: TextStyle(
                    color: isDark ? AppColors.accentCyan : AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_days.length, (index) {
              final day = _days[index];
              final isSelected = index == _selectedDayIndex;
              final score = day.score;
              final height = (score / 100 * 105).clamp(18.0, 105.0);

              Color barColor;
              if (isSelected) {
                barColor = isDark ? AppColors.accentCyan : AppColors.primary;
              } else if (score >= 75) {
                barColor = AppColors.success.withValues(alpha: 0.85);
              } else if (score >= 50) {
                barColor = AppColors.primary.withValues(alpha: 0.65);
              } else {
                barColor = AppColors.danger.withValues(alpha: 0.65);
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDayIndex = index;
                    _selectedPeriodIndex = 0; // Switch to Day view
                  });
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$score',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: isSelected ? 26 : 20,
                      height: height,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(7),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: barColor.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      index == _days.length - 1 ? 'Today' : day.dayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? (isDark ? AppColors.accentCyan : AppColors.primary)
                            : AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Selected Day Quick Analysis Card (Clickable to open Full Sheet)
  // --------------------------------------------------------------------------
  Widget _buildSelectedDayQuickCard(DayAnalyticsData day, bool isDark) {
    final grade = _getScoreGrade(day.score);
    final isToday = day.dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now());

    return InkWell(
      onTap: () => _showDayDeepDiveSheet(day),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isToday ? 'Today (${day.shortDate})' : '${day.dayName}, ${day.shortDate}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              grade,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total: ${_formatTime(day.totalMinutes)} • Prod: ${_formatTime(day.productiveMinutes)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${day.score}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      day.scoreResult.advice,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryColor(context),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Analyze 🔍',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Wasted Time Breakdown Section (Phone vs Other/Offline Idle)
  // --------------------------------------------------------------------------
  Widget _buildWastedTimeBreakdownSection(DayAnalyticsData currentDay, bool isDark) {
    // Gather metrics based on active period
    final phoneWaste = _activePhoneWastedMinutes;
    final otherWaste = _activeOtherWastedMinutes;
    final totalWaste = _activeTotalWastedMinutes;
    final sleepMins = _activeSleepMinutes;
    final offlineProd = _activeOfflineProdMinutes;
    final phoneProd = _activeProductiveMinutes;
    final totalProd = offlineProd + phoneProd;
    final elapsedMins = _activeElapsedMinutes > 0 ? _activeElapsedMinutes : 1440;
    final topApps = _activeTopDistractingApps;

    final wastePct = ((totalWaste / elapsedMins) * 100).clamp(0, 100).round();
    final phonePctOfWaste = totalWaste > 0 ? ((phoneWaste / totalWaste) * 100).round() : 0;
    final otherPctOfWaste = totalWaste > 0 ? ((otherWaste / totalWaste) * 100).round() : 0;

    // Severity indicator
    String severityLabel;
    Color severityColor;
    if (totalWaste <= 90) {
      severityLabel = 'Minimal Waste';
      severityColor = AppColors.success;
    } else if (totalWaste <= 240) {
      severityLabel = 'Moderate Waste';
      severityColor = AppColors.warning;
    } else {
      severityLabel = 'High Time Waste';
      severityColor = AppColors.danger;
    }

    // Dynamic advice
    String smartAdviceTitle;
    String smartAdviceBody;
    IconData smartAdviceIcon;
    Color smartAdviceColor;

    if (totalWaste <= 60) {
      smartAdviceTitle = 'Great Discipline!';
      smartAdviceBody = 'Your wasted time today is kept at a minimum. Excellent focus and control!';
      smartAdviceIcon = Icons.check_circle_rounded;
      smartAdviceColor = AppColors.success;
    } else if (phoneWaste >= otherWaste) {
      final topAppName = topApps.isNotEmpty ? topApps.first.appName : 'Social Apps';
      smartAdviceTitle = 'High Phone Distraction';
      smartAdviceBody = 'Most wasted time was spent on $topAppName and distracting apps ($phoneWaste m). Consider setting app limits or turning on Focus Mode.';
      smartAdviceIcon = Icons.phone_android_rounded;
      smartAdviceColor = AppColors.danger;
    } else {
      smartAdviceTitle = 'High Offline Idle Time';
      smartAdviceBody = 'A significant amount of off-screen idle time was detected ($otherWaste m). Scheduling quick time blocks in the Planner can keep you on track.';
      smartAdviceIcon = Icons.timelapse_rounded;
      smartAdviceColor = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (totalWaste > 240 ? AppColors.danger : AppColors.warning).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (totalWaste > 240 ? AppColors.danger : AppColors.warning).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: (totalWaste > 240 ? AppColors.danger : AppColors.warning).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_bottom_rounded,
                  size: 20,
                  color: totalWaste > 240 ? AppColors.danger : AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Loss Breakdown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    Text(
                      'Phone screen vs offline idle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: severityColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  severityLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: severityColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Wasted Big Highlight Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2C1E20), const Color(0xFF1E1E28)]
                    : [const Color(0xFFFFF0F0), const Color(0xFFFFF8E7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (totalWaste > 240 ? AppColors.danger : AppColors.warning).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Wasted Today',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(totalWaste),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: totalWaste > 240 ? AppColors.danger : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 38,
                  width: 1,
                  color: AppColors.cardBorder(context),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Day Loss Ratio',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$wastePct%',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Two Pillars: Phone Waste vs Other/Offline Waste
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pillar 1: Phone Waste (Screen)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: isDark ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.phone_android_rounded, size: 16, color: AppColors.danger),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Phone Waste',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.danger,
                                  ),
                                ),
                                Text(
                                  'Screen ($phonePctOfWaste%)',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textSecondaryColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formatTime(phoneWaste),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Distracting apps & feeds',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Top 3 Distracting Phone Apps
                      if (topApps.isNotEmpty) ...[
                        Text(
                          'Top Distractions:',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...topApps.take(3).map((app) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  AppIconWidget(
                                    packageName: app.packageName,
                                    appName: app.appName,
                                    initialIcon: app.appIcon,
                                    size: 18,
                                    borderRadius: 4,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      app.appName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimaryColor(context),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatTime(app.durationMinutes),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ] else ...[
                        Text(
                          'No distracting apps! 🎉',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textMutedColor(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Pillar 2: Other / Offline Waste (Off-screen)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: isDark ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.timelapse_rounded, size: 16, color: AppColors.warning),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Other Waste',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.warning,
                                  ),
                                ),
                                Text(
                                  'Offline ($otherPctOfWaste%)',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textSecondaryColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formatTime(otherWaste),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Off-screen idle & untracked',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Off-screen math breakdown
                      Text(
                        'Calculation Context:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildMiniInfoRow(
                        'Active Day:',
                        _formatTime(elapsedMins),
                        AppColors.textSecondaryColor(context),
                      ),
                      _buildMiniInfoRow(
                        'Sleep & Rest:',
                        _formatTime(sleepMins),
                        const Color(0xFF6C5CE7),
                      ),
                      _buildMiniInfoRow(
                        'Productive Work:',
                        _formatTime(totalProd),
                        AppColors.success,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 24-Hour Day Balance Multi-Segment Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Day Time Allocation',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              Text(
                _formatTime(elapsedMins),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMutedColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Multi-Segment Rounded Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 12,
              color: AppColors.surfaceVariant(context),
              child: Row(
                children: [
                  if (totalProd > 0)
                    Flexible(
                      flex: totalProd,
                      child: Container(
                        color: AppColors.success,
                      ),
                    ),
                  if (sleepMins > 0)
                    Flexible(
                      flex: sleepMins,
                      child: Container(
                        color: const Color(0xFF6C5CE7),
                      ),
                    ),
                  if (phoneWaste > 0)
                    Flexible(
                      flex: phoneWaste,
                      child: Container(
                        color: AppColors.danger,
                      ),
                    ),
                  if (otherWaste > 0)
                    Flexible(
                      flex: otherWaste,
                      child: Container(
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 4-Item Legend Grid
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildBarLegendItem(AppColors.success, 'Productive: ${_formatTime(totalProd)}'),
              _buildBarLegendItem(const Color(0xFF6C5CE7), 'Sleep: ${_formatTime(sleepMins)}'),
              _buildBarLegendItem(AppColors.danger, 'Phone Waste: ${_formatTime(phoneWaste)}'),
              _buildBarLegendItem(AppColors.warning, 'Other Waste: ${_formatTime(otherWaste)}'),
            ],
          ),
          const SizedBox(height: 16),

          // Smart Sinhala Advice Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: smartAdviceColor.withValues(alpha: isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: smartAdviceColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(smartAdviceIcon, size: 20, color: smartAdviceColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        smartAdviceTitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: smartAdviceColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        smartAdviceBody,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfoRow(String label, String value, Color valColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarLegendItem(Color dotColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondaryColor(context),
          ),
        ),
      ],
    );
  }
  Widget _buildCategoryCard({
    required String category,
    required int minutes,
    required double percentage,
    required List<AppUsage> appsInCategory,
    required int totalTime,
  }) {
    final isProd = AppCategoryManager.isProductive(category);
    final isDist = AppCategoryManager.isDistracting(category);
    final catColor = isProd ? AppColors.success : (isDist ? AppColors.danger : AppColors.primary);

    return InkWell(
      onTap: () => _showCategoryDeepDiveSheet(
        category: category,
        minutes: minutes,
        appsInCategory: appsInCategory,
        totalTime: totalTime,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder(context)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryColor(context),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '${_formatTime(minutes)} (${(percentage * 100).toInt()}%)',
                      style: TextStyle(
                        color: AppColors.textSecondaryColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textMutedColor(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage.clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceVariant(context),
                valueColor: AlwaysStoppedAnimation<Color>(catColor),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // App Item Card (Clickable to open App Sheet)
  // --------------------------------------------------------------------------
  Widget _buildAppItemCard(AppUsage app, int totalMinutes) {
    final pct = totalMinutes > 0 ? (app.durationMinutes / totalMinutes) : 0.0;
    final isProd = AppCategoryManager.isProductive(app.category);
    final isDist = AppCategoryManager.isDistracting(app.category);

    return InkWell(
      onTap: () => _showAppDeepDiveSheet(app, totalMinutes),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder(context)),
        ),
        child: Row(
          children: [
            AppIconWidget(
              packageName: app.packageName,
              appName: app.appName,
              initialIcon: app.appIcon,
              size: 42,
              borderRadius: 12,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          app.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isProd ? AppColors.success : (isDist ? AppColors.danger : AppColors.primary))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          app.category,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isProd ? AppColors.success : (isDist ? AppColors.danger : AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_formatTime(app.durationMinutes)} (${(pct * 100).toInt()}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                      Text(
                        '${app.launchCount} opens',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      backgroundColor: AppColors.surfaceVariant(context),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isProd ? AppColors.success : (isDist ? AppColors.danger : AppColors.primary),
                      ),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMutedColor(context), size: 18),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Deep-Dive Modal: Specific Date / Day Analysis
  // --------------------------------------------------------------------------
  void _showDayDeepDiveSheet(DayAnalyticsData day) {
    final grade = _getScoreGrade(day.score);
    final prodPct = day.totalMinutes > 0 ? (day.productiveMinutes / day.totalMinutes * 100).toInt() : 0;
    final distPct = day.totalMinutes > 0 ? (day.distractingMinutes / day.totalMinutes * 100).toInt() : 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
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

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Day Analysis Report',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      Text(
                        '${day.dayName}, ${day.shortDate} (${day.dateStr})',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textSecondaryColor(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Big Score Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.score}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              grade,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            day.score >= 75
                                ? 'High Productivity Day! Keep this momentum up.'
                                : day.score >= 50
                                    ? 'Moderate Productivity. Distractions can be reduced.'
                                    : 'Focus Challenged. Review app limits and schedule.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // AI Smart Diagnosis
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder(context)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_rounded, color: AppColors.warning, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Focus Analysis & Advice',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            day.scoreResult.advice,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryColor(context),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 4 Key Metric Pillars Grid
              Text(
                'Key Metrics Breakdown',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _metricPillar(
                    title: 'Total Screen Time',
                    value: _formatTime(day.totalMinutes),
                    subtitle: '${day.usages.length} Apps active',
                    icon: Icons.timer_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  _metricPillar(
                    title: 'Productive Work',
                    value: _formatTime(day.productiveMinutes),
                    subtitle: '$prodPct% of day',
                    icon: Icons.task_alt_rounded,
                    color: AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _metricPillar(
                    title: 'Distractions',
                    value: _formatTime(day.distractingMinutes),
                    subtitle: '$distPct% of day',
                    icon: Icons.videogame_asset_rounded,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 10),
                  _metricPillar(
                    title: 'Score Points',
                    value: '${day.score}/100',
                    subtitle: 'Productivity Index',
                    icon: Icons.speed_rounded,
                    color: AppColors.accentCyan,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Day's Time Loss & Wasted Breakdown Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: (day.totalWastedMinutes > 240 ? AppColors.danger : AppColors.warning)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.hourglass_bottom_rounded,
                          size: 18,
                          color: day.totalWastedMinutes > 240 ? AppColors.danger : AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Wasted Time Breakdown',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryColor(context),
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(day.totalWastedMinutes),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: day.totalWastedMinutes > 240 ? AppColors.danger : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.phone_android_rounded, size: 14, color: AppColors.danger),
                                    SizedBox(width: 4),
                                    Text(
                                      'Phone Waste',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(day.phoneWastedMinutes),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.danger,
                                  ),
                                ),
                                Text(
                                  'Social & Games',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textMutedColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.timelapse_rounded, size: 14, color: AppColors.warning),
                                    SizedBox(width: 4),
                                    Text(
                                      'Other Waste',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(day.otherWastedMinutes),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.warning,
                                  ),
                                ),
                                Text(
                                  'Offline idle / untracked',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textMutedColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (day.topDistractingApps.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Top Phone Distractions on this date:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: day.topDistractingApps.take(3).map((app) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.cardBorder(context)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppIconWidget(
                                packageName: app.packageName,
                                appName: app.appName,
                                initialIcon: app.appIcon,
                                size: 14,
                                borderRadius: 3,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                app.appName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimaryColor(context),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatTime(app.durationMinutes),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Score Breakdown Factors
              Text(
                'Score Calculation Points',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _scorePointRow('🎯 Goal Completion Points', '${day.scoreResult.goalPoints} / 30 pts'),
                    const Divider(height: 16),
                    _scorePointRow('🚀 Productive Ratio Points', '${day.scoreResult.productiveRatioPoints} / 25 pts'),
                    const Divider(height: 16),
                    _scorePointRow('⏱️ Focus Sessions Points', '${day.scoreResult.focusPoints} / 20 pts'),
                    const Divider(height: 16),
                    _scorePointRow('🛡️ Distraction Control Points', '${day.scoreResult.distractionControlPoints} / 15 pts'),
                    const Divider(height: 16),
                    _scorePointRow('🔥 Consistency & Habits Points', '${day.scoreResult.consistencyPoints} / 10 pts'),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Day's Notes & Ideas Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notes & Ideas on this Day',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${day.notes.length} Recorded',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (day.notes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'No notes or ideas captured on this day.',
                    style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 12),
                  ),
                )
              else
                ...day.notes.map((note) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder(context)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        note.category,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        note.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.textPrimaryColor(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (note.content.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    note.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondaryColor(context),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              const SizedBox(height: 18),

              // Day's Top Apps
              Text(
                'Top Apps Used on this Date',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 8),
              if (day.usages.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'No app activities recorded for this date.',
                    style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 12),
                  ),
                )
              else
                ...day.usages.take(6).map((app) => _buildAppItemCard(app, day.totalMinutes)),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Deep-Dive Modal: Category Analysis
  // --------------------------------------------------------------------------
  void _showCategoryDeepDiveSheet({
    required String category,
    required int minutes,
    required List<AppUsage> appsInCategory,
    required int totalTime,
  }) {
    final isProd = AppCategoryManager.isProductive(category);
    final isDist = AppCategoryManager.isDistracting(category);
    final catColor = isProd ? AppColors.success : (isDist ? AppColors.danger : AppColors.primary);
    final pct = totalTime > 0 ? (minutes / totalTime * 100).toInt() : 0;
    final budget = _budgetsMap[category];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (ctx, scrollController) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isProd
                              ? Icons.work_rounded
                              : (isDist ? Icons.sports_esports_rounded : Icons.category_rounded),
                          color: catColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryColor(context),
                            ),
                          ),
                          Text(
                            isProd
                                ? 'Productive Category 🚀'
                                : (isDist ? 'Distracting Category ⚠️' : 'Neutral Activity'),
                            style: TextStyle(
                              fontSize: 12,
                              color: catColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Time Stat Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Total Spent', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(minutes),
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: catColor),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 35, color: AppColors.cardBorder(context)),
                    Column(
                      children: [
                        Text('% of Total Screen', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 35, color: AppColors.cardBorder(context)),
                    Column(
                      children: [
                        Text('Apps Count', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          '${appsInCategory.length}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Budget Status
              Text(
                'Budget & Limits',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder(context)),
                ),
                child: budget != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Daily Budget: ${budget.limitMinutes} min',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryColor(context),
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                minutes > budget.limitMinutes
                                    ? 'Exceeded by ${minutes - budget.limitMinutes}m 🚨'
                                    : 'Remaining: ${budget.limitMinutes - minutes}m ✅',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: minutes > budget.limitMinutes ? AppColors.danger : AppColors.success,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (minutes / budget.limitMinutes).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                minutes > budget.limitMinutes ? AppColors.danger : AppColors.success,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No daily limit budget set for this category.',
                              style: TextStyle(
                                color: AppColors.textSecondaryColor(context),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 18),

              // Apps in this category
              Text(
                'Apps in $category (${appsInCategory.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 8),
              if (appsInCategory.isEmpty)
                Text(
                  'No apps recorded in this category.',
                  style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 12),
                )
              else
                ...appsInCategory.map((app) => _buildAppItemCard(app, totalTime)),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Deep-Dive Modal: Specific App Analysis
  // --------------------------------------------------------------------------
  void _showAppDeepDiveSheet(AppUsage app, int totalMinutes) {
    final isProd = AppCategoryManager.isProductive(app.category);
    final isDist = AppCategoryManager.isDistracting(app.category);
    final appColor = isProd ? AppColors.success : (isDist ? AppColors.danger : AppColors.primary);
    final pct = totalMinutes > 0 ? (app.durationMinutes / totalMinutes * 100).toInt() : 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Row(
              children: [
                AppIconWidget(
                  packageName: app.packageName,
                  appName: app.appName,
                  initialIcon: app.appIcon,
                  size: 50,
                  borderRadius: 14,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.appName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: appColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    app.category,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: appColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Statistics Row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Usage Time', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(app.durationMinutes),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: appColor),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 35, color: AppColors.cardBorder(context)),
                  Column(
                    children: [
                      Text('Opens Count', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        '${app.launchCount} times',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 35, color: AppColors.cardBorder(context)),
                  Column(
                    children: [
                      Text('Screen Share', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Behavioral Diagnosis
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder(context)),
              ),
              child: Row(
                children: [
                  Icon(
                    isProd ? Icons.check_circle_rounded : (isDist ? Icons.warning_amber_rounded : Icons.info_rounded),
                    color: appColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isDist
                          ? (app.durationMinutes > 40
                              ? 'High distraction risk! Spending over 40 mins on this app hurts your productivity score.'
                              : 'Distraction app under control. Keep usage below your limits.')
                          : isProd
                              ? 'Great work tool! Spending focused time here contributes positively to your productivity score.'
                              : 'Standard utility app. Balanced usage detected.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Dismiss Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Close Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Helper Widgets & Calculators
  // --------------------------------------------------------------------------
  Widget _metricPillar({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondaryColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMutedColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scorePointRow(String title, String pts) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
        Text(
          pts,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  String _getScoreGrade(int score) {
    if (score >= 90) return 'Grade A+ • Exceptional';
    if (score >= 80) return 'Grade A • Highly Productive';
    if (score >= 70) return 'Grade B • Good Focus';
    if (score >= 50) return 'Grade C • Balanced';
    return 'Grade D • Needs Focus';
  }

  Widget _timePeriodButton(String title, int index) {
    final isSelected = _selectedPeriodIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriodIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondaryColor(context),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
