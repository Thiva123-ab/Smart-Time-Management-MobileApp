import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../data/models/goal.dart';
import '../data/models/time_budget.dart';
import '../domain/app_category_manager.dart';
import '../services/usage_tracking_service.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Goal> _goals = [];
  List<TimeBudget> _budgets = [];
  Map<String, int> _categoryUsage = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final today = UsageTrackingService.todayDate;

    final goals = await db.getGoalsForDate(today);
    final budgets = await db.getAllBudgets();
    final usages = await db.getUsageForDate(today);

    final catMap = <String, int>{};
    for (var u in usages) {
      catMap[u.category] = (catMap[u.category] ?? 0) + u.durationMinutes;
    }

    setState(() {
      _goals = goals;
      _budgets = budgets;
      _categoryUsage = catMap;
      _isLoading = false;
    });
  }

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  void _showAddGoalDialog() {
    final titleController = TextEditingController();
    final minutesController = TextEditingController(text: '60');
    String selectedCategory = 'Education';

    final categories = ['Education', 'Work', 'Productivity', 'Reading', 'Coding', 'Fitness', 'Other'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Add Daily Goal', style: TextStyle(color: AppColors.textPrimaryColor(context))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  style: TextStyle(color: AppColors.textPrimaryColor(context)),
                  decoration: InputDecoration(
                    labelText: 'Goal Title',
                    hintText: 'e.g. Flutter Study Session',
                    labelStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
                    hintStyle: TextStyle(color: AppColors.textMutedColor(context)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  dropdownColor: AppColors.surface(context),
                  style: TextStyle(color: AppColors.textPrimaryColor(context)),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedCategory = val);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: minutesController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppColors.textPrimaryColor(context)),
                  decoration: InputDecoration(
                    labelText: 'Target Duration',
                    suffixText: 'mins',
                    suffixStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
                    labelStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: AppColors.textMutedColor(context))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                final minutes = int.tryParse(minutesController.text.trim()) ?? 60;

                final newGoal = Goal(
                  title: title,
                  category: selectedCategory,
                  targetMinutes: minutes,
                  completedMinutes: 0,
                  date: UsageTrackingService.todayDate,
                  status: 'PENDING',
                );

                await DatabaseHelper.instance.insertGoal(newGoal);
                Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Add Goal'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetBudgetDialog(TimeBudget budget) {
    final controller = TextEditingController(text: budget.limitMinutes.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${budget.category} Budget', style: TextStyle(color: AppColors.textPrimaryColor(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Set maximum daily budget in minutes:',
              style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textPrimaryColor(context)),
              decoration: InputDecoration(
                labelText: 'Limit (Minutes)',
                suffixText: 'mins',
                suffixStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
                labelStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final newLimit = int.tryParse(controller.text.trim()) ?? budget.limitMinutes;
              final updated = TimeBudget(
                id: budget.id,
                category: budget.category,
                limitMinutes: newLimit,
                date: budget.date,
                enabled: budget.enabled,
              );
              await DatabaseHelper.instance.setBudget(updated);
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleGoal(Goal goal) async {
    final isDone = goal.status == 'COMPLETED';
    final updated = Goal(
      id: goal.id,
      title: goal.title,
      category: goal.category,
      targetMinutes: goal.targetMinutes,
      completedMinutes: isDone ? 0 : goal.targetMinutes,
      date: goal.date,
      status: isDone ? 'PENDING' : 'COMPLETED',
    );
    await DatabaseHelper.instance.updateGoal(updated);
    _loadData();
  }

  Future<void> _deleteGoal(int id) async {
    await DatabaseHelper.instance.deleteGoal(id);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completedCount = _goals.where((g) => g.status == 'COMPLETED').length;
    final goalPercent = _goals.isNotEmpty ? (completedCount / _goals.length) : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Goals & Budgets',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context)),
                      ),
                      const SizedBox(height: 4),
                      Text('Stay disciplined and on track', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13)),
                    ],
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add),
                    tooltip: 'Add Goal',
                    onPressed: _showAddGoalDialog,
                  ),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: isDark ? AppColors.accentCyan : AppColors.primary,
              labelColor: isDark ? AppColors.accentCyan : AppColors.primary,
              unselectedLabelColor: AppColors.textSecondaryColor(context),
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Daily Goals'),
                Tab(text: 'Category Budgets'),
              ],
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 1. Daily Goals Tab
                  ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      // Summary Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cardBorder(context)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: goalPercent,
                                    strokeWidth: 6,
                                    backgroundColor: AppColors.surfaceVariant(context),
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                                  ),
                                  Text(
                                    '${(goalPercent * 100).toInt()}%',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimaryColor(context)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$completedCount of ${_goals.length} Goals Done',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimaryColor(context)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    completedCount == _goals.length && _goals.isNotEmpty
                                        ? 'All goals finished! Outstanding work! 🔥'
                                        : 'Keep going, make every hour count!',
                                    style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (_goals.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(Icons.flag_outlined, size: 48, color: AppColors.textMutedColor(context).withOpacity(0.5)),
                              const SizedBox(height: 12),
                              Text('No goals set for today', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 15)),
                              const SizedBox(height: 6),
                              Text('Tap "+" at the top to add your first goal', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 12)),
                            ],
                          ),
                        )
                      else
                        ..._goals.map((g) {
                          final isDone = g.status == 'COMPLETED';
                          final progress = g.targetMinutes > 0 ? (g.completedMinutes / g.targetMinutes).clamp(0.0, 1.0) : 0.0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDone ? AppColors.success.withOpacity(0.5) : AppColors.cardBorder(context),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                                        color: isDone ? AppColors.success : AppColors.textSecondaryColor(context),
                                        size: 24,
                                      ),
                                      onPressed: () => _toggleGoal(g),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            g.title,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: isDone ? AppColors.textMutedColor(context) : AppColors.textPrimaryColor(context),
                                              decoration: isDone ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${g.category} • Target: ${_formatTime(g.targetMinutes)}',
                                            style: TextStyle(fontSize: 11, color: AppColors.textMutedColor(context)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, size: 20, color: AppColors.textMutedColor(context)),
                                      onPressed: () {
                                        if (g.id != null) _deleteGoal(g.id!);
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: isDone ? 1.0 : progress,
                                    backgroundColor: AppColors.surfaceVariant(context),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDone ? AppColors.success : AppColors.primary,
                                    ),
                                    minHeight: 5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),

                  // 2. Category Budgets Tab
                  ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      Text(
                        'Set maximum daily limits on distraction categories to keep your focus intact.',
                        style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ..._budgets.map((b) {
                        final used = _categoryUsage[b.category] ?? 0;
                        final ratio = b.limitMinutes > 0 ? (used / b.limitMinutes).clamp(0.0, 1.0) : 0.0;
                        final isExceeded = used > b.limitMinutes;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isExceeded ? AppColors.danger.withOpacity(0.6) : AppColors.cardBorder(context),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    b.category,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimaryColor(context)),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '${_formatTime(used)} / ${_formatTime(b.limitMinutes)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isExceeded ? AppColors.danger : AppColors.textSecondaryColor(context),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined, size: 18, color: isDark ? AppColors.accentCyan : AppColors.primary),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _showSetBudgetDialog(b),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  backgroundColor: AppColors.surfaceVariant(context),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isExceeded
                                        ? AppColors.danger
                                        : ratio > 0.8
                                            ? AppColors.warning
                                            : AppColors.primary,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isExceeded
                                    ? '⚠️ Budget exceeded by ${_formatTime(used - b.limitMinutes)}!'
                                    : '${_formatTime((b.limitMinutes - used).clamp(0, 9999))} remaining today',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isExceeded ? AppColors.danger : AppColors.textMutedColor(context),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
