import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../data/models/daily_score.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<Achievement> _achievements = [];
  int _currentStreak = 4;
  int _bestStreak = 7;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.getAllAchievements();
    setState(() {
      _achievements = list;
      _isLoading = false;
    });
  }

  IconData _getBadgeIcon(String id) {
    switch (id) {
      case 'first_focus':
        return Icons.rocket_launch_outlined;
      case 'focus_10_hours':
        return Icons.psychology;
      case 'streak_3_days':
        return Icons.local_fire_department;
      case 'streak_7_days':
        return Icons.military_tech;
      case 'digital_balance':
        return Icons.balance;
      case 'goals_master':
        return Icons.emoji_events;
      default:
        return Icons.star_border;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unlockedCount = _achievements.where((a) => a.isUnlocked).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Streaks & Badges',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context)),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Streak Hero Banner
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFFE17055), Color(0xFFD63031)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD63031).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_fire_department, color: Colors.white, size: 40),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '$_currentStreak Day Streak!',
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            const Text('🔥', style: TextStyle(fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You have hit your daily productivity score 4 days in a row. Best: $_bestStreak days.',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Badges Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Achievements',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder(context)),
                  ),
                  child: Text(
                    '$unlockedCount of ${_achievements.length} Unlocked',
                    style: TextStyle(
                      color: isDark ? AppColors.accentCyan : AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Grid of Badges
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _achievements.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, index) {
                final badge = _achievements[index];
                final icon = _getBadgeIcon(badge.achievementId);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: badge.isUnlocked
                          ? (isDark ? AppColors.accentCyan.withOpacity(0.5) : AppColors.primary.withOpacity(0.5))
                          : AppColors.cardBorder(context),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: badge.isUnlocked
                              ? AppColors.primary.withOpacity(0.15)
                              : AppColors.surfaceVariant(context),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 32,
                          color: badge.isUnlocked
                              ? (isDark ? AppColors.accentCyan : AppColors.primary)
                              : AppColors.textMutedColor(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        badge.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: badge.isUnlocked
                              ? AppColors.textPrimaryColor(context)
                              : AppColors.textMutedColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        badge.description,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 11),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
