import 'package:flutter/material.dart';
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

  List<DayAnalyticsData> _days = [];
  Map<String, TimeBudget> _budgetsMap = {};

  @override
  void initState() {
    super.initState();
    _loadAllAnalytics();
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
        ),
      );
    }

    if (mounted) {
      setState(() {
        _days = loadedDays;
        _budgetsMap = bMap;
        _selectedDayIndex = loadedDays.isNotEmpty ? loadedDays.length - 1 : 0;
        _isLoading = false;
      });
    }
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

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Productivity Analytics',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryColor(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Interactive insights & data deep-dive',
                      style: TextStyle(
                        color: AppColors.textSecondaryColor(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _loadAllAnalytics,
                  icon: const Icon(Icons.refresh_rounded),
                  color: AppColors.primary,
                  tooltip: 'Refresh Analytics',
                ),
              ],
            ),
            const SizedBox(height: 16),

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

            // Category Breakdown Section (Interactive!)
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

            // Top Apps & Screen Time (Interactive!)
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

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
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
  // Category Card (Clickable to open Category Sheet)
  // --------------------------------------------------------------------------
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
