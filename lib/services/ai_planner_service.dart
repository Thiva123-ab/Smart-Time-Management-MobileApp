import 'package:intl/intl.dart';
import '../data/local/database_helper.dart';
import '../data/models/time_block.dart';
import '../data/models/goal.dart';

class ScheduledSlot {
  final int startMinutes;
  final int endMinutes;
  final String title;
  final String category;
  final String notes;

  const ScheduledSlot({
    required this.startMinutes,
    required this.endMinutes,
    required this.title,
    required this.category,
    this.notes = '',
  });

  int get durationMinutes => endMinutes - startMinutes;
}

enum ScheduleFocusType {
  balanced,
  deepWork,
  examPrep,
  healthAndProductivity,
}

class SmartScheduleProposal {
  final List<TimeBlock> proposedBlocks;
  final int totalFocusMinutes;
  final int totalBreakMinutes;
  final String strategySummary;
  final String energyCurveDescription;
  final int projectedProductivityScore;

  const SmartScheduleProposal({
    required this.proposedBlocks,
    required this.totalFocusMinutes,
    required this.totalBreakMinutes,
    required this.strategySummary,
    required this.energyCurveDescription,
    required this.projectedProductivityScore,
  });
}

class AiPlannerService {
  static final AiPlannerService instance = AiPlannerService._internal();
  AiPlannerService._internal();

