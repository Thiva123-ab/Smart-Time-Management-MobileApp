import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../data/models/user_profile.dart';
import 'achievements_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile _profile = UserProfile(
    name: 'Focus User',
    role: 'Productivity Enthusiast',
    email: 'user@focusflow.app',
    bio: 'Focusing on building better daily habits and managing time effectively.',
    dailyTargetHours: 4,
    avatarIndex: 0,
  );

  int _totalFocusMinutes = 0;
  int _completedGoalsCount = 0;
  int _unlockedBadgesCount = 0;
  bool _isLoading = true;

  final List<Map<String, dynamic>> _avatarPresets = [
    {'icon': Icons.rocket_launch, 'label': 'Explorer', 'color': Color(0xFF6C5CE7)},
    {'icon': Icons.code_rounded, 'label': 'Developer', 'color': Color(0xFF00CEC9)},
    {'icon': Icons.school, 'label': 'Scholar', 'color': Color(0xFF0984E3)},
    {'icon': Icons.bolt, 'label': 'Flow State', 'color': Color(0xFFFFA502)},
    {'icon': Icons.self_improvement, 'label': 'Zen', 'color': Color(0xFF00B894)},
    {'icon': Icons.local_fire_department, 'label': 'Performer', 'color': Color(0xFFFD79A8)},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final profile = await UserProfile.load();
    final db = DatabaseHelper.instance;

    final focusMin = await db.getTotalFocusMinutesAllTime();
    final goalsCount = await db.getTotalCompletedGoalsCount();
    final achievements = await db.getAllAchievements();
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;

    setState(() {
      _profile = profile;
      _totalFocusMinutes = focusMin;
      _completedGoalsCount = goalsCount;
      _unlockedBadgesCount = unlockedCount;
      _isLoading = false;
    });
  }

  void _showEditProfileSheet() {
    final nameController = TextEditingController(text: _profile.name);
    final roleController = TextEditingController(text: _profile.role);
    final emailController = TextEditingController(text: _profile.email);
    final bioController = TextEditingController(text: _profile.bio);
    int selectedAvatar = _profile.avatarIndex;
    int targetHours = _profile.dailyTargetHours;

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
                        'Edit Profile',
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

                  // Choose Avatar
                  Text(
                    'Choose Avatar Badge',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_avatarPresets.length, (idx) {
                      final item = _avatarPresets[idx];
                      final isSelected = selectedAvatar == idx;
                      final col = item['color'] as Color;

                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedAvatar = idx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: col.withOpacity(isSelected ? 0.25 : 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? col : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            color: col,
                            size: 22,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),

                  // Name field
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: AppColors.textPrimaryColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Your Name',
                      hintText: 'e.g. Alex Silva',
                      prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                      labelStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
                      hintStyle: TextStyle(color: AppColors.textMutedColor(context)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Role/Profession
                  TextField(
                    controller: roleController,
                    style: TextStyle(color: AppColors.textPrimaryColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Role / Occupation',
                      hintText: 'e.g. Software Engineer or Student',
                      prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary),
                      labelStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
                      hintStyle: TextStyle(color: AppColors.textMutedColor(context)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Email
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: AppColors.textPrimaryColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'e.g. user@gmail.com',
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                      labelStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
                      hintStyle: TextStyle(color: AppColors.textMutedColor(context)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Bio
                  TextField(
                    controller: bioController,
                    maxLines: 2,
                    style: TextStyle(color: AppColors.textPrimaryColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Productivity Motto / Bio',
                      hintText: 'e.g. Working deeply every single day.',
                      prefixIcon: const Icon(Icons.format_quote_outlined, color: AppColors.primary),
                      labelStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
                      hintStyle: TextStyle(color: AppColors.textMutedColor(context)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Daily Target Hours
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daily Productivity Target',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$targetHours Hours / Day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.accentCyan : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: targetHours.toDouble(),
                    min: 1,
                    max: 12,
                    divisions: 11,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.surfaceVariant(context),
                    label: '$targetHours hours',
                    onChanged: (val) {
                      setSheetState(() => targetHours = val.round());
                    },
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        final newProfile = _profile.copyWith(
                          name: nameController.text.trim().isEmpty ? 'User' : nameController.text.trim(),
                          role: roleController.text.trim().isEmpty ? 'Productivity Enthusiast' : roleController.text.trim(),
                          email: emailController.text.trim().isEmpty ? 'user@focusflow.app' : emailController.text.trim(),
                          bio: bioController.text.trim().isEmpty ? 'Focusing on building better daily habits.' : bioController.text.trim(),
                          dailyTargetHours: targetHours,
                          avatarIndex: selectedAvatar,
                        );

                        await newProfile.save();
                        Navigator.pop(ctx);
                        _loadProfileData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile updated successfully!')),
                          );
                        }
                      },
                      child: const Text('Save Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  String _formatHours(int minutes) {
    final h = (minutes / 60).toStringAsFixed(1);
    return '${h}h';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentAvatar = _avatarPresets[_profile.avatarIndex.clamp(0, _avatarPresets.length - 1)];
    final avatarColor = currentAvatar['color'] as Color;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          'User Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfileData,
          color: AppColors.accentCyan,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 1. Profile Hero Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1F1C38), const Color(0xFF26204E)]
                        : [const Color(0xFFEDE9FE), const Color(0xFFF5F3FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: avatarColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: avatarColor, width: 2.5),
                          ),
                          child: Icon(
                            currentAvatar['icon'] as IconData,
                            size: 46,
                            color: avatarColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface(context),
                              width: 2,
                            ),
                          ),
                          child: const Icon(Icons.bolt, size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _profile.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: avatarColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _profile.role,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: avatarColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _profile.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMutedColor(context),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '“${_profile.bio}”',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                        label: const Text(
                          'Edit Profile & Goals',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        onPressed: _showEditProfileSheet,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 2. All-Time Productivity Highlights
              Text(
                'Productivity Milestones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Focus Time',
                      _formatHours(_totalFocusMinutes),
                      Icons.timer_outlined,
                      AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      'Daily Target',
                      '${_profile.dailyTargetHours}h / day',
                      Icons.flag_outlined,
                      AppColors.accentCyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Goals Crushed',
                      '$_completedGoalsCount',
                      Icons.check_circle_outline,
                      AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      'Badges Earned',
                      '$_unlockedBadgesCount / 6',
                      Icons.military_tech_outlined,
                      AppColors.warning,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // 3. User Badges & Achievements Preview
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
                        Row(
                          children: [
                            const Icon(Icons.workspace_premium, color: AppColors.warning, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Achievements & Streaks',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryColor(context),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                            );
                          },
                          child: Text(
                            'View All',
                            style: TextStyle(color: isDark ? AppColors.accentCyan : AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You have unlocked $_unlockedBadgesCount badges! Keep completing daily time blocks and focus sessions to unlock more.',
                      style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 4. Quick Account Actions
              Text(
                'Preferences & Data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 12),
              _actionTile(
                icon: Icons.tune_rounded,
                title: 'App Settings & Privacy',
                subtitle: 'Manage permissions, bedtime mode, and API keys',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),
              _actionTile(
                icon: Icons.calendar_month_outlined,
                title: 'Daily Schedule & Time Blocks',
                subtitle: 'Manage allocated task time slots and agenda',
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
                if (onTap != null)
                  Icon(Icons.chevron_right, size: 18, color: AppColors.textMutedColor(context)),
              ],
            ),
            const SizedBox(height: 10),
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
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
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
            fontSize: 11,
            color: AppColors.textMutedColor(context),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      ),
    );
  }
}
