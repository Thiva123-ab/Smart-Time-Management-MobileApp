import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/local/database_helper.dart';
import '../data/models/daily_habit_activity.dart';
import '../theme/app_theme.dart';

class HabitHeatmapWidget extends StatefulWidget {
  final bool isCompact;
  final VoidCallback? onExpandedView;

  const HabitHeatmapWidget({
    super.key,
    this.isCompact = false,
    this.onExpandedView,
  });

  @override
  State<HabitHeatmapWidget> createState() => _HabitHeatmapWidgetState();
}

class _HabitHeatmapWidgetState extends State<HabitHeatmapWidget> {
  int _selectedDaysCount = 35; // 5 full weeks for clean grid
  bool _isLoading = true;
  HabitHeatmapStats? _stats;
  String? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadHeatmapData();
  }

  Future<void> _loadHeatmapData() async {
    setState(() => _isLoading = true);
    final days = widget.isCompact ? 28 : _selectedDaysCount;
    final stats = await DatabaseHelper.instance.getHabitHeatmapStats(daysCount: days);
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  Color _getCellColor(int level, bool isDark) {
    switch (level) {
      case 4:
        return const Color(0xFF00CEC9); // Electric Cyan
      case 3:
        return const Color(0xFF6C5CE7); // Deep Vivid Purple
      case 2:
        return const Color(0xFF6C5CE7).withValues(alpha: 0.65);
      case 1:
        return const Color(0xFF6C5CE7).withValues(alpha: 0.32);
      case 0:
      default:
        return isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.05);
    }
  }

  void _showDayDetails(BuildContext context, DailyHabitActivity activity) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime? dt;
    try {
      dt = DateTime.parse(activity.date);
    } catch (_) {}
    final formattedDate = dt != null ? DateFormat('EEEE, MMMM d, yyyy').format(dt) : activity.date;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1B38) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.cardBorder(ctx)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMutedColor(ctx).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryColor(ctx),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activity.hasActivity ? 'Productive Day Logged' : 'No recorded deep focus',
                          style: TextStyle(
                            fontSize: 12,
                            color: activity.hasActivity ? AppColors.accentCyan : AppColors.textMutedColor(ctx),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getCellColor(activity.intensityLevel, isDark).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getCellColor(activity.intensityLevel, isDark)),
                    ),
                    child: Text(
                      'Level ${activity.intensityLevel}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: activity.intensityLevel == 0
                            ? AppColors.textSecondaryColor(ctx)
                            : _getCellColor(activity.intensityLevel, isDark),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _metricTile(
                    ctx,
                    'Focus Time',
                    '${activity.focusMinutes}m',
                    Icons.timelapse_rounded,
                    AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  _metricTile(
                    ctx,
                    'Tasks Done',
                    '${activity.completedTasks}',
                    Icons.check_circle_outline_rounded,
                    AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _metricTile(
                    ctx,
                    'Daily Score',
                    activity.productivityScore > 0 ? '${activity.productivityScore}/100' : 'N/A',
                    Icons.bolt_rounded,
                    AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  _metricTile(
                    ctx,
                    'Goals Crushed',
                    '${activity.completedGoals}',
                    Icons.flag_rounded,
                    AppColors.accentCyan,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricTile(BuildContext ctx, String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant(ctx),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder(ctx)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondaryColor(ctx)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryColor(ctx),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Container(
        height: widget.isCompact ? 140 : 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder(context)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
        ),
      );
    }

    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Generate weeks matrix: columns of 7 days
    final List<List<DailyHabitActivity>> weeks = [];
    final allDays = stats.activityMap.values.toList();

    // Group into columns of 7 days (or day of week aligned)
    for (int i = 0; i < allDays.length; i += 7) {
      final chunkEnd = (i + 7 < allDays.length) ? i + 7 : allDays.length;
      weeks.add(allDays.sublist(i, chunkEnd));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder(context)),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.grid_view_rounded, size: 15, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isCompact ? 'Habit Consistency' : '30-Day Activity Heatmap',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryColor(context),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${stats.activeDaysCount} active days • ${stats.activityRate.toInt()}% consistency',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.isCompact) ...[
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDaysCount = _selectedDaysCount == 35 ? 70 : 35;
                        });
                        _loadHeatmapData();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.cardBorder(context)),
                        ),
                        child: Text(
                          _selectedDaysCount == 35 ? '5 Weeks' : '10 Weeks',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Current Streak Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: stats.currentStreak > 0
                          ? Colors.orange.withValues(alpha: 0.15)
                          : AppColors.surfaceVariant(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: stats.currentStreak > 0
                            ? Colors.orange.withValues(alpha: 0.4)
                            : AppColors.cardBorder(context),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 13,
                          color: stats.currentStreak > 0 ? Colors.orange : AppColors.textMutedColor(context),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${stats.currentStreak} Day${stats.currentStreak == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: stats.currentStreak > 0 ? Colors.orange : AppColors.textMutedColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Heatmap Grid
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day Labels (Mon, Wed, Fri)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _dayLabel('M', context),
                      const SizedBox(height: 18),
                      _dayLabel('W', context),
                      const SizedBox(height: 18),
                      _dayLabel('F', context),
                    ],
                  ),
                ),
                // Matrix Columns
                ...weeks.map((col) {
                  return Column(
                    children: col.map((activity) {
                      final isToday = activity.date == todayStr;
                      final isSelected = _selectedDate == activity.date;
                      final color = _getCellColor(activity.intensityLevel, isDark);

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedDate = activity.date);
                          _showDayDetails(context, activity);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.all(2.5),
                          width: widget.isCompact ? 16 : 18,
                          height: widget.isCompact ? 16 : 18,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : (isToday ? AppColors.accentCyan : Colors.transparent),
                              width: (isSelected || isToday) ? 1.5 : 0.5,
                            ),
                            boxShadow: activity.intensityLevel == 4
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00CEC9).withValues(alpha: 0.5),
                                      blurRadius: 4,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Footer Row: Legend & Quick Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // GitHub style color legend
              Row(
                children: [
                  Text(
                    'Less',
                    style: TextStyle(fontSize: 10, color: AppColors.textMutedColor(context)),
                  ),
                  const SizedBox(width: 4),
                  ...List.generate(5, (level) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: _getCellColor(level, isDark),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                  const SizedBox(width: 4),
                  Text(
                    'More',
                    style: TextStyle(fontSize: 10, color: AppColors.textMutedColor(context)),
                  ),
                ],
              ),

              // Longest streak or Total hours
              Row(
                children: [
                  const Icon(Icons.military_tech_rounded, size: 14, color: AppColors.warning),
                  const SizedBox(width: 3),
                  Text(
                    'Best: ${stats.longestStreak}d',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '•  ${(stats.totalFocusMinutes / 60).toStringAsFixed(1)}h focus',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentCyan,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayLabel(String text, BuildContext ctx) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textMutedColor(ctx),
      ),
    );
  }
}
