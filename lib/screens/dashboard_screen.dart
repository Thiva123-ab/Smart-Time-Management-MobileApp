import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../data/models/app_usage.dart';
import '../data/models/goal.dart';
import '../data/models/time_block.dart';
import '../domain/app_category_manager.dart';
import '../domain/productivity_score_engine.dart';
import '../services/usage_tracking_service.dart';
import '../data/models/user_profile.dart';
import 'time_planner_screen.dart';
import 'focus_screen.dart';
import 'profile_screen.dart';
import '../widgets/app_icon_widget.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onStartFocus;
  final VoidCallback onViewGoals;

  const DashboardScreen({
    super.key,
    required this.onStartFocus,
    required this.onViewGoals,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<AppUsage> _apps = [];
  List<Goal> _goals = [];
  List<TimeBlock> _todayBlocks = [];
  UserProfile? _userProfile;
  ScoreResult _score = ProductivityScoreEngine.calculateScore(
    goalCompletionPercentage: 80,
    productiveMinutes: 240,
    distractingMinutes: 85,
    focusMinutes: 90,
  );
  int _totalMinutes = 325;
  int _productiveMinutes = 240;
  int _distractingMinutes = 85;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final today = UsageTrackingService.todayDate;

    final usages = await UsageTrackingService.fetchTodayUsage();
    await db.saveAppUsageList(usages);
    final goals = await db.getGoalsForDate(today);

    int total = 0;
    int prod = 0;
    int dist = 0;

    for (var u in usages) {
      total += u.durationMinutes;
      if (AppCategoryManager.isProductive(u.category)) {
        prod += u.durationMinutes;
      } else if (AppCategoryManager.isDistracting(u.category)) {
        dist += u.durationMinutes;
      }
    }

    final completedGoals = goals.where((g) => g.status == 'COMPLETED').length;
    final goalPercent = goals.isNotEmpty ? (completedGoals * 100) ~/ goals.length : 80;

    final todayBlocks = await db.getTimeBlocksForDate(today);
    final userProfile = await UserProfile.load();

    final scoreRes = ProductivityScoreEngine.calculateScore(
      goalCompletionPercentage: goalPercent,
      productiveMinutes: prod,
      distractingMinutes: dist,
      focusMinutes: 60,
    );

    setState(() {
      _apps = usages;
      _goals = goals;
      _todayBlocks = todayBlocks;
      _userProfile = userProfile;
      _totalMinutes = total;
      _productiveMinutes = prod;
      _distractingMinutes = dist;
      _score = scoreRes;
      _isLoading = false;
    });
  }

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    final firstName = _userProfile?.name.trim().split(' ').first ?? '';
    final nameStr = firstName.isNotEmpty ? ', $firstName' : '';
    if (hour < 12) return 'Good Morning$nameStr 👋';
    if (hour < 17) return 'Good Afternoon$nameStr ☀️';
    return 'Good Evening$nameStr 🌙';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentCyan,
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 1. Header with Avatar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userProfile?.role ?? 'Take Control of Your Day',
                          style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      ).then((_) => _loadData());
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person, color: AppColors.primary, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. Productivity Score Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardBorder(context)),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(isDark ? 0.15 : 0.08),
                      AppColors.accentCyan.withOpacity(isDark ? 0.05 : 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'PRODUCTIVITY SCORE',
                      style: TextStyle(
                        color: isDark ? AppColors.accentCyan : AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: CircularProgressIndicator(
                            value: _score.totalScore / 100,
                            strokeWidth: 8,
                            backgroundColor: AppColors.surfaceVariant(context),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _score.totalScore >= 75 ? AppColors.success : AppColors.primary,
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '${_score.totalScore}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryColor(context),
                              ),
                            ),
                            Text(
                              '/ 100',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondaryColor(context)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _score.advice,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 3. Screen Time Breakdown Cards
              Row(
                children: [
                  Expanded(child: _metricCard('Screen Time', _formatTime(_totalMinutes), AppColors.info)),
                  const SizedBox(width: 10),
                  Expanded(child: _metricCard('Productive', _formatTime(_productiveMinutes), AppColors.success)),
                  const SizedBox(width: 10),
                  Expanded(child: _metricCard('Distracting', _formatTime(_distractingMinutes), AppColors.danger)),
                ],
              ),
              const SizedBox(height: 18),

              // 4. Start Focus Button Card
              InkWell(
                onTap: widget.onStartFocus,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Start Focus Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Block distractions & enter flow state', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // 4.5. Today's Schedule & Time Blocks
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Today's Schedule", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context))),
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_forward, size: 14),
                    label: Text(_todayBlocks.isEmpty ? 'Plan Day' : 'Manage', style: TextStyle(color: isDark ? AppColors.accentCyan : AppColors.primary)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TimePlannerScreen()),
                      ).then((_) => _loadData());
                    },
                  ),
                ],
              ),
              if (_todayBlocks.isEmpty)
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TimePlannerScreen()),
                    ).then((_) => _loadData());
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder(context)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.calendar_today, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No Time Blocks Allocated Yet',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryColor(context),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap to schedule time blocks for your tasks today',
                                style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 22),
                      ],
                    ),
                  ),
                )
              else
                ..._todayBlocks.take(3).map((b) => _scheduleBlockItem(b)),
              const SizedBox(height: 22),

              // 5. Today's Goals
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Today's Goals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context))),
                  TextButton(
                    onPressed: widget.onViewGoals,
                    child: Text('View All', style: TextStyle(color: isDark ? AppColors.accentCyan : AppColors.primary)),
                  ),
                ],
              ),
              if (_goals.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(16)),
                  child: Text('No goals yet today. Tap View All to create one!', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13)),
                )
              else
                ..._goals.take(3).map((g) => _goalItem(g)),
              const SizedBox(height: 22),

              // 6. Top Apps
              Text('Top Apps Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context))),
              const SizedBox(height: 12),
              ..._apps.take(5).map((app) => _appItem(app)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimaryColor(context))),
          Text(title, style: TextStyle(fontSize: 11, color: AppColors.textSecondaryColor(context))),
        ],
      ),
    );
  }

  Widget _goalItem(Goal goal) {
    final isDone = goal.status == 'COMPLETED';
    final progress = goal.targetMinutes > 0 ? (goal.completedMinutes / goal.targetMinutes).clamp(0.0, 1.0) : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(goal.title, style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.bold, fontSize: 14)),
              Text(
                isDone ? 'Completed' : '${(progress * 100).toInt()}%',
                style: TextStyle(color: isDone ? AppColors.success : (isDark ? AppColors.accentCyan : AppColors.primary), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.surfaceVariant(context),
            valueColor: AlwaysStoppedAnimation<Color>(isDone ? AppColors.success : AppColors.primary),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _appItem(AppUsage app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.surfaceVariant(context),
            child: (app.appIcon != null && app.appIcon!.isNotEmpty)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      app.appIcon!,
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Text(
                        app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
                        style: TextStyle(color: isDark ? AppColors.accentCyan : AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : Text(
                    app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
                    style: TextStyle(color: isDark ? AppColors.accentCyan : AppColors.primary, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.appName, style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${app.category} • ${app.launchCount} opens', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 11)),
              ],
            ),
          ),
          Text(_formatTime(app.durationMinutes), style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _scheduleBlockItem(TimeBlock block) {
    final isDone = block.isCompleted;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone ? AppColors.success.withOpacity(0.3) : AppColors.cardBorder(context),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDone ? AppColors.success.withOpacity(0.15) : AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isDone ? Icons.check_circle : Icons.schedule,
              color: isDone ? AppColors.success : (isDark ? AppColors.accentCyan : AppColors.primary),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.title,
                  style: TextStyle(
                    color: AppColors.textPrimaryColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${block.startTime} - ${block.endTime} • ${block.category}',
                  style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill, color: AppColors.primary, size: 28),
            tooltip: 'Start Focus',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FocusScreen(
                    initialTask: block.title,
                    initialDurationMinutes: block.durationMinutes,
                  ),
                ),
              ).then((_) => _loadData());
            },
          ),
        ],
      ),
    );
  }
}
