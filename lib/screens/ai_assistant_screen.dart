import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../data/models/time_block.dart';
import '../domain/ai_productivity_engine.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isOnline;
  final List<TimeBlock>? suggestedBlocks;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isOnline = false,
    this.suggestedBlocks,
  });
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  AIContextData? _contextData;
  bool _hasApiKey = false;

  final List<String> _quickPrompts = [
    '📊 Analyze My Day',
    '📅 Smart Schedule Builder',
    '🚫 Cut Distractions',
    '🔥 Boost Deep Focus',
    '🎯 Fix Goal Bottlenecks',
    '🇱🇰 Singlish / මගපෙන්වීම',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('gemini_api_key') ?? '';
    final liveContext = await AIProductivityEngine.gatherLiveContext();

    if (mounted) {
      setState(() {
        _hasApiKey = key.trim().isNotEmpty;
        _contextData = liveContext;
        _messages.add(
          ChatMessage(
            text: '''👋 **Hello ${liveContext.profile.name}! I am your FocusFlow AI Productivity Coach.**

Today's Live Snapshot:
• Productivity Score: **${liveContext.productivityScore}/100** (${liveContext.scoreGrade})
• Screen Time: **${liveContext.totalMinutes ~/ 60}h ${liveContext.totalMinutes % 60}m** (Productive: ${liveContext.productiveMinutes}m, Distractions: ${liveContext.distractingMinutes}m)
• Goals Tracked: **${liveContext.completedGoalsCount} of ${liveContext.goals.length}** completed
• Top App: **${liveContext.topDistractionApp}** (${liveContext.topDistractionMinutes}m)

I am ready to analyze your habits, build personalized daily schedules, or provide Singlish/English guidance. Tap a quick prompt below or ask me anything!''',
            isUser: false,
            timestamp: DateTime.now(),
            isOnline: _hasApiKey,
          ),
        );
      });
    }
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
      _messages.add(ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await AIProductivityEngine.getProductivityCoaching(text);
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: response.text,
              isUser: false,
              timestamp: DateTime.now(),
              isOnline: response.isOnline,
              suggestedBlocks: response.suggestedBlocks,
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: '⚠️ An error occurred while generating advice. Please try asking again.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.key_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Gemini AI Key',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FocusFlow includes a powerful offline Intelligent Productivity Coach. To optionally connect cloud Gemini AI, paste your Google AI Studio API key below:',
              style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              obscureText: true,
              style: TextStyle(color: AppColors.textPrimaryColor(context)),
              decoration: InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'AIzaSy...',
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
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final key = controller.text.trim();
              await prefs.setString('gemini_api_key', key);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                setState(() => _hasApiKey = key.isNotEmpty);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(key.isNotEmpty ? '✅ Gemini API Key Connected!' : 'Local AI Engine active'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Save Key'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSuggestedBlockToSchedule(TimeBlock block) async {
    await DatabaseHelper.instance.insertTimeBlock(block);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Scheduled: "${block.title}" added to your Time Planner!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctxData = _contextData;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Productivity Coach',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _hasApiKey ? AppColors.accentCyan : AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _hasApiKey ? 'Gemini Cloud AI' : 'Smart Local AI Brain',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _hasApiKey ? Icons.cloud_done_rounded : Icons.vpn_key_outlined,
              color: _hasApiKey ? AppColors.accentCyan : AppColors.textMutedColor(context),
            ),
            tooltip: 'Configure Gemini API Key',
            onPressed: _showApiKeyDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Live Context Header Banner
            if (ctxData != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  border: Border(bottom: BorderSide(color: AppColors.cardBorder(context), width: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Live Synced: Score ${ctxData.productivityScore}/100 • ${ctxData.totalMinutes ~/ 60}h ${ctxData.totalMinutes % 60}m Screen • ${ctxData.completedGoalsCount}/${ctxData.goals.length} Goals',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final updated = await AIProductivityEngine.gatherLiveContext();
                        if (mounted) setState(() => _contextData = updated);
                      },
                      child: Text(
                        'Refresh',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Quick Prompt Chips
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                scrollDirection: Axis.horizontal,
                itemCount: _quickPrompts.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final prompt = _quickPrompts[index];
                  return ActionChip(
                    label: Text(
                      prompt,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.accentCyan : AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: AppColors.surface(context),
                    side: BorderSide(color: AppColors.cardBorder(context)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onPressed: () => _sendMessage(prompt),
                  );
                },
              ),
            ),

            // Chat Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageBubble(msg, isDark);
                },
              ),
            ),

            // Loading indicator
            if (_isLoading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? AppColors.accentCyan : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'AI Coach is analyzing your habits...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMutedColor(context),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

            // Bottom Input Bar
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
                        hintText: 'Ask in English or Singlish (e.g. ada dawasa analyze karanna)...',
                        hintStyle: TextStyle(color: AppColors.textMutedColor(context), fontSize: 12),
                        filled: true,
                        fillColor: AppColors.surfaceVariant(context),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(_inputController.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: Column(
          crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: msg.isUser ? AppColors.primary : AppColors.surface(context),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(msg.isUser ? 20 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 20),
                ),
                border: Border.all(
                  color: msg.isUser ? Colors.transparent : AppColors.cardBorder(context),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: msg.isUser ? Colors.white : AppColors.textPrimaryColor(context),
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  if (!msg.isUser && msg.suggestedBlocks != null && msg.suggestedBlocks!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'AI Suggested Time Blocks:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...msg.suggestedBlocks!.map((block) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder(context)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      block.title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimaryColor(context),
                                      ),
                                    ),
                                    Text(
                                      '${block.startTime} – ${block.endTime} (${block.durationMinutes}m)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondaryColor(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _addSuggestedBlockToSchedule(block),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  '+ Add',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!msg.isUser) ...[
                  Text(
                    msg.isOnline ? 'Gemini AI' : 'Smart Local AI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: msg.isOnline ? AppColors.accentCyan : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 10, color: AppColors.textMutedColor(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
