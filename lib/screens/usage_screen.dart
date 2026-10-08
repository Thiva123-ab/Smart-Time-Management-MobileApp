import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../data/models/app_usage.dart';
import '../data/models/time_budget.dart';
import '../domain/app_category_manager.dart';
import '../services/usage_tracking_service.dart';

class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  List<AppUsage> _allApps = [];
  List<AppUsage> _filteredApps = [];
  Map<String, int> _appLimits = {};
  String _selectedCategory = 'All';
  String _searchQuery = '';
  int _totalUsageMinutes = 0;
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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final apps = await UsageTrackingService.fetchTodayUsage();
    final db = DatabaseHelper.instance;
    await db.saveAppUsageList(apps);

    final limits = await db.getAllAppLimits();
    final limitMap = <String, int>{};
    for (var l in limits) {
      if (l.enabled) {
        limitMap[l.packageName] = l.limitMinutes;
      }
    }

    int total = 0;
    for (var a in apps) {
      total += a.durationMinutes;
    }

    setState(() {
      _allApps = apps;
      _appLimits = limitMap;
      _totalUsageMinutes = total;
      _isLoading = false;
    });

    _filterList();
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
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  void _showSetLimitDialog(AppUsage app) {
    final currentLimit = _appLimits[app.packageName] ?? 60;
    final controller = TextEditingController(text: currentLimit.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Daily Limit for ${app.appName}', style: const TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set a maximum daily usage time in minutes:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Limit (Minutes)',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                suffixText: 'mins',
                suffixStyle: const TextStyle(color: AppColors.textSecondary),
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
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final newLimit = int.tryParse(controller.text.trim()) ?? 60;
              final limitObj = AppLimit(
                packageName: app.packageName,
                appName: app.appName,
                limitMinutes: newLimit,
                date: UsageTrackingService.todayDate,
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
                    backgroundColor: AppColors.surfaceVariantDark,
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Usage',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text('Today\'s device activity', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorderDark),
                    ),
                    child: Text(
                      _formatTime(_totalUsageMinutes),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentCyan, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: TextField(
                onChanged: (val) {
                  _searchQuery = val;
                  _filterList();
                },
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search applications...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Category Chips
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                    backgroundColor: AppColors.surfaceDark,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.cardBorderDark,
                    ),
                    onSelected: (val) {
                      setState(() => _selectedCategory = cat);
                      _filterList();
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // App List
            Expanded(
              child: RefreshIndicator(
                color: AppColors.accentCyan,
                onRefresh: _loadData,
                child: _filteredApps.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 100),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                const Text('No apps found', style: TextStyle(color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isExceeded
                                  ? AppColors.danger.withOpacity(0.6)
                                  : AppColors.cardBorderDark,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColors.surfaceVariantDark,
                                    child: Text(
                                      app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: AppColors.accentCyan,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          app.appName,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.cardBorderDark,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                app.category,
                                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${app.launchCount} opens',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                            ),
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
                                          color: isExceeded ? AppColors.danger : AppColors.textPrimary,
                                        ),
                                      ),
                                      if (hasLimit)
                                        Text(
                                          'Limit: ${_formatTime(limit)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isExceeded ? AppColors.danger : AppColors.textMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.timer_outlined,
                                      size: 20,
                                      color: hasLimit ? AppColors.accentCyan : AppColors.textMuted,
                                    ),
                                    tooltip: 'Set Limit',
                                    onPressed: () => _showSetLimitDialog(app),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: usageRatio,
                                  backgroundColor: AppColors.surfaceVariantDark,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isExceeded
                                        ? AppColors.danger
                                        : AppCategoryManager.isProductive(app.category)
                                            ? AppColors.success
                                            : AppCategoryManager.isDistracting(app.category)
                                                ? AppColors.warning
                                                : AppColors.primary,
                                  ),
                                  minHeight: 6,
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
}
