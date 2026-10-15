import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../data/models/app_usage.dart';
import '../data/models/goal.dart';
import '../data/models/time_block.dart';
import '../data/models/daily_note.dart';
import '../domain/app_category_manager.dart';
import '../domain/productivity_score_engine.dart';
import '../services/usage_tracking_service.dart';
import '../services/transport_tracking_service.dart';
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
  List<DailyNote> _todayNotes = [];
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
    final todayNotes = await db.getDailyNotesForDate(today);
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
      _todayNotes = todayNotes;
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
              const SizedBox(height: 16),

              // Live Transport Active Indicator Banner
              Consumer<TransportTrackingService>(
                builder: (ctx, transportService, _) {
                  if (!transportService.isTracking) return const SizedBox.shrink();
                  final elapsedSec = transportService.currentElapsedSeconds;
                  final h = elapsedSec ~/ 3600;
                  final m = (elapsedSec % 3600) ~/ 60;
                  final s = elapsedSec % 60;
                  final timeStr = h > 0
                      ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
                      : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B4D8).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF00B4D8), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF00B4D8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.directions_bus_filled_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Transport Tracking Active',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00B4D8)),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                                    child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Time running: $timeStr • Tap to manage or stop',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondaryColor(context)),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00B4D8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TimePlannerScreen()),
                            ).then((_) => _loadData());
                          },
                          child: const Text('Manage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                },
              ),
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

              // 4.8. Today's Notes & Ideas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text("Today's Notes & Ideas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context))),
                    ],
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_forward, size: 14),
                    label: Text(_todayNotes.isEmpty ? '+ Add Note' : 'View All', style: TextStyle(color: isDark ? AppColors.accentCyan : AppColors.primary)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TimePlannerScreen()),
                      ).then((_) => _loadData());
                    },
                  ),
                ],
              ),
              if (_todayNotes.isEmpty)
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
                                'Jot Down Today\'s Ideas & Notes',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryColor(context),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Capture thoughts, daily reflections, or creative sparks',
                                style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.add_circle_outline, color: Colors.amber, size: 22),
                      ],
                    ),
                  ),
                )
              else
                ..._todayNotes.take(3).map((n) => _noteDashboardItem(n)),
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
          AppIconWidget(
            packageName: app.packageName,
            appName: app.appName,
            initialIcon: app.appIcon,
            size: 38,
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

  Widget _noteDashboardItem(DailyNote note) {
    Color tagColor = const Color(0xFF6C5CE7);
    if (note.colorHex != null) {
      try {
        final buffer = StringBuffer();
        if (note.colorHex!.length == 6 || note.colorHex!.length == 7) buffer.write('ff');
        buffer.write(note.colorHex!.replaceFirst('#', ''));
        tagColor = Color(int.parse(buffer.toString(), radix: 16));
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: note.isPinned ? Colors.amber.withValues(alpha: 0.6) : AppColors.cardBorder(context),
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TimePlannerScreen()),
          ).then((_) => _loadData());
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                note.category,
                style: TextStyle(
                  color: tagColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title,
                          style: TextStyle(
                            color: AppColors.textPrimaryColor(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (note.isPinned)
                        const Icon(Icons.push_pin, size: 14, color: Colors.amber),
                    ],
                  ),
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      note.content,
                      style: TextStyle(
                        color: AppColors.textSecondaryColor(context),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

