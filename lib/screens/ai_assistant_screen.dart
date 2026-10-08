import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../services/usage_tracking_service.dart';

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  Message({required this.text, required this.isUser, required this.timestamp});
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final List<Message> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final List<String> _quickPrompts = [
    '📊 Analyze My Day',
    '🚫 Reduce Screen Distractions',
    '📅 Plan Tomorrow\'s Focus Blocks',
    '🔥 Boost My Discipline',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      Message(
        text: 'Hello! I am your FocusFlow AI Productivity Coach. I can analyze your daily screentime habits, identify focus leaks, and plan balanced study/work routines. How can I help you take control of your time today?',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _inputController.clear();

    setState(() {
      _messages.add(Message(text: text, isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
    });
    _scrollToBottom();

    // Pull local stats for context
    final db = DatabaseHelper.instance;
    final today = UsageTrackingService.todayDate;
    final usages = await db.getUsageForDate(today);
    final goals = await db.getGoalsForDate(today);

    int totalMinutes = 0;
    int socialMinutes = 0;
    String topApp = 'None';
    int topAppMins = 0;

    for (var u in usages) {
      totalMinutes += u.durationMinutes;
      if (u.category == 'Social Media') socialMinutes += u.durationMinutes;
      if (u.durationMinutes > topAppMins) {
        topAppMins = u.durationMinutes;
        topApp = u.appName;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('gemini_api_key') ?? '';

    String responseText = '';

    if (apiKey.isNotEmpty) {
      try {
        responseText = await _callGeminiApi(
          apiKey: apiKey,
          prompt: text,
          totalMinutes: totalMinutes,
          socialMinutes: socialMinutes,
          topApp: topApp,
          topAppMins: topAppMins,
          goalsCount: goals.length,
          completedGoals: goals.where((g) => g.status == 'COMPLETED').length,
        );
      } catch (e) {
        responseText = _generateHeuristicResponse(text, totalMinutes, socialMinutes, topApp, topAppMins, goals.length);
      }
    } else {
      // Offline heuristic response
      responseText = _generateHeuristicResponse(text, totalMinutes, socialMinutes, topApp, topAppMins, goals.length);
    }

    setState(() {
      _messages.add(Message(text: responseText, isUser: false, timestamp: DateTime.now()));
      _isLoading = false;
    });
    _scrollToBottom();
  }

  String _generateHeuristicResponse(String prompt, int total, int social, String topApp, int topAppMins, int goalsCount) {
    final lower = prompt.toLowerCase();

    if (lower.contains('analyze') || lower.contains('day') || lower.contains('habit')) {
      final h = total ~/ 60;
      final m = total % 60;
      return '''📊 **Today's Screen Time Analysis:**
• **Total Device Time:** ${h}h ${m}m
• **Top App:** $topApp (${topAppMins}m logged)
• **Social Media Load:** ${social}m (${total > 0 ? (social * 100 ~/ total) : 0}% of your day)

💡 **Coach Recommendation:**
${social > 60 ? 'Your social media usage is currently high. Consider setting an App Limit of 45 mins in the Usage tab and scheduling two 25-minute Pomodoro sessions this afternoon.' : 'Your screen time is well balanced today! Keep maintaining this disciplined routine.'}''';
    } else if (lower.contains('distraction') || lower.contains('reduce') || lower.contains('social')) {
      return '''🚫 **Action Plan to Cut Distractions:**
1. **Apply App Limits:** Open FocusFlow > Usage tab and set a 30m hard limit for $topApp.
2. **Use Bedtime Wind-Down:** Stop checking feeds 45 minutes before sleep to reset dopamine baseline.
3. **Log the Urge:** In the Focus tab, whenever you feel the impulse to check feeds, tap "+1 Distraction" and take 3 deep breaths before continuing.''';
    } else if (lower.contains('plan') || lower.contains('tomorrow') || lower.contains('schedule')) {
      return '''📅 **Recommended High-Performance Daily Schedule:**
• **08:30 AM – 10:00 AM:** 90m Deep Focus Block (Hardest creative/study task)
• **10:00 AM – 10:15 AM:** Physical stretch break (No screens)
• **10:15 AM – 12:00 PM:** 2x 45m Pomodoro Study Blocks
• **01:30 PM – 02:30 PM:** Admin, emails, and light communication
• **04:00 PM – 05:00 PM:** Review and wrap up daily goals checklist
• **09:30 PM:** Wind-Down Mode activated 🌙''';
    } else {
      return '''🔥 **Discipline Mindset:**
"Action precedes motivation, not the other way around."

You've already tracked $total minutes today. Pick one single important task right now, tap **Focus > Start Deep Focus**, and give it 25 uninterrupted minutes. You have got this!''';
    }
  }

  Future<String> _callGeminiApi({
    required String apiKey,
    required String prompt,
    required int totalMinutes,
    required int socialMinutes,
    required String topApp,
    required int topAppMins,
    required int goalsCount,
    required int completedGoals,
  }) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey');

    final systemInstruction = '''You are the intelligent in-app productivity coach for FocusFlow, a digital wellbeing and time management mobile app.
Context about the user today:
- Total screen time: $totalMinutes minutes
- Social media time: $socialMinutes minutes
- Top app used: $topApp ($topAppMins minutes)
- Goals: $completedGoals completed out of $goalsCount total.
Provide friendly, actionable, encouraging, and concise markdown productivity advice.''';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': '$systemInstruction\n\nUser Question: $prompt'}
          ]
        }
      ]
    });

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final candidateText = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (candidateText != null && candidateText.isNotEmpty) {
        return candidateText;
      }
    }
    throw Exception('Gemini API request failed: ${res.statusCode}');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: isDark ? AppColors.accentCyan : AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'AI Productivity Coach',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context)),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Quick prompts
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                scrollDirection: Axis.horizontal,
                itemCount: _quickPrompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final prompt = _quickPrompts[index];
                  return ActionChip(
                    label: Text(
                      prompt,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.accentCyan : AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: AppColors.surface(context),
                    side: BorderSide(color: AppColors.cardBorder(context)),
                    onPressed: () => _sendMessage(prompt),
                  );
                },
              ),
            ),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return Align(
                    alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                      decoration: BoxDecoration(
                        color: msg.isUser ? AppColors.primary : AppColors.surface(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: msg.isUser ? Colors.transparent : AppColors.cardBorder(context),
                        ),
                      ),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          color: msg.isUser ? Colors.white : AppColors.textPrimaryColor(context),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark ? AppColors.accentCyan : AppColors.primary,
                  ),
                ),
              ),

            // Bottom Input bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                border: Border(top: BorderSide(color: AppColors.cardBorder(context), width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: TextStyle(color: AppColors.textPrimaryColor(context)),
                      decoration: InputDecoration(
                        hintText: 'Ask coach about your habits, schedule...',
                        hintStyle: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13),
                        filled: true,
                        fillColor: AppColors.surfaceVariant(context),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_upward, size: 20),
                    onPressed: () => _sendMessage(_inputController.text),
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
