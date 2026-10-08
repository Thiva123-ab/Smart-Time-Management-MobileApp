import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../data/models/app_usage.dart';
import '../data/models/daily_score.dart';
import '../domain/app_category_manager.dart';
import '../services/usage_tracking_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedPeriodIndex = 0; // 0: Today, 1: Weekly, 2: Monthly
  List<AppUsage> _usages = [];
  Map<String, int> _categoryTotals = {};
  int _totalMinutes = 0;
  int _productiveMinutes = 0;
  int _distractingMinutes = 0;
  bool _isLoading = true;

  // Mock 7-day trend scores for visual bar chart
  final List<Map<String, dynamic>> _weekScores = [
    {'day': 'Mon', 'score': 68},
    {'day': 'Tue', 'score': 74},
    {'day': 'Wed', 'score': 82},
    {'day': 'Thu', 'score': 79},
    {'day': 'Fri', 'score': 88},
    {'day': 'Sat', 'score': 65},
    {'day': 'Sun', 'score': 78},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final apps = await UsageTrackingService.fetchTodayUsage();

    final catMap = <String, int>{};
    int total = 0;
    int prod = 0;
    int dist = 0;

    for (var a in apps) {
      total += a.durationMinutes;
      catMap[a.category] = (catMap[a.category] ?? 0) + a.durationMinutes;
      if (AppCategoryManager.isProductive(a.category)) {
        prod += a.durationMinutes;
      } else if (AppCategoryManager.isDistracting(a.category)) {
        dist += a.durationMinutes;
      }
    }

    setState(() {
      _usages = apps;
      _categoryTotals = catMap;
      _totalMinutes = total;
      _productiveMinutes = prod;
      _distractingMinutes = dist;
      _isLoading = false;
    });
  }

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prodRatio = _totalMinutes > 0 ? (_productiveMinutes / _totalMinutes * 100).toInt() : 0;
    final avgScore = (_weekScores.map((e) => e['score'] as int).reduce((a, b) => a + b) / _weekScores.length).round();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Header
            Text(
              'Productivity Analytics',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context)),
            ),
            const SizedBox(height: 4),
            Text(
              'Comprehensive trends and habit insights',
              style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Timeframe Selector
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder(context)),
              ),
              child: Row(
                children: [
                  _timePeriodButton('Today', 0),
                  _timePeriodButton('This Week', 1),
                  _timePeriodButton('This Month', 2),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Weekly Score Trend Chart
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '7-Day Score Trend',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Avg: $avgScore/100',
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
                    children: _weekScores.map((item) {
                      final score = item['score'] as int;
                      final height = (score / 100 * 110).clamp(15.0, 110.0);
                      final isToday = item['day'] == 'Wed'; // or active day

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$score',
                            style: TextStyle(
                              fontSize: 10,
                              color: isToday
                                  ? (isDark ? AppColors.accentCyan : AppColors.primary)
                                  : AppColors.textMutedColor(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 22,
                            height: height,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? (isDark ? AppColors.accentCyan : AppColors.primary)
                                  : (score >= 75 ? AppColors.primary : AppColors.surfaceVariant(context)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item['day'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday
                                  ? (isDark ? AppColors.accentCyan : AppColors.primary)
                                  : AppColors.textSecondaryColor(context),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Time Distribution Highlights
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Productive Ratio', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12)),
                        const SizedBox(height: 6),
                        Text('$prodRatio%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.success)),
                        const SizedBox(height: 4),
                        Text(_formatTime(_productiveMinutes), style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 11)),
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
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Distractions', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12)),
                        const SizedBox(height: 6),
                        Text('${100 - prodRatio}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.danger)),
                        const SizedBox(height: 4),
                        Text(_formatTime(_distractingMinutes), style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Category Breakdown
            Text(
              'Time Breakdown by Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context)),
            ),
            const SizedBox(height: 12),
            ..._categoryTotals.entries.map((entry) {
              final cat = entry.key;
              final minutes = entry.value;
              final pct = _totalMinutes > 0 ? (minutes / _totalMinutes) : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                              decoration: BoxDecoration(
                                color: AppCategoryManager.isProductive(cat)
                                    ? AppColors.success
                                    : AppCategoryManager.isDistracting(cat)
                                        ? AppColors.danger
                                        : AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(cat, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context), fontSize: 14)),
                          ],
                        ),
                        Text(
                          '${_formatTime(minutes)} (${(pct * 100).toInt()}%)',
                          style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: AppColors.surfaceVariant(context),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppCategoryManager.isProductive(cat)
                              ? AppColors.success
                              : AppCategoryManager.isDistracting(cat)
                                  ? AppColors.danger
                                  : AppColors.primary,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
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
