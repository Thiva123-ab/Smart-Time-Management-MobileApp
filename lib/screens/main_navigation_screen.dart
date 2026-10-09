import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
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

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  void _navigateToFocus() {
    setState(() => _currentIndex = 2);
  }

  void _navigateToGoals() {
    setState(() => _currentIndex = 3);
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
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'FocusFlow',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: isDark ? AppColors.accentCyan : AppColors.primary,
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () => themeProvider.toggleTheme(),
          ),
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
          IconButton(
            icon: const Icon(Icons.military_tech_outlined, color: AppColors.warning),
            tooltip: 'Badges & Streaks',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AchievementsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: AppColors.textSecondaryColor(context)),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, color: AppColors.primaryLight, size: 26),
            tooltip: 'User Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 6),
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
