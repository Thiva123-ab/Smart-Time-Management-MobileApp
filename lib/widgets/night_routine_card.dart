import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bedtime_routine_service.dart';
import '../services/sleep_tracking_service.dart';
import '../theme/app_theme.dart';
import 'bedtime_settings_sheet.dart';

class NightRoutineCard extends StatelessWidget {
  const NightRoutineCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer2<BedtimeRoutineService, SleepTrackingService>(
      builder: (ctx, bedtime, sleep, _) {
        if (!bedtime.isEnabled) return const SizedBox.shrink();

        final isTrackingSleep = sleep.isTracking;
        final isWindDown = bedtime.isWindDownActive;
        final minsUntil = bedtime.minutesUntilBedtime;
        final hoursUntil = minsUntil ~/ 60;
        final remainingMins = minsUntil % 60;

        final timeCountdownStr = hoursUntil > 0
            ? '${hoursUntil}h ${remainingMins}m'
            : '${remainingMins}m';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isWindDown
                  ? (isDark
                      ? [const Color(0xFF23173B), const Color(0xFF130F26)]
                      : [const Color(0xFFF3E8FF), const Color(0xFFE9D5FF)])
                  : (isDark
                      ? [const Color(0xFF181C2B), const Color(0xFF10131F)]
                      : [const Color(0xFFF8FAFC), Colors.white]),
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isWindDown
                  ? const Color(0xFF6C5CE7).withValues(alpha: 0.6)
                  : AppColors.cardBorder(context),
              width: isWindDown ? 1.5 : 1.0,
            ),
            boxShadow: isWindDown
                ? [
                    BoxShadow(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isWindDown
                              ? const Color(0xFF6C5CE7).withValues(alpha: 0.3)
                              : AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isWindDown ? Icons.nights_stay_rounded : Icons.bedtime_rounded,
                          size: 18,
                          color: isWindDown ? const Color(0xFFA29BFE) : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isWindDown ? 'Wind-Down Active' : 'Evening Sleep Routine',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryColor(context),
                                ),
                              ),
                              if (isWindDown) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6C5CE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'REST',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            isWindDown
                                ? 'Target Bedtime: ${bedtime.formattedBedtime}'
                                : 'Bedtime in $timeCountdownStr • ${bedtime.formattedBedtime}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    color: AppColors.textMutedColor(context),
                    tooltip: 'Configure Routine',
                    onPressed: () => BedtimeSettingsSheet.show(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Content Advice
              Text(
                isWindDown
                    ? 'Protect your REM cycles: Dim screens, disconnect from notifications, and begin physical wind-down.'
                    : 'Targeting ${bedtime.targetSleepDurationHours.toStringAsFixed(1)}h of restorative sleep tonight (Wake: ${bedtime.formattedWakeup}).',
                style: TextStyle(
                  fontSize: 12,
                  color: isWindDown
                      ? (isDark ? const Color(0xFFDDD6FE) : const Color(0xFF5B21B6))
                      : AppColors.textMutedColor(context),
                ),
              ),
              const SizedBox(height: 14),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isWindDown ? const Color(0xFF6C5CE7) : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: Icon(
                        isTrackingSleep ? Icons.stop_rounded : Icons.bedtime_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isTrackingSleep ? 'Manage Sleep (${sleep.formattedElapsed})' : 'Start Sleep Session',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () async {
                        if (isTrackingSleep) {
                          final block = await sleep.wakeUpAndSave();
                          if (context.mounted && block != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🛌 Sleep recorded: ${block.durationMinutes ~/ 60}h ${block.durationMinutes % 60}m logged!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } else {
                          await sleep.startSleep();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🌙 Sleep session started! Sleep well.'),
                                backgroundColor: Color(0xFF6C5CE7),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.cardBorder(context)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => BedtimeSettingsSheet.show(context),
                    child: Text(
                      'Schedule',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