  /// Parse time strings like "08:30 AM", "8:30", or "14:00" to minutes from midnight
  int parseTimeToMinutes(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      if (clean.contains('AM') || clean.contains('PM')) {
        final format = DateFormat('hh:mm a');
        final dt = format.parse(clean);
        return dt.hour * 60 + dt.minute;
      } else if (clean.contains(':')) {
        final parts = clean.split(':');
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }
    } catch (_) {}
    return 0;
  }

  /// Format minutes from midnight to "hh:mm a"
  String formatMinutesToTime(int totalMinutes) {
    final h = (totalMinutes ~/ 60) % 24;
    final m = totalMinutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${hour12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  /// Generate smart schedule proposal analyzing empty calendar gaps and active goals
  Future<SmartScheduleProposal> generateDailySchedule({
    required DateTime targetDate,
    required List<TimeBlock> existingBlocks,
    ScheduleFocusType focusType = ScheduleFocusType.balanced,
    int wakeUpHour = 7,
    int wakeUpMinute = 30,
    int sleepHour = 23,
    int sleepMinute = 0,
    bool autoAddBreaks = true,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    final db = DatabaseHelper.instance;

    // Fetch active goals for context
    List<Goal> activeGoals = [];
    try {
      activeGoals = await db.getGoalsForDate(dateStr);
      if (activeGoals.isEmpty) {
        // Fallback to today's goals if scheduling for another day
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        activeGoals = await db.getGoalsForDate(todayStr);
      }
    } catch (_) {}

    // Wake and sleep bounds
    final dayStartMinutes = wakeUpHour * 60 + wakeUpMinute; // e.g. 7:30 AM = 450
    final dayEndMinutes = sleepHour * 60 + sleepMinute;     // e.g. 11:00 PM = 1380

    // Collect busy intervals from existing blocks
    final List<List<int>> busyIntervals = [];
    for (final b in existingBlocks) {
      final start = parseTimeToMinutes(b.startTime);
      final end = parseTimeToMinutes(b.endTime);
      if (end > start) {
        busyIntervals.add([start, end]);
      }
    }
    busyIntervals.sort((a, b) => a[0].compareTo(b[0]));

    // Find free gaps of at least 30 minutes
    final List<List<int>> freeGaps = [];
    int cursor = dayStartMinutes;

    for (final interval in busyIntervals) {
      if (interval[0] > cursor && (interval[0] - cursor) >= 30) {
        freeGaps.add([cursor, interval[0]]);
      }
      if (interval[1] > cursor) {
        cursor = interval[1];
      }
    }
    if (cursor < dayEndMinutes && (dayEndMinutes - cursor) >= 30) {
      freeGaps.add([cursor, dayEndMinutes]);
    }

    // Prepare candidate tasks based on focusType and goals
    final candidates = _buildCandidateTasks(focusType, activeGoals);

    final List<TimeBlock> proposedBlocks = [];
    int taskIdx = 0;
    int totalFocusMinutes = 0;
    int totalBreakMinutes = 0;

    for (final gap in freeGaps) {
      int gapStart = gap[0];
      final gapEnd = gap[1];
      int remainingInGap = gapEnd - gapStart;

      while (remainingInGap >= 30 && taskIdx < candidates.length) {
        final candidate = candidates[taskIdx];
        final taskDuration = candidate.durationMinutes.clamp(30, remainingInGap);

        final taskStartMin = gapStart;
        final taskEndMin = taskStartMin + taskDuration;

        final newBlock = TimeBlock(
          title: candidate.title,
          category: candidate.category,
          date: dateStr,
          startTime: formatMinutesToTime(taskStartMin),
          endTime: formatMinutesToTime(taskEndMin),
          durationMinutes: taskDuration,
          isCompleted: false,
          notes: candidate.notes.isNotEmpty
              ? '${candidate.notes} (AI Auto-Planned)'
              : 'Auto-scheduled by AI Auto-Planner based on peak focus rhythm.',
        );

        proposedBlocks.add(newBlock);
        if (candidate.category == 'Break' || candidate.category == 'Personal') {
          totalBreakMinutes += taskDuration;
        } else {
          totalFocusMinutes += taskDuration;
        }

        gapStart = taskEndMin;
        remainingInGap = gapEnd - gapStart;
        taskIdx++;

        // Add 10-15 minute recharge buffer if requested and gap permits
        if (autoAddBreaks && remainingInGap >= 45 && candidate.category != 'Break') {
          final breakDuration = remainingInGap >= 60 ? 15 : 10;
          final breakStart = gapStart;
          final breakEnd = breakStart + breakDuration;

          proposedBlocks.add(TimeBlock(
            title: 'Mindful Break & Hydrate 💧',
            category: 'Break',
            date: dateStr,
            startTime: formatMinutesToTime(breakStart),
            endTime: formatMinutesToTime(breakEnd),
            durationMinutes: breakDuration,
            isCompleted: false,
            notes: 'Rest your eyes, hydrate, and stretch before the next focus block.',
          ));

          totalBreakMinutes += breakDuration;
          gapStart = breakEnd;
          remainingInGap = gapEnd - gapStart;
        }
      }
    }

    // Compute strategy summary
    String strategySummary;
    String energyDesc;
    int score = 85;

    switch (focusType) {
      case ScheduleFocusType.deepWork:
        strategySummary = 'High-Intensity Deep Work: Packed with multi-hour deep focus blocks during morning energy peaks.';
        energyDesc = 'Peak cognitive capacity targeted from 8:30 AM to 11:30 AM and 2:00 PM to 4:00 PM.';
        score = 92;
        break;
      case ScheduleFocusType.examPrep:
        strategySummary = 'Intensive Study & Retention: Focused on active recall sessions interspersed with systematic spaced breaks.';
        energyDesc = 'Cognitive load balanced with 15-minute consolidation rests to prevent mental burnout.';
        score = 90;
        break;
      case ScheduleFocusType.healthAndProductivity:
        strategySummary = 'Sustained Vitality: Balanced split between mental focus, physical movement, and recovery intervals.';
        energyDesc = 'Smooth energy transitions featuring late-afternoon workout and mindful evening decompression.';
        score = 88;
        break;
      case ScheduleFocusType.balanced:
        strategySummary = 'Ultradian Rhythm Schedule: Alternates high-impact productivity blocks with strategic recharges.';
        energyDesc = 'Synchronized with natural circadian energy curves for sustained daily momentum.';
        score = 87;
        break;
    }

    return SmartScheduleProposal(
      proposedBlocks: proposedBlocks,
      totalFocusMinutes: totalFocusMinutes,
      totalBreakMinutes: totalBreakMinutes,
      strategySummary: strategySummary,
      energyCurveDescription: energyDesc,
      projectedProductivityScore: score,
    );
  }

  List<ScheduledSlot> _buildCandidateTasks(ScheduleFocusType type, List<Goal> goals) {
    final List<ScheduledSlot> tasks = [];

    // Prioritize active user goals first
    for (final g in goals) {
      if (g.status != 'COMPLETED') {
        final remaining = (g.targetMinutes - g.completedMinutes).clamp(30, 120);
        tasks.add(ScheduledSlot(
          startMinutes: 0,
          endMinutes: remaining,
          title: '🎯 ${g.title}',
          category: g.category.isNotEmpty ? g.category : 'Study',
          notes: 'Dedicated session for daily goal target: ${g.title}',
        ));
      }
    }

    // Supplement with archetypal blocks based on focus strategy
    switch (type) {
      case ScheduleFocusType.deepWork:
        tasks.addAll([
          const ScheduledSlot(startMinutes: 0, endMinutes: 90, title: 'Deep Work: Core Priorities 🚀', category: 'Work', notes: 'High leverage execution with notifications muted'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 60, title: 'Architecture & Problem Solving 🧠', category: 'Coding', notes: 'Complex logic and documentation'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 45, title: 'Lunch & Cognitive Rest 🥗', category: 'Break', notes: 'Recharge away from digital screens'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 60, title: 'Sprint Execution & Deliverables ⚡', category: 'Work', notes: 'Complete remaining daily backlog items'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 45, title: 'Inbox Zero & Next-Day Planning 📋', category: 'Work', notes: 'Clear communications and organize tomorrow'),
        ]);
        break;

      case ScheduleFocusType.examPrep:
        tasks.addAll([
          const ScheduledSlot(startMinutes: 0, endMinutes: 75, title: 'Subject Mastery: Core Concepts 📚', category: 'Study', notes: 'Active reading and notes consolidation'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 60, title: 'Problem Sets & Practice Exam ✍️', category: 'Study', notes: 'Timed exam questions and self-grading'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 45, title: 'Nutrition & Stretch Break 🍎', category: 'Break', notes: 'Short walk and hydration'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 60, title: 'Flashcards & Memory Recall 💡', category: 'Study', notes: 'Spaced repetition flashcards'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 40, title: 'Summary Notes & Concept Maps 🗺️', category: 'Reading', notes: 'High-level synthesis of key formulas'),
        ]);
        break;

      case ScheduleFocusType.healthAndProductivity:
        tasks.addAll([
          const ScheduledSlot(startMinutes: 0, endMinutes: 75, title: 'Morning Focus: Top Priority ☀️', category: 'Work', notes: 'Tackle the most important task of the day'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 45, title: 'Mid-Morning Project Sprint 💻', category: 'Coding', notes: 'Direct implementation and problem solving'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 60, title: 'Healthy Lunch & Fresh Air 🚶', category: 'Break', notes: 'Nutritious meal and brief outdoors walk'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 60, title: 'Afternoon Focus Session 🎯', category: 'Study', notes: 'Skill acquisition and deep reading'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 50, title: 'Fitness, Cardio & Bodyweight 🏃', category: 'Fitness', notes: 'Physical workout to reset cortisol'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 30, title: 'Evening Reading & Reflection 📖', category: 'Personal', notes: 'Non-fiction book or journal entry'),
        ]);
        break;

      case ScheduleFocusType.balanced:
        tasks.addAll([
          const ScheduledSlot(startMinutes: 0, endMinutes: 90, title: 'Deep Work: Prime Focus 🚀', category: 'Work', notes: 'Peak morning hours devoted to top objective'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 60, title: 'Study & Skill Building 📖', category: 'Study', notes: 'Targeted research, reading, or coursework'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 45, title: 'Lunch & Digital Detox 🍽️', category: 'Break', notes: 'Healthy meal, hydrate, unplug'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 60, title: 'Project Execution & Tasks 💻', category: 'Coding', notes: 'Implementation, reviews, and bug fixing'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 45, title: 'Physical Movement / Workout 🏋️', category: 'Fitness', notes: 'Exercise session to maintain stamina'),
          const ScheduledSlot(startMinutes: 0, endMinutes: 30, title: 'Daily Review & Wind-down 🌙', category: 'Personal', notes: 'Log learnings, celebrate wins, prepare for rest'),
        ]);
        break;
    }

    return tasks;
  }

  /// Bulk insert the proposed blocks into the database
  Future<int> applyProposalToSchedule(List<TimeBlock> blocks) async {
    final db = DatabaseHelper.instance;
    int count = 0;
    for (final block in blocks) {
      await db.insertTimeBlock(block);
      count++;
    }
    return count;
  }
}
