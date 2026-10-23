import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/time_block.dart';
import '../services/ai_planner_service.dart';
import '../theme/app_theme.dart';

class SmartSchedulePreviewDialog extends StatefulWidget {
  final DateTime targetDate;
  final List<TimeBlock> existingBlocks;
  final VoidCallback onApplied;

  const SmartSchedulePreviewDialog({
    super.key,
    required this.targetDate,
    required this.existingBlocks,
    required this.onApplied,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime targetDate,
    required List<TimeBlock> existingBlocks,
    required VoidCallback onApplied,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SmartSchedulePreviewDialog(
        targetDate: targetDate,
        existingBlocks: existingBlocks,
        onApplied: onApplied,
      ),
    );
  }

  @override
  State<SmartSchedulePreviewDialog> createState() => _SmartSchedulePreviewDialogState();
}

class _SmartSchedulePreviewDialogState extends State<SmartSchedulePreviewDialog> {
  ScheduleFocusType _selectedFocusType = ScheduleFocusType.balanced;
  bool _isLoading = true;
  SmartScheduleProposal? _proposal;
  final Set<int> _selectedIndices = {};
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() => _isLoading = true);
    final prop = await AiPlannerService.instance.generateDailySchedule(
      targetDate: widget.targetDate,
      existingBlocks: widget.existingBlocks,
      focusType: _selectedFocusType,
    );
    if (mounted) {
      setState(() {
        _proposal = prop;
        _selectedIndices.clear();
        for (int i = 0; i < prop.proposedBlocks.length; i++) {
          _selectedIndices.add(i);
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _applySchedule() async {
    if (_proposal == null) return;
    setState(() => _isApplying = true);

    final toApply = <TimeBlock>[];
    for (int i = 0; i < _proposal!.proposedBlocks.length; i++) {
      if (_selectedIndices.contains(i)) {
        toApply.add(_proposal!.proposedBlocks[i]);
      }
    }

    final count = await AiPlannerService.instance.applyProposalToSchedule(toApply);

    if (mounted) {
      Navigator.pop(context);
      widget.onApplied();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ Successfully scheduled $count AI-optimized time blocks!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Work':
        return AppColors.primary;
      case 'Coding':
        return AppColors.accentCyan;
      case 'Study':
        return const Color(0xFF8B5CF6);
      case 'Fitness':
        return const Color(0xFF10B981);
      case 'Break':
        return const Color(0xFFF59E0B);
      case 'Reading':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = DateFormat('EEEE, MMM d').format(widget.targetDate);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131826) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.cardBorder(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMutedColor(context).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.accentCyan,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Auto-Planner',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    Text(
                      'Smart Schedule for $formattedDate',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: AppColors.textSecondaryColor(context),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Strategy Selector Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStrategyPill('Balanced', ScheduleFocusType.balanced, Icons.tune_rounded),
                const SizedBox(width: 8),
                _buildStrategyPill('Deep Work', ScheduleFocusType.deepWork, Icons.bolt_rounded),
                const SizedBox(width: 8),
                _buildStrategyPill('Exam Prep', ScheduleFocusType.examPrep, Icons.school_rounded),
                const SizedBox(width: 8),
                _buildStrategyPill('Vitality & Health', ScheduleFocusType.healthAndProductivity, Icons.fitness_center_rounded),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Main Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.accentCyan),
                    SizedBox(height: 14),
                    Text('Analyzing free gaps & circadian rhythm...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else if (_proposal != null) ...[
            // Metrics Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricItem(
                    'Focus Time',
                    '${(_proposal!.totalFocusMinutes ~/ 60)}h ${_proposal!.totalFocusMinutes % 60}m',
                    AppColors.primary,
                  ),
                  Container(height: 24, width: 1, color: AppColors.cardBorder(context)),
                  _buildMetricItem(
                    'Recharge',
                    '${_proposal!.totalBreakMinutes}m',
                    const Color(0xFFF59E0B),
                  ),
                  Container(height: 24, width: 1, color: AppColors.cardBorder(context)),
                  _buildMetricItem(
                    'Score Potential',
                    '${_proposal!.projectedProductivityScore}%',
                    AppColors.accentCyan,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // AI Strategy Note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.psychology_outlined, color: AppColors.accentCyan, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _proposal!.strategySummary,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.accentCyan : AppColors.primary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PROPOSED SCHEDULE (${_proposal!.proposedBlocks.length} BLOCKS)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppColors.textMutedColor(context),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_selectedIndices.length == _proposal!.proposedBlocks.length) {
                        _selectedIndices.clear();
                      } else {
                        for (int i = 0; i < _proposal!.proposedBlocks.length; i++) {
                          _selectedIndices.add(i);
                        }
                      }
                    });
                  },
                  child: Text(
                    _selectedIndices.length == _proposal!.proposedBlocks.length ? 'Deselect All' : 'Select All',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Proposed Blocks List
            Expanded(
              child: _proposal!.proposedBlocks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_busy_rounded, size: 40, color: AppColors.textMutedColor(context)),
                          const SizedBox(height: 8),
                          Text(
                            'Your schedule is already packed!\nNo free 30+ minute slots found.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _proposal!.proposedBlocks.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final block = _proposal!.proposedBlocks[index];
                        final isChecked = _selectedIndices.contains(index);
                        final catColor = _getCategoryColor(block.category);

                        return Container(
                          decoration: BoxDecoration(
                            color: isChecked
                                ? AppColors.surface(context)
                                : AppColors.surface(context).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isChecked
                                  ? catColor.withValues(alpha: 0.6)
                                  : AppColors.cardBorder(context),
                            ),
                          ),
                          child: CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            value: isChecked,
                            activeColor: catColor,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIndices.add(index);
                                } else {
                                  _selectedIndices.remove(index);
                                }
                              });
                            },
                            title: Row(
                              children: [
                                Text(
                                  '${block.startTime} - ${block.endTime}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: catColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    block.category,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: catColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                block.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimaryColor(context),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.cardBorder(context)),
                    foregroundColor: AppColors.textSecondaryColor(context),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reroll'),
                  onPressed: _isLoading ? null : _generate,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: _isApplying
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: Text(
                      'Apply ${_selectedIndices.length} Blocks to Day',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: (_isApplying || _selectedIndices.isEmpty) ? null : _applySchedule,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStrategyPill(String title, ScheduleFocusType type, IconData icon) {
    final isSelected = _selectedFocusType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        if (_selectedFocusType != type) {
          setState(() => _selectedFocusType = type);
          _generate();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.accentCyan.withValues(alpha: 0.22) : AppColors.primary.withValues(alpha: 0.12))
              : AppColors.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.accentCyan : AppColors.primary)
                : AppColors.cardBorder(context),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? (isDark ? AppColors.accentCyan : AppColors.primary)
                  : AppColors.textSecondaryColor(context),
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? AppColors.accentCyan : AppColors.primary)
                    : AppColors.textSecondaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textMutedColor(context),
          ),
        ),
      ],
    );
  }
}
