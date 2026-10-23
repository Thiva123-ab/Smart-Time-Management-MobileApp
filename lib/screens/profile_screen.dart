import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../data/models/user_profile.dart';
import 'achievements_screen.dart';
import 'settings_screen.dart';
import '../widgets/habit_heatmap_widget.dart';

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
    bio: 'Dedicated to high performance, continuous learning, and mindful digital habits.',
    dailyTargetHours: 4,
    avatarIndex: 0,
    phoneNumber: '+94 77 123 4567',
    location: 'Colombo, Sri Lanka',
    occupationField: 'Software & Tech',
    linkedinUrl: 'linkedin.com/in/focususer',
    githubUrl: 'github.com/focususer',
    portfolioUrl: 'focusflow.app/me',
    joinedDate: 'Oct 2026',
  );

  int _totalFocusMinutes = 0;
  int _completedGoalsCount = 0;
  int _unlockedBadgesCount = 0;
  bool _isLoading = true;

  final List<Map<String, dynamic>> _avatarPresets = [
    {'icon': Icons.rocket_launch, 'label': 'Explorer', 'color': const Color(0xFF6C5CE7)},
    {'icon': Icons.code_rounded, 'label': 'Architect', 'color': const Color(0xFF00CEC9)},
    {'icon': Icons.school, 'label': 'Scholar', 'color': const Color(0xFF0984E3)},
    {'icon': Icons.bolt, 'label': 'Flow State', 'color': const Color(0xFFFFA502)},
    {'icon': Icons.self_improvement, 'label': 'Zen Sage', 'color': const Color(0xFF00B894)},
    {'icon': Icons.local_fire_department, 'label': 'Performer', 'color': const Color(0xFFFD79A8)},
    {'icon': Icons.palette_rounded, 'label': 'Creative', 'color': const Color(0xFFE056FD)},
    {'icon': Icons.shield_rounded, 'label': 'Strategist', 'color': const Color(0xFFF0932B)},
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

    if (mounted) {
      setState(() {
        _profile = profile;
        _totalFocusMinutes = focusMin;
        _completedGoalsCount = goalsCount;
        _unlockedBadgesCount = unlockedCount;
        _isLoading = false;
      });
    }
  }

  int get _userLevel => (_totalFocusMinutes ~/ 120) + 1;
  double get _levelProgress => (_totalFocusMinutes % 120) / 120.0;

  String get _levelTitle {
    final lvl = _userLevel;
    if (lvl <= 2) return 'Novice Practitioner';
    if (lvl <= 5) return 'Focus Enthusiast';
    if (lvl <= 9) return 'Deep Work Specialist';
    return 'Master of Focus';
  }

  void _copyToClipboard(String text, String label) {
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showEditProfileSheet() {
    final nameController = TextEditingController(text: _profile.name);
    final roleController = TextEditingController(text: _profile.role);
    final occupationController = TextEditingController(text: _profile.occupationField);
    final emailController = TextEditingController(text: _profile.email);
    final phoneController = TextEditingController(text: _profile.phoneNumber);
    final locationController = TextEditingController(text: _profile.location);
    final bioController = TextEditingController(text: _profile.bio);
    final linkedinController = TextEditingController(text: _profile.linkedinUrl);
    final githubController = TextEditingController(text: _profile.githubUrl);
    final portfolioController = TextEditingController(text: _profile.portfolioUrl);

    int selectedAvatar = _profile.avatarIndex;
    int targetHours = _profile.dailyTargetHours;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.92,
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: AppColors.cardBorder(context)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.35),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.badge_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Edit Professional Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textMutedColor(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: [
                      // Avatar Badge Picker
                      Text(
                        'Choose Avatar Identity',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_avatarPresets.length, (idx) {
                            final item = _avatarPresets[idx];
                            final isSelected = selectedAvatar == idx;
                            final col = item['color'] as Color;

                            return GestureDetector(
                              onTap: () => setSheetState(() => selectedAvatar = idx),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: col.withValues(alpha: isSelected ? 0.25 : 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? col : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(item['icon'] as IconData, color: col, size: 24),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['label'] as String,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? col : AppColors.textSecondaryColor(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Personal & Professional Fields
                      _sectionTitle('Personal & Professional Identity'),
                      const SizedBox(height: 8),
                      _inputField(
                        controller: nameController,
                        label: 'Full Name',
                        hint: 'e.g. Alex Henderson',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _inputField(
                              controller: roleController,
                              label: 'Role / Designation',
                              hint: 'e.g. Lead Engineer',
                              icon: Icons.work_outline_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _inputField(
                              controller: occupationController,
                              label: 'Field / Industry',
                              hint: 'e.g. Tech & AI',
                              icon: Icons.domain_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _inputField(
                        controller: bioController,
                        label: 'Bio / Executive Motto',
                        hint: 'e.g. Deep Work Specialist & Continuous Learner',
                        icon: Icons.format_quote_rounded,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 18),

                      // Contact & Location Fields
                      _sectionTitle('Contact & Location Details'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _inputField(
                              controller: emailController,
                              label: 'Email Address',
                              hint: 'user@focusflow.app',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _inputField(
                              controller: phoneController,
                              label: 'Phone Number',
                              hint: '+94 77 123 4567',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _inputField(
                        controller: locationController,
                        label: 'Location / Region',
                        hint: 'e.g. Colombo, Sri Lanka',
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 18),

                      // Social & Web Links
                      _sectionTitle('Social & Professional Links'),
                      const SizedBox(height: 8),
                      _inputField(
                        controller: linkedinController,
                        label: 'LinkedIn Profile URL',
                        hint: 'linkedin.com/in/username',
                        icon: Icons.link_rounded,
                      ),
                      const SizedBox(height: 10),
                      _inputField(
                        controller: githubController,
                        label: 'GitHub Profile URL',
                        hint: 'github.com/username',
                        icon: Icons.code_rounded,
                      ),
                      const SizedBox(height: 10),
                      _inputField(
                        controller: portfolioController,
                        label: 'Portfolio / Website URL',
                        hint: 'myportfolio.com',
                        icon: Icons.language_rounded,
                      ),
                      const SizedBox(height: 18),

                      // Daily Target Slider
                      _sectionTitle('Daily Focus Commitment'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardBorder(context)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Daily Focus Hours Target',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimaryColor(context),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$targetHours hrs/day',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppColors.primary,
                                thumbColor: AppColors.accentCyan,
                                overlayColor: AppColors.primary.withValues(alpha: 0.2),
                              ),
                              child: Slider(
                                value: targetHours.toDouble(),
                                min: 1,
                                max: 12,
                                divisions: 11,
                                onChanged: (val) {
                                  setSheetState(() => targetHours = val.round());
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      final updated = _profile.copyWith(
                        name: nameController.text.trim().isEmpty ? 'Focus User' : nameController.text.trim(),
                        role: roleController.text.trim().isEmpty ? 'Productivity Enthusiast' : roleController.text.trim(),
                        occupationField: occupationController.text.trim().isEmpty ? 'General' : occupationController.text.trim(),
                        email: emailController.text.trim().isEmpty ? 'user@focusflow.app' : emailController.text.trim(),
                        phoneNumber: phoneController.text.trim(),
                        location: locationController.text.trim().isEmpty ? 'Global' : locationController.text.trim(),
                        bio: bioController.text.trim().isEmpty ? 'Focusing on building better daily habits.' : bioController.text.trim(),
                        linkedinUrl: linkedinController.text.trim(),
                        githubUrl: githubController.text.trim(),
                        portfolioUrl: portfolioController.text.trim(),
                        dailyTargetHours: targetHours,
                        avatarIndex: selectedAvatar,
                      );

                      await updated.save();
                      await _loadProfileData();

                      if (ctx.mounted && mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Profile updated successfully!'),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.success,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Save Professional Profile',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondaryColor(context),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: 13,
        color: AppColors.textPrimaryColor(context),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: AppColors.textMutedColor(context)),
        labelStyle: TextStyle(fontSize: 12, color: AppColors.textSecondaryColor(context)),
        prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.surfaceVariant(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.cardBorder(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.cardBorder(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  String _formatHours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
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
          'Executive Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            children: [
              // 1. Ultra-Modern Glassmorphic Hero Card
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF1E1B38),
                            const Color(0xFF141228),
                          ]
                        : [
                            const Color(0xFFF3F0FF),
                            const Color(0xFFFFFFFF),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: avatarColor.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: avatarColor.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Avatar & Level Ring
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glowing aura
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                avatarColor.withValues(alpha: 0.2),
                                avatarColor,
                                AppColors.accentCyan,
                                avatarColor.withValues(alpha: 0.2),
                              ],
                            ),
                          ),
                        ),
                        // Inner circle
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            color: AppColors.surface(context),
                            shape: BoxShape.circle,
                            border: Border.all(color: avatarColor, width: 2.5),
                          ),
                          child: Icon(
                            currentAvatar['icon'] as IconData,
                            size: 42,
                            color: avatarColor,
                          ),
                        ),
                        // Verified badge
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface(context),
                                width: 2,
                              ),
                            ),
                            child: const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // User Name & Pro Pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _profile.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Role & Occupation Pill
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: avatarColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: avatarColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _profile.role,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: avatarColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder(context)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.domain_rounded, size: 12, color: AppColors.accentCyan),
                              const SizedBox(width: 4),
                              Text(
                                _profile.occupationField,
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
                    ),
                    const SizedBox(height: 8),

                    // Location & Member Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMutedColor(context)),
                        const SizedBox(width: 4),
                        Text(
                          _profile.location,
                          style: TextStyle(fontSize: 11, color: AppColors.textMutedColor(context)),
                        ),
                        const SizedBox(width: 10),
                        Text('•', style: TextStyle(color: AppColors.textMutedColor(context))),
                        const SizedBox(width: 10),
                        Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textMutedColor(context)),
                        const SizedBox(width: 4),
                        Text(
                          'Since ${_profile.joinedDate}',
                          style: TextStyle(fontSize: 11, color: AppColors.textMutedColor(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Bio Quote Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant(context).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder(context).withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '“${_profile.bio}”',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Level & XP Progress
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context).withValues(alpha: 0.8),
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
                                  const Icon(Icons.bolt_rounded, color: AppColors.warning, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Level $_userLevel • $_levelTitle',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimaryColor(context),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${(_levelProgress * 100).toInt()}% to Lvl ${_userLevel + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _levelProgress.clamp(0.05, 1.0),
                              minHeight: 6,
                              backgroundColor: AppColors.surfaceVariant(context),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text(
                              'Edit Profile',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: _showEditProfileSheet,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.cardBorder(context)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 15, color: AppColors.accentCyan),
                            label: Text(
                              'Copy Info',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? AppColors.accentCyan : AppColors.primaryDark,
                              ),
                            ),
                            onPressed: () {
                              final summary = '${_profile.name} • ${_profile.role} (${_profile.occupationField})\nEmail: ${_profile.email}\nPhone: ${_profile.phoneNumber}\nFocus Target: ${_profile.dailyTargetHours}h/day';
                              _copyToClipboard(summary, 'Profile Details');
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Professional & Contact Info Card
              _buildSectionHeader('Professional & Contact Information', Icons.contact_page_rounded),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder(context)),
                ),
                child: Column(
                  children: [
                    _contactTile(
                      icon: Icons.phone_rounded,
                      iconColor: AppColors.success,
                      label: 'Phone Number',
                      value: _profile.phoneNumber.isNotEmpty ? _profile.phoneNumber : 'Not set (Tap to add)',
                      onCopy: () => _copyToClipboard(_profile.phoneNumber, 'Phone number'),
                      onTap: _showEditProfileSheet,
                    ),
                    Divider(height: 1, color: AppColors.cardBorder(context)),
                    _contactTile(
                      icon: Icons.email_rounded,
                      iconColor: AppColors.primary,
                      label: 'Email Address',
                      value: _profile.email,
                      onCopy: () => _copyToClipboard(_profile.email, 'Email address'),
                      onTap: _showEditProfileSheet,
                    ),
                    Divider(height: 1, color: AppColors.cardBorder(context)),
                    _contactTile(
                      icon: Icons.business_center_rounded,
                      iconColor: AppColors.warning,
                      label: 'Occupation & Industry',
                      value: '${_profile.role} • ${_profile.occupationField}',
                      onTap: _showEditProfileSheet,
                    ),
                    Divider(height: 1, color: AppColors.cardBorder(context)),
                    _contactTile(
                      icon: Icons.place_rounded,
                      iconColor: AppColors.accentPink,
                      label: 'Location / Region',
                      value: _profile.location,
                      onTap: _showEditProfileSheet,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Social & Portfolio Links Card
              _buildSectionHeader('Social & Portfolio Links', Icons.hub_rounded),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder(context)),
                ),
                child: Column(
                  children: [
                    _socialTile(
                      icon: Icons.link_rounded,
                      color: const Color(0xFF0077B5),
                      label: 'LinkedIn',
                      value: _profile.linkedinUrl.isNotEmpty ? _profile.linkedinUrl : 'Add LinkedIn link',
                      onCopy: () => _copyToClipboard(_profile.linkedinUrl, 'LinkedIn URL'),
                      onTap: _showEditProfileSheet,
                    ),
                    Divider(height: 1, color: AppColors.cardBorder(context)),
                    _socialTile(
                      icon: Icons.code_rounded,
                      color: isDark ? Colors.white : const Color(0xFF24292E),
                      label: 'GitHub',
                      value: _profile.githubUrl.isNotEmpty ? _profile.githubUrl : 'Add GitHub profile',
                      onCopy: () => _copyToClipboard(_profile.githubUrl, 'GitHub URL'),
                      onTap: _showEditProfileSheet,
                    ),
                    Divider(height: 1, color: AppColors.cardBorder(context)),
                    _socialTile(
                      icon: Icons.language_rounded,
                      color: AppColors.accentCyan,
                      label: 'Portfolio / Website',
                      value: _profile.portfolioUrl.isNotEmpty ? _profile.portfolioUrl : 'Add personal website',
                      onCopy: () => _copyToClipboard(_profile.portfolioUrl, 'Portfolio URL'),
                      onTap: _showEditProfileSheet,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. 30-Day Activity & Habit Consistency Matrix
              _buildSectionHeader('30-Day Habit & Consistency Matrix', Icons.grid_view_rounded),
              const SizedBox(height: 10),
              const HabitHeatmapWidget(isCompact: true),
              const SizedBox(height: 20),

              // 5. Lifetime Productivity Milestones Grid
              _buildSectionHeader('Lifetime Productivity Milestones', Icons.insights_rounded),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Total Focus',
                      _formatHours(_totalFocusMinutes),
                      Icons.timer_rounded,
                      AppColors.primary,
                      subtitle: 'Hours deep work',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      'Daily Target',
                      '${_profile.dailyTargetHours}h / day',
                      Icons.flag_rounded,
                      AppColors.accentCyan,
                      subtitle: 'Commitment',
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
                      Icons.task_alt_rounded,
                      AppColors.success,
                      subtitle: 'Completed tasks',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      'Badges Earned',
                      '$_unlockedBadgesCount / 6',
                      Icons.military_tech_rounded,
                      AppColors.warning,
                      subtitle: 'Milestones',
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

              // 5. Quick Account Actions
              _buildSectionHeader('Account & Data Options', Icons.tune_rounded),
              const SizedBox(height: 10),
              _actionTile(
                icon: Icons.settings_rounded,
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
                icon: Icons.military_tech_rounded,
                title: 'Achievements & Streaks Showcase',
                subtitle: 'View all trophies, badges, and consecutive habit records',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
      ],
    );
  }

  Widget _contactTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    VoidCallback? onCopy,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
            if (onCopy != null)
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                color: AppColors.textMutedColor(context),
                onPressed: onCopy,
                tooltip: 'Copy',
              ),
          ],
        ),
      ),
    );
  }

  Widget _socialTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    VoidCallback? onCopy,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
            if (onCopy != null)
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                color: AppColors.textMutedColor(context),
                onPressed: onCopy,
                tooltip: 'Copy link',
              ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder(context)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMutedColor(context)),
              ],
            ),
            const SizedBox(height: 12),
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
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textMutedColor(context),
                ),
              ),
            ],
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
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
        trailing: Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMutedColor(context)),
      ),
    );
  }
}
