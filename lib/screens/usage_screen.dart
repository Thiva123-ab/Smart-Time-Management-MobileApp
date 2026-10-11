import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../data/models/app_usage.dart';
import '../data/models/time_budget.dart';
import '../domain/app_category_manager.dart';
import '../services/usage_tracking_service.dart';
import '../widgets/app_icon_widget.dart';

class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  DateTime _selectedDate = DateTime.now();
  List<AppUsage> _allApps = [];
  List<AppUsage> _filteredApps = [];
  Map<String, int> _appLimits = {};
  String _selectedCategory = 'All';
  String _searchQuery = '';
  int _totalUsageMinutes = 0;
  int _productiveMinutes = 0;
  int _distractingMinutes = 0;
  bool _isLoading = true;

  final List<String> _categories = [
    'All',
    'Productivity',
    'Education',
    'Work',
    'Social Media',
    'Entertainment',
    'Gaming',
    'Communication',
    'Browser',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadDataForDate(_selectedDate);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dateString(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  Future<void> _loadDataForDate(DateTime date) async {
    setState(() => _isLoading = true);
    final apps = await UsageTrackingService.fetchUsageForDate(date);
    final db = DatabaseHelper.instance;

    // Save fetched usage to local database
    if (apps.isNotEmpty) {
      await db.saveAppUsageList(apps);
    }

    final limits = await db.getAllAppLimits();
    final limitMap = <String, int>{};
    for (var l in limits) {
      if (l.enabled) {
        limitMap[l.packageName] = l.limitMinutes;
      }
    }

    int total = 0;
    int prod = 0;
    int dist = 0;

    for (var a in apps) {
      total += a.durationMinutes;
      if (AppCategoryManager.isProductive(a.category)) {
        prod += a.durationMinutes;
      } else if (AppCategoryManager.isDistracting(a.category)) {
        dist += a.durationMinutes;
      }
    }

    if (mounted) {
      setState(() {
        _selectedDate = date;
        _allApps = apps;
        _appLimits = limitMap;
        _totalUsageMinutes = total;
        _productiveMinutes = prod;
        _distractingMinutes = dist;
        _isLoading = false;
      });
      _filterList();
    }
  }

  void _filterList() {
    setState(() {
      _filteredApps = _allApps.where((app) {
        final matchesCategory = _selectedCategory == 'All' || app.category == _selectedCategory;
        final matchesSearch = _searchQuery.isEmpty || app.appName.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String get _dateSubtitle {
    final now = DateTime.now();
    if (_isSameDay(_selectedDate, now)) {
      return "Today's live device activity";
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(_selectedDate, yesterday)) {
      return "Yesterday's device activity";
    }
    return "Activity for ${DateFormat('EEEE, MMM d').format(_selectedDate)}";
  }

  void _showSetLimitDialog(AppUsage app) {
    final currentLimit = _appLimits[app.packageName] ?? 60;
    final controller = TextEditingController(text: currentLimit.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            AppIconWidget(packageName: app.packageName, appName: app.appName, initialIcon: app.appIcon, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Daily Limit: ${app.appName}',
                style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set a maximum daily usage time in minutes:',
              style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(color: AppColors.textPrimaryColor(context)),
              decoration: InputDecoration(
                labelText: 'Limit (Minutes)',
                labelStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
                suffixText: 'mins',
                suffixStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMutedColor(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final newLimit = int.tryParse(controller.text.trim()) ?? 60;
              final limitObj = AppLimit(
                packageName: app.packageName,
                appName: app.appName,
                limitMinutes: newLimit,
                date: _dateString(_selectedDate),
                enabled: true,
              );
              await DatabaseHelper.instance.setAppLimit(limitObj);
              setState(() {
                _appLimits[app.packageName] = newLimit;
              });
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Daily limit set: $newLimit mins for ${app.appName}'),
                    backgroundColor: AppColors.surfaceVariant(context),
                  ),
                );
              }
            },
            child: const Text('Save Limit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Usage',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context)),
                      ),
                      const SizedBox(height: 3),
                      Text(_dateSubtitle, style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13)),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.calendar_today_outlined, size: 20),
                        tooltip: 'Select Date',
                        color: AppColors.textSecondaryColor(context),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            _loadDataForDate(picked);
                          }
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder(context)),
                        ),
                        child: Text(
                          _formatTime(_totalUsageMinutes),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.accentCyan : AppColors.primary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Horizontal Day-by-Day Strip
            _buildDaySelectorStrip(isDark),

            // Day Breakdown Cards
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _summaryMetricCard(
                      'Total Screen Time',
                      _formatTime(_totalUsageMinutes),
                      Icons.phone_android,
                      AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryMetricCard(
                      'Productive',
                      _formatTime(_productiveMinutes),
                      Icons.trending_up,
                      AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryMetricCard(
                      'Distracting',
                      _formatTime(_distractingMinutes),
                      Icons.warning_amber_rounded,
                      AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: TextField(
                onChanged: (val) {
                  _searchQuery = val;
                  _filterList();
                },
                style: TextStyle(color: AppColors.textPrimaryColor(context)),
                decoration: InputDecoration(
                  hintText: 'Search applications...',
                  hintStyle: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13),
                  prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textSecondaryColor(context)),
                  filled: true,
                  fillColor: AppColors.surface(context),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.cardBorder(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.cardBorder(context)),
                  ),
                ),
              ),
            ),

            // Category Chips
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat == _selectedCategory;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface(context),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondaryColor(context),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.cardBorder(context),
                    ),
                    onSelected: (val) {
                      setState(() => _selectedCategory = cat);
                      _filterList();
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 6),

            // App List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : RefreshIndicator(
                      color: AppColors.accentCyan,
                      onRefresh: () => _loadDataForDate(_selectedDate),
                      child: _filteredApps.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 60),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.search_off, size: 48, color: AppColors.textMutedColor(context).withOpacity(0.5)),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No apps recorded for this day',
                                        style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                              itemCount: _filteredApps.length,
                              itemBuilder: (context, index) {
                                final app = _filteredApps[index];
                                final limit = _appLimits[app.packageName];
                                final hasLimit = limit != null && limit > 0;
                                final isExceeded = hasLimit && app.durationMinutes >= limit;
                                final usageRatio = _totalUsageMinutes > 0
                                    ? (app.durationMinutes / _totalUsageMinutes).clamp(0.0, 1.0)
                                    : 0.0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface(context),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isExceeded
                                          ? AppColors.danger.withOpacity(0.6)
                                          : AppColors.cardBorder(context),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Dynamic App Logo / Icon Widget
                                          AppIconWidget(
                                            packageName: app.packageName,
                                            appName: app.appName,
                                            initialIcon: app.appIcon,
                                            size: 42,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  app.appName,
                                                  style: TextStyle(
                                                    color: AppColors.textPrimaryColor(context),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.surfaceVariant(context),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        app.category,
                                                        style: TextStyle(fontSize: 10, color: AppColors.textSecondaryColor(context)),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '${app.launchCount} opens',
                                                      style: TextStyle(fontSize: 11, color: AppColors.textMutedColor(context)),
                                                    ),
                                                    if (hasLimit) ...[
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Limit: ${limit}m',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: isExceeded ? AppColors.danger : AppColors.warning,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                _formatTime(app.durationMinutes),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: isExceeded ? AppColors.danger : AppColors.textPrimaryColor(context),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              InkWell(
                                                onTap: () => _showSetLimitDialog(app),
                                                borderRadius: BorderRadius.circular(6),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(2),
                                                  child: Icon(
                                                    Icons.tune,
                                                    size: 18,
                                                    color: hasLimit ? AppColors.primary : AppColors.textMutedColor(context),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      // Usage Progress Bar
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: usageRatio,
                                          minHeight: 5,
                                          backgroundColor: AppColors.surfaceVariant(context),
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            isExceeded
                                                ? AppColors.danger
                                                : (isDark ? AppColors.accentCyan : AppColors.primary),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelectorStrip(bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // List of past 10 days up to Today
    final days = List.generate(10, (i) => today.subtract(Duration(days: 9 - i)));

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        itemBuilder: (ctx, index) {
          final day = days[index];
          final isSelected = _isSameDay(day, _selectedDate);
          final isToday = _isSameDay(day, today);
          final isYesterday = _isSameDay(day, today.subtract(const Duration(days: 1)));

          String label = DateFormat('E').format(day);
          if (isToday) label = 'Today';
          if (isYesterday) label = 'Yest.';

          return GestureDetector(
            onTap: () => _loadDataForDate(day),
            child: Container(
              width: 58,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isToday ? AppColors.surfaceVariant(context) : AppColors.surface(context)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isToday ? AppColors.primary.withOpacity(0.5) : AppColors.cardBorder(context)),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white70 : AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textPrimaryColor(context),
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

  Widget _summaryMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondaryColor(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimaryColor(context)),
          ),
        ],
      ),
    );
  }
}
