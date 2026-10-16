import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local/database_helper.dart';
import '../data/models/app_usage.dart';
import '../data/models/goal.dart';
import '../data/models/time_block.dart';
import '../data/models/daily_note.dart';
import '../data/models/user_profile.dart';
import '../domain/app_category_manager.dart';
import '../domain/productivity_score_engine.dart';
import '../services/usage_tracking_service.dart';

class AIContextData {
  final String dateStr;
  final UserProfile profile;
  final List<AppUsage> usages;
  final int totalMinutes;
  final int productiveMinutes;
  final int distractingMinutes;
  final String topDistractionApp;
  final int topDistractionMinutes;
  final List<Goal> goals;
  final int completedGoalsCount;
  final List<TimeBlock> timeBlocks;
  final int completedBlocksCount;
  final List<DailyNote> notes;
  final int productivityScore;
  final String scoreGrade;
  final String basicAdvice;

  AIContextData({
    required this.dateStr,
    required this.profile,
    required this.usages,
    required this.totalMinutes,
    required this.productiveMinutes,
    required this.distractingMinutes,
    required this.topDistractionApp,
    required this.topDistractionMinutes,
    required this.goals,
    required this.completedGoalsCount,
    required this.timeBlocks,
    required this.completedBlocksCount,
    required this.notes,
    required this.productivityScore,
    required this.scoreGrade,
    required this.basicAdvice,
  });
}

class AIResponse {
  final String text;
  final bool isOnline;
  final List<TimeBlock>? suggestedBlocks;

  AIResponse({
    required this.text,
    required this.isOnline,
    this.suggestedBlocks,
  });
}

class AIProductivityEngine {
  static Future<AIContextData> gatherLiveContext() async {
    final db = DatabaseHelper.instance;
    final today = UsageTrackingService.todayDate;
    final profile = await UserProfile.load();

    final usages = await UsageTrackingService.fetchTodayUsage();
    final goals = await db.getGoalsForDate(today);
    final blocks = await db.getTimeBlocksForDate(today);
    final notes = await db.getDailyNotesForDate(today);

    int total = 0;
    int prod = 0;
    int dist = 0;
    String topDistApp = 'None';
    int topDistMins = 0;

    for (var u in usages) {
      total += u.durationMinutes;
      if (AppCategoryManager.isProductive(u.category)) {
        prod += u.durationMinutes;
      } else if (AppCategoryManager.isDistracting(u.category)) {
        dist += u.durationMinutes;
        if (u.durationMinutes > topDistMins) {
          topDistMins = u.durationMinutes;
          topDistApp = u.appName;
        }
      }
    }

    final completedGoals = goals.where((g) => g.status == 'COMPLETED').length;
    final goalPct = goals.isNotEmpty
        ? (completedGoals * 100) ~/ goals.length
        : (blocks.isNotEmpty
            ? ((blocks.where((b) => b.isCompleted).length * 100) ~/ blocks.length)
            : 75);

    final scoreRes = ProductivityScoreEngine.calculateScore(
      goalCompletionPercentage: goalPct,
      productiveMinutes: prod,
      distractingMinutes: dist,
      focusMinutes: prod > 60 ? 60 : prod,
      streakDays: 4,
    );

    String grade;
    if (scoreRes.totalScore >= 90) {
      grade = 'Grade A+ • Outstanding';
    } else if (scoreRes.totalScore >= 80) {
      grade = 'Grade A • Highly Productive';
    } else if (scoreRes.totalScore >= 70) {
      grade = 'Grade B • Good Momentum';
    } else if (scoreRes.totalScore >= 50) {
      grade = 'Grade C • Balanced';
    } else {
      grade = 'Grade D • Needs Focus';
    }

    return AIContextData(
      dateStr: today,
      profile: profile,
      usages: usages,
      totalMinutes: total,
      productiveMinutes: prod,
      distractingMinutes: dist,
      topDistractionApp: topDistApp,
      topDistractionMinutes: topDistMins,
      goals: goals,
      completedGoalsCount: completedGoals,
      timeBlocks: blocks,
      completedBlocksCount: blocks.where((b) => b.isCompleted).length,
      notes: notes,
      productivityScore: scoreRes.totalScore,
      scoreGrade: grade,
      basicAdvice: scoreRes.advice,
    );
  }

