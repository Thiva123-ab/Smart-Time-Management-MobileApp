import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../data/models/user_profile.dart';
import 'dashboard_screen.dart';
import 'usage_screen.dart';
import 'focus_screen.dart';
import 'goals_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'ai_assistant_screen.dart';
import 'achievements_screen.dart';
import 'time_planner_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await UserProfile.load();
    if (mounted) {
      setState(() => _profile = profile);
    }
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  void _navigateToFocus() {
    setState(() => _currentIndex = 2);
  }

  void _navigateToGoals() {
    setState(() => _currentIndex = 3);
  }

  IconData _getAvatarIcon(int index) {
    switch (index) {
      case 0:
        return Icons.rocket_launch;
      case 1:
        return Icons.code_rounded;
      case 2:
        return Icons.school;
      case 3:
        return Icons.bolt;
      case 4:
        return Icons.self_improvement;
      case 5:
        return Icons.local_fire_department;
      default:
        return Icons.person;
    }
  }

  void _showQuickHubSheet(BuildContext context, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: AppColors.cardBorder(context), width: 0.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                // User Profile Header Card
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ).then((_) => _loadUserProfile());
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1F1C38), const Color(0xFF26204E)]
                            : [const Color(0xFFEDE9FE), const Color(0xFFF5F3FF)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          child: Icon(
                            _getAvatarIcon(_profile?.avatarIndex ?? 0),
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _profile?.name ?? 'Focus User',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textPrimaryColor(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _profile?.role ?? 'Productivity Enthusiast',
                                style: TextStyle(
                                  color: AppColors.textSecondaryColor(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Dark / Light Theme Mode Switch Tile
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.accentCyan : AppColors.primary).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                        color: isDark ? AppColors.accentCyan : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Dark Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    subtitle: Text(
                      isDark ? 'Dark theme enabled' : 'Light theme enabled',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                    trailing: Switch.adaptive(
                      value: isDark,
                      activeColor: AppColors.accentCyan,
                      onChanged: (val) {
                        themeProvider.toggleTheme();
                        setSheetState(() {});
                      },
                    ),
                  ),
                ),

                // Achievements Tile
                _hubTile(
                  context: context,
                  icon: Icons.military_tech_outlined,
                  iconColor: AppColors.warning,
                  title: 'Badges & Streaks',
                  subtitle: 'View unlocked achievements & streaks',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                    );
                  },
                ),

                // Settings Tile
                _hubTile(
                  context: context,
                  icon: Icons.settings_outlined,
                  iconColor: AppColors.textSecondaryColor(context),
                  title: 'Settings & Privacy',
                  subtitle: 'Usage permissions, AI key, data limits',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ).then((_) => _loadUserProfile());
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _hubTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondaryColor(context),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final List<Widget> screens = [
      DashboardScreen(
        onStartFocus: _navigateToFocus,
        onViewGoals: _navigateToGoals,
      ),
      const UsageScreen(),
      const FocusScreen(),
      const GoalsScreen(),
      const AnalyticsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'FocusFlow',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, color: AppColors.accentCyan),
            tooltip: 'Time Planner & Schedule',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TimePlannerScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppColors.accentPink),
            tooltip: 'AI Coach',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
              );
            },
          ),
          GestureDetector(
            onTap: () => _showQuickHubSheet(context, themeProvider),
            child: Container(
              margin: const EdgeInsets.only(right: 14, left: 4),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.accentCyan : AppColors.primary,
                  width: 1.8,
                ),
              ),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                child: Icon(
                  _getAvatarIcon(_profile?.avatarIndex ?? 0),
                  size: 18,
                  color: isDark ? AppColors.accentCyan : AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.cardBorder(context), width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabTapped,
          backgroundColor: AppColors.surface(context),
          indicatorColor: AppColors.primary.withOpacity(isDark ? 0.2 : 0.12),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: isDark ? AppColors.accentCyan : AppColors.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: const Icon(Icons.pie_chart_outline),
              selectedIcon: Icon(Icons.pie_chart, color: isDark ? AppColors.accentCyan : AppColors.primary),
              label: 'Usage',
            ),
            NavigationDestination(
              icon: const Icon(Icons.timer_outlined),
              selectedIcon: Icon(Icons.timer, color: isDark ? AppColors.accentCyan : AppColors.primary),
              label: 'Focus',
            ),
            NavigationDestination(
              icon: const Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag, color: isDark ? AppColors.accentCyan : AppColors.primary),
              label: 'Goals',
            ),
            NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart, color: isDark ? AppColors.accentCyan : AppColors.primary),
              label: 'Analytics',
            ),
          ],
        ),
      ),
    );
  }
}
