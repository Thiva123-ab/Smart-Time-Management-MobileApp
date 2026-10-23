import 'package:flutter/material.dart';
import '../services/bedtime_routine_service.dart';
import '../theme/app_theme.dart';

class BedtimeSettingsSheet extends StatefulWidget {
  const BedtimeSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BedtimeSettingsSheet(),
    );
  }

  @override
  State<BedtimeSettingsSheet> createState() => _BedtimeSettingsSheetState();
}

class _BedtimeSettingsSheetState extends State<BedtimeSettingsSheet> {
  late bool _isEnabled;
  late int _bedHour;
  late int _bedMinute;
  late int _wakeHour;
  late int _wakeMinute;
  late int _leadMinutes;
  late bool _autoAlarms;

  @override
  void initState() {
    super.initState();
    final s = BedtimeRoutineService.instance;
    _isEnabled = s.isEnabled;
    _bedHour = s.bedHour;
    _bedMinute = s.bedMinute;
    _wakeHour = s.wakeHour;
    _wakeMinute = s.wakeMinute;
    _leadMinutes = s.leadMinutes;
    _autoAlarms = s.autoAlarms;
  }

  Future<void> _pickBedtime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _bedHour, minute: _bedMinute),
    );
    if (picked != null) {
      setState(() {
        _bedHour = picked.hour;
        _bedMinute = picked.minute;
      });
    }
  }

  Future<void> _pickWakeup() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _wakeHour, minute: _wakeMinute),
    );
    if (picked != null) {
      setState(() {
        _wakeHour = picked.hour;
        _wakeMinute = picked.minute;
      });
    }
  }

  Future<void> _save() async {
    await BedtimeRoutineService.instance.updateSettings(
      isEnabled: _isEnabled,
      bedHour: _bedHour,
      bedMinute: _bedMinute,
      wakeHour: _wakeHour,
      wakeMinute: _wakeMinute,
      leadMinutes: _leadMinutes,
      autoAlarms: _autoAlarms,
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🌙 Bedtime & Wind-Down routine updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final service = BedtimeRoutineService.instance;

    int startMins = _bedHour * 60 + _bedMinute;
    int endMins = _wakeHour * 60 + _wakeMinute;
    if (endMins <= startMins) endMins += 24 * 60;
    final sleepDurationHours = (endMins - startMins) / 60.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141926) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMutedColor(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title & Master Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.bedtime_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bedtime & Night Routine',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${sleepDurationHours.toStringAsFixed(1)}h sleep target',
                          style: const TextStyle(fontSize: 12, color: AppColors.accentCyan, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: _isEnabled,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) => setState(() => _isEnabled = val),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Time Pickers Row
            Row(
              children: [
                Expanded(
                  child: _timeTile(
                    context,
                    label: 'Target Bedtime',
                    timeStr: service.formattedBedtime,
                    icon: Icons.nightlight_round,
                    color: const Color(0xFF6C5CE7),
                    onTap: _pickBedtime,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _timeTile(
                    context,
                    label: 'Wake-Up Target',
                    timeStr: service.formattedWakeup,
                    icon: Icons.wb_sunny_rounded,
                    color: const Color(0xFFFFA502),
                    onTap: _pickWakeup,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Wind-Down Lead Window
            const Text(
              'Wind-Down Lead Time',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [15, 30, 45, 60].map((mins) {
                final isSelected = _leadMinutes == mins;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _leadMinutes = mins),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceVariant(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.cardBorder(context),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$mins min',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.textSecondaryColor(context),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Auto Alarms Checkbox
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder(context)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, size: 20, color: AppColors.accentCyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule Smart Reminders',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                        Text(
                          'Alerts $_leadMinutes min before bed to begin wind-down',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondaryColor(context)),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _autoAlarms,
                    activeTrackColor: AppColors.accentCyan.withValues(alpha: 0.5),
                    activeThumbColor: AppColors.accentCyan,
                    onChanged: (val) => setState(() => _autoAlarms = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _save,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Save Bedtime Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeTile(
    BuildContext ctx, {
    required String label,
    required String timeStr,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant(ctx),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder(ctx)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondaryColor(ctx)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryColor(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