  static Future<AIResponse> getProductivityCoaching(String userPrompt) async {
    final context = await gatherLiveContext();
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('gemini_api_key') ?? '';

    // Check if online Gemini API is configured
    if (apiKey.trim().isNotEmpty) {
      try {
        final onlineText = await _queryGemini(apiKey.trim(), userPrompt, context);
        if (onlineText != null && onlineText.trim().isNotEmpty) {
          final suggested = _extractSuggestedBlocks(onlineText, context);
          return AIResponse(text: onlineText, isOnline: true, suggestedBlocks: suggested);
        }
      } catch (_) {
        // Fallback safely to offline local engine
      }
    }

    // Local Intelligent Productivity Engine
    return _generateLocalIntelligentCoaching(userPrompt, context);
  }

  static Future<String?> _queryGemini(String apiKey, String prompt, AIContextData c) async {
    final models = ['gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-2.0-flash'];

    final topAppsSummary = c.usages.take(5).map((u) => '${u.appName} (${u.durationMinutes}m, ${u.category})').join(', ');
    final goalsSummary = c.goals.map((g) => '${g.title} [${g.status}]').join(', ');
    final blocksSummary = c.timeBlocks.map((b) => '${b.title} (${b.startTime}-${b.endTime}, ${b.isCompleted ? 'Done' : 'Pending'})').join(', ');
    final notesSummary = c.notes.map((n) => '${n.title} (${n.category})').join(', ');

    final systemPrompt = '''You are the intelligent AI Productivity & Time Management Coach for FocusFlow.
User Profile:
- Name: ${c.profile.name}
- Role/Occupation: ${c.profile.role}
- Target Daily Focus Hours: ${c.profile.dailyTargetHours}h

Today's Live Mobile Data (${c.dateStr}):
- Productivity Score: ${c.productivityScore}/100 (${c.scoreGrade})
- Total Screen Time: ${c.totalMinutes} minutes (${c.totalMinutes ~/ 60}h ${c.totalMinutes % 60}m)
- Productive Time: ${c.productiveMinutes} minutes
- Distracting Time: ${c.distractingMinutes} minutes
- Main Distraction App: ${c.topDistractionApp} (${c.topDistractionMinutes} minutes)
- Top 5 Apps Used: ${topAppsSummary.isEmpty ? 'None logged yet' : topAppsSummary}
- Daily Goals: ${c.completedGoalsCount} completed out of ${c.goals.length} total. Goals list: ${goalsSummary.isEmpty ? 'None' : goalsSummary}
- Time Blocks Scheduled: ${c.completedBlocksCount} completed out of ${c.timeBlocks.length}. Blocks: ${blocksSummary.isEmpty ? 'None' : blocksSummary}
- Notes & Ideas Logged Today: ${c.notes.length}. Notes: ${notesSummary.isEmpty ? 'None' : notesSummary}

Instructions:
1. Provide personalized, highly actionable, encouraging, and structured productivity advice based directly on the user's real numbers above.
2. If the user writes in Singlish or Sinhala, understand it thoroughly and reply in friendly Singlish / English with Sinhala guidance so it is crystal clear.
3. If they ask for a schedule, suggest concrete time blocks formatted as:
[SCHEDULE BLOCK]: Title | StartTime | EndTime | DurationMinutes | Category
For example:
[SCHEDULE BLOCK]: Deep Focus Study | 08:30 PM | 09:30 PM | 60 | Work
4. Use clean markdown formatting with bullet points and emojis.''';

    for (var model in models) {
      try {
        final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': '$systemPrompt\n\nUser Message: $prompt'}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.7,
              'maxOutputTokens': 1000,
            }
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
          if (text != null && text.toString().trim().isNotEmpty) {
            return text.toString().trim();
          }
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static AIResponse _generateLocalIntelligentCoaching(String prompt, AIContextData c) {
    final lower = prompt.toLowerCase();
    final h = c.totalMinutes ~/ 60;
    final m = c.totalMinutes % 60;
    final prodH = c.productiveMinutes ~/ 60;
    final prodM = c.productiveMinutes % 60;
    final distH = c.distractingMinutes ~/ 60;
    final distM = c.distractingMinutes % 60;

    // Detect Singlish or Sinhala intent
    final isSinglish = lower.contains('ada') ||
        lower.contains('mata') ||
        lower.contains('karanna') ||
        lower.contains('kohomada') ||
        lower.contains('onee') ||
        lower.contains('wada') ||
        lower.contains('dawas') ||
        lower.contains('heta') ||
        lower.contains('kammali') ||
        lower.contains('kramayak') ||
        lower.contains('sinhala');

    // 1. Analysis / Habits Audit
    if (lower.contains('analyze') ||
        lower.contains('audit') ||
        lower.contains('habit') ||
        lower.contains('performance') ||
        lower.contains('report') ||
        lower.contains('screen time') ||
        lower.contains('ada dawas') ||
        lower.contains('danata') ||
        lower.contains('kohomada')) {
      final text = isSinglish
          ? '''📊 **ඔබගේ අද දවසේ Live Productivity Analysis (${c.dateStr}):**

• **Productivity Score:** **${c.productivityScore} / 100** (${c.scoreGrade})
• **මුළු Screen Time එක:** **${h}h ${m}m**
• **ඵලදායී වැඩ කළ කාලය (Productive):** **${prodH}h ${prodM}m**
• **Distractions වලට ගිය කාලය:** **${distH}h ${distM}m**
• **ප්‍රධාන Distraction App එක:** **${c.topDistractionApp}** (${c.topDistractionMinutes}m)
• **Daily Goals:** ${c.completedGoalsCount}/${c.goals.length} අවසන් කර ඇත.
• **Time Planner Blocks:** ${c.completedBlocksCount}/${c.timeBlocks.length} සම්පූර්ණයි.

💡 **AI Coach ගේ මගපෙන්වීම:**
${c.distractingMinutes > 60 ? '⚠️ ඔබගේ distraction කාලය (${c.topDistractionApp} ඇතුළුව) පැයකට වඩා වැඩියි. දැන්ම Usage tab එකට ගොස් ${c.topDistractionApp} සඳහා 30m limit එකක් දමා, විනාඩි 25ක Pomodoro session එකක් ආරම්භ කරන්න!' : '🌟 ඔබ අද ඉතා හොඳින් කාලය කළමනාකරණය කරගෙන ඇත! ඉතිරි goals ද සම්පූර්ණ කර Score එක 90+ කරගන්න.'}'''
          : '''📊 **Live Productivity Audit for ${c.profile.name} (${c.dateStr}):**

• **Productivity Index:** **${c.productivityScore} / 100** (${c.scoreGrade})
• **Total Device Time:** **${h}h ${m}m**
• **Deep Work & Productive:** **${prodH}h ${prodM}m** (${c.totalMinutes > 0 ? (c.productiveMinutes * 100 ~/ c.totalMinutes) : 0}% of day)
• **Distraction Load:** **${distH}h ${distM}m**
• **Chief Distraction Leaker:** **${c.topDistractionApp}** (${c.topDistractionMinutes}m logged)
• **Goals Tracked:** ${c.completedGoalsCount} of ${c.goals.length} completed
• **Scheduled Blocks:** ${c.completedBlocksCount} of ${c.timeBlocks.length} completed

💡 **Coach Diagnosis & Protocol:**
${c.distractingMinutes > 60 ? '🚨 High distraction detected on **${c.topDistractionApp}**. Suggest configuring an App Limit in the Usage tab and scheduling a 45-minute distraction-free Deep Focus Block right now.' : '🚀 Outstanding digital balance today! You are maintaining strong momentum towards your ${c.profile.dailyTargetHours}h daily target.'}''';

      return AIResponse(text: text, isOnline: false);
    }

    // 2. Schedule Builder / Timetable
    if (lower.contains('plan') ||
        lower.contains('schedule') ||
        lower.contains('routine') ||
        lower.contains('time table') ||
        lower.contains('timetable') ||
        lower.contains('tomorrow') ||
        lower.contains('heta') ||
        lower.contains('wada pilivelak') ||
        lower.contains('study plan')) {
      final now = DateTime.now();
      final startH = (now.hour + 1).clamp(8, 21);
      final startTimeStr = '${startH.toString().padLeft(2, '0')}:00';
      final endH = (startH + 1).clamp(9, 22);
      final endTimeStr = '${endH.toString().padLeft(2, '0')}:30';

      final block1 = TimeBlock(
        title: 'Deep Focus Work Block',
        category: 'Work',
        date: c.dateStr,
        startTime: '$startTimeStr AM',
        endTime: '$endTimeStr AM',
        durationMinutes: 90,
      );

      final block2 = TimeBlock(
        title: 'Goal Review & Catchup',
        category: 'Study',
        date: c.dateStr,
        startTime: '04:00 PM',
        endTime: '05:00 PM',
        durationMinutes: 60,
      );

      final text = isSinglish
          ? '''📅 **ඔබ වෙනුවෙන් සකස් කළ High-Impact Schedule එක:**

• **08:30 AM – 10:00 AM:** 🎯 90m Deep Focus Block (දවසේ අමාරුම හෝ වැදගත්ම වැඩය)
• **10:00 AM – 10:15 AM:** ☕ විවේකය (Screen එකෙන් ඈත් වී වතුර වීදුරුවක් බොන්න)
• **10:15 AM – 12:00 PM:** 📚 2x 45m Pomodoro Study / Work Sessions
• **01:30 PM – 02:30 PM:** ✉️ Admin tasks, messages & light work
• **04:00 PM – 05:00 PM:** 📝 Goals Review & Notes Recap
• **09:30 PM:** 🌙 Digital Wind-Down (Phone එක ඈත් කර නින්දට සූදානම් වීම)

💡 **පහත ඇති "Add to My Schedule" බොත්තමෙන් මෙම block එක ඔබේ Time Planner එකට එක් කරගත හැක!**'''
          : '''📅 **Recommended High-Performance Daily Schedule:**

• **08:30 AM – 10:00 AM:** 🎯 90m Deep Focus Block (Most cognitively demanding goal)
• **10:00 AM – 10:15 AM:** ☕ Rest & Hydrate (Strictly zero screens)
• **10:15 AM – 12:00 PM:** 📚 2x 45m Pomodoro Focus Sessions
• **01:30 PM – 02:30 PM:** ✉️ Communication, emails & administrative tasks
• **04:00 PM – 05:00 PM:** 🎯 Daily Goals Wrap-up & Notes Review
• **09:30 PM:** 🌙 Digital Sunset & Bedtime Wind-Down

💡 **Tap the button below to automatically schedule this focus block into your Time Planner!**''';

      return AIResponse(text: text, isOnline: false, suggestedBlocks: [block1, block2]);
    }

    // 3. Cut Distraction / Phone Addiction
    if (lower.contains('distraction') ||
        lower.contains('reduce') ||
        lower.contains('social') ||
        lower.contains('phone') ||
        lower.contains('addict') ||
        lower.contains('adu karanna') ||
        lower.contains('reels') ||
        lower.contains('shorts') ||
        lower.contains('tiktok')) {
      final text = isSinglish
          ? '''🚫 **Distractions සහ Phone ඇබ්බැහිවීම පාලනය කිරීමට පියවර 3ක්:**

1. **App Limit එකක් දමන්න:**
   ඔබ අද වැඩිපුරම කාලය නාස්ති කර ඇති **${c.topDistractionApp}** (${c.topDistractionMinutes}m) සඳහා Usage tab එකට ගොස් **30 min daily limit** එකක් යොදන්න.
2. **The 5-Second Delay Rule:**
   Social media හෝ YouTube open කිරීමට සිතුන විට තත්පර 5ක් නතර වී "මේක දැන්ම බැලීම ඇත්තටම අවශ්‍යද?" කියා ඔබෙන්ම අසන්න.
3. **Use Focus Mode:**
   Focus tab එකෙන් **Start Deep Focus** ඔබන්න. එමගින් apps block වී නියමිත කාලය තුළ අවධානය රඳවාගත හැක.

🔥 මතක තබාගන්න: කුඩා විනය පුරුදු මහා ප්‍රතිඵල ගෙනදෙයි!'''
          : '''🚫 **Targeted Protocol to Eliminate Digital Distractions:**

1. **Hard Limit on ${c.topDistractionApp}:**
   You have logged **${c.topDistractionMinutes}m** on ${c.topDistractionApp} today. Open **Usage > App Limits** and cap it at 30 minutes per day.
2. **Friction at the Threshold:**
   Move your top 3 distracting apps into a nested folder on your phone's secondary screen to eliminate autopilot tapping.
3. **Use Pomodoro Discipline:**
   Commit to 25 minutes of unbroken work. When the impulse to check feeds strikes, tap "+1 Distraction" in the Focus screen and breathe for 5 seconds before refocusing.''';

      return AIResponse(text: text, isOnline: false);
    }

    // 4. Focus / Deep Work / Motivation
    if (lower.contains('focus') ||
        lower.contains('deep work') ||
        lower.contains('pomodoro') ||
        lower.contains('study') ||
        lower.contains('motivat') ||
        lower.contains('kammali') ||
        lower.contains('lazy') ||
        lower.contains('wada karanna')) {
      final text = isSinglish
          ? '''🔥 **කම්මැලිකම නැති කර Focus වීමට රහස:**

*"ක්‍රියාවට බැසීමෙන් පසු උනන්දුව (motivation) ඉබේම පැමිණේ; උනන්දුව එනතුරු බලා සිටියහොත් කිසිදා වැඩය නොවනු ඇත."*

⚡ **දැන්ම කරන්න පුළුවන් දේ:**
1. ඔබගේ Goals වලින් එකම එක කුඩා කොටසක් තෝරාගන්න.
2. Focus tab එකට ගොස් **25-min Pomodoro** එකක් start කරන්න.
3. Phone එක silent කර මේ විනාඩි 25 තුළ එකම එක කාර්යයක් පමණක් කරන්න.

ඔබට මෙය අනිවාර්යයෙන්ම කළ හැක! 🚀'''
          : '''🔥 **The Science of Unbreakable Focus:**

*"Action precedes motivation, not the other way around."*

⚡ **Immediate Execution Steps:**
1. Pick your highest priority goal from your list right now.
2. Go to **Focus Screen > Pomodoro Focus** and lock in a 25-minute timer.
3. Keep a pen and paper beside you. Whenever a random thought arrives, write it down and return immediately to your work.

You have already logged ${c.totalMinutes} minutes today. Make the next 25 minutes your masterpiece!''';

      return AIResponse(text: text, isOnline: false);
    }

    // 5. Goals Optimization
    if (lower.contains('goal') || lower.contains('target') || lower.contains('iwara')) {
      final text = isSinglish
          ? '''🎯 **Daily Goals සාර්ථක කරගැනීමේ ක්‍රමය:**

• අද ඔබගේ Goals **${c.completedGoalsCount} / ${c.goals.length}** ක් අවසන් කර ඇත.
• තවමත් සම්පූර්ණ නොවූ Goals ඇත්නම්, ඒවායින් එක් goal එකක් තෝරාගෙන ඉදිරි විනාඩි 30 තුළ එය පමණක් ඉලක්ක කරන්න.
• කාලය මදි නම්, Goals tab එකට ගොස් target minutes සුළු වශයෙන් වෙනස් කර සාක්ෂාත් කරගත හැකි මට්ටමක තබාගන්න.

ජයග්‍රහණය යනු කුඩා ඉලක්ක දිනපතා සම්පූර්ණ කරගැනීමයි! 🏆'''
          : '''🎯 **Goal Execution Diagnosis:**

• Today's Completion: **${c.completedGoalsCount} of ${c.goals.length} Goals finished**.
• If you have remaining goals, apply the **Rule of 1**: Dedicate the next 35 minutes exclusively to the single highest-value goal before touching any other task.
• Track your minutes directly in the Goals tab to keep your score above 85!''';

      return AIResponse(text: text, isOnline: false);
    }

    // Default friendly coach response
    final defaultText = isSinglish
        ? '''👋 **හෙලෝ ${c.profile.name}! මම ඔබගේ FocusFlow AI Productivity Coach.**

ඔබගේ අද දවසේ Score එක **${c.productivityScore}/100** (${c.scoreGrade}).
මුළු Screen Time එක **${h}h ${m}m** (Productive: ${prodH}h ${prodM}m | Distractions: ${distH}h ${distM}m).

මට ඔබට උපකාර කළ හැකි දේවල්:
1. 📊 "Analyze my day" – අද දවසේ පුරුදු සහ අඩුපාඩු විශ්ලේෂණය
2. 📅 "Plan my schedule" – හෙට හෝ අද සඳහා smart කාලසටහනක්
3. 🚫 "Cut distractions" – ${c.topDistractionApp} වැනි apps වල කාලය අඩු කිරීම
4. 🔥 "Boost focus" – Pomodoro සහ deep work මගපෙන්වීම

ඔබට අවශ්‍ය කුමක් ගැනද? ඕනෑම දෙයක් අසන්න! 😊'''
        : '''👋 **Hello ${c.profile.name}! I am your FocusFlow AI Productivity Coach.**

Today's Live Snapshot:
• Score: **${c.productivityScore}/100** (${c.scoreGrade})
• Screen Time: **${h}h ${m}m** (Productive: ${prodH}h ${prodM}m, Distractions: ${distH}h ${distM}m)
• Goals Completed: **${c.completedGoalsCount} / ${c.goals.length}**

How can I coach you right now?
1. 📊 "Analyze My Day" for a deep habit audit
2. 📅 "Plan My Schedule" for structured time blocks
3. 🚫 "Cut Distractions" to reclaim lost hours from ${c.topDistractionApp}
4. 🔥 "Deep Work Routine" to conquer procrastination''';

    return AIResponse(text: defaultText, isOnline: false);
  }

  static List<TimeBlock>? _extractSuggestedBlocks(String text, AIContextData c) {
    try {
      final lines = text.split('\n');
      final blocks = <TimeBlock>[];

      for (var line in lines) {
        if (line.contains('[SCHEDULE BLOCK]:')) {
          final parts = line.replaceFirst('[SCHEDULE BLOCK]:', '').split('|');
          if (parts.length >= 4) {
            final title = parts[0].trim();
            final start = parts[1].trim();
            final end = parts[2].trim();
            final duration = int.tryParse(parts[3].trim()) ?? 45;
            final category = parts.length >= 5 ? parts[4].trim() : 'Work';

            blocks.add(
              TimeBlock(
                title: title,
                category: category,
                date: c.dateStr,
                startTime: start,
                endTime: end,
                durationMinutes: duration,
              ),
            );
          }
        }
      }
      return blocks.isNotEmpty ? blocks : null;
    } catch (_) {
      return null;
    }
  }
}
