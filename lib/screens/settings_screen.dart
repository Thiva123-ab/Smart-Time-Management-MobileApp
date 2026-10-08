import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../data/local/database_helper.dart';
import '../services/usage_tracking_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hasPermission = false;
  bool _bedtimeMode = false;
  bool _dailyNotifications = true;
  String _geminiApiKey = '';
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPerm = await UsageTrackingService.hasUsagePermission();

    setState(() {
      _hasPermission = hasPerm;
      _bedtimeMode = prefs.getBool('bedtime_mode') ?? false;
      _dailyNotifications = prefs.getBool('daily_notifications') ?? true;
      _geminiApiKey = prefs.getString('gemini_api_key') ?? '';
      _apiKeyController.text = _geminiApiKey;
    });
  }

  Future<void> _savePreference(String key, dynamic val) async {
    final prefs = await SharedPreferences.getInstance();
    if (val is bool) await prefs.setBool(key, val);
    if (val is String) await prefs.setString(key, val);
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Gemini AI Assistant Key', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Optional: Enter your Gemini API Key to enable cloud-powered personalized time management advice and coaching.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'AIzaSy...',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                hintStyle: const TextStyle(color: AppColors.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final key = _apiKeyController.text.trim();
              await _savePreference('gemini_api_key', key);
              setState(() => _geminiApiKey = key);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(key.isEmpty ? 'API Key removed. Heuristic AI coach active.' : 'Gemini API Key saved successfully!'),
                    backgroundColor: AppColors.surfaceVariantDark,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmClearData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Wipe All Local Data?', style: TextStyle(color: AppColors.danger)),
        content: const Text(
          'This will permanently delete all logged app usage, focus sessions, goals, and daily scores stored on this device. This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              await DatabaseHelper.instance.clearAllData();
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All local database records erased.')),
                );
              }
            },
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Header
            const Text('Settings & Privacy', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Local-first controls & device permissions', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),

            // Permission Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _hasPermission ? AppColors.success.withOpacity(0.5) : AppColors.warning.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _hasPermission ? AppColors.success.withOpacity(0.15) : AppColors.warning.withOpacity(0.15),
                    child: Icon(
                      _hasPermission ? Icons.check_circle : Icons.warning_amber,
                      color: _hasPermission ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hasPermission ? 'Usage Access Granted' : 'Usage Access Needed',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _hasPermission
                            ? 'Tracking active via Android UsageStatsManager.'
                            : 'Enable usage stats permission in Android settings.',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (!_hasPermission)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: () async {
                        await UsageTrackingService.requestUsagePermission();
                        final granted = await UsageTrackingService.hasUsagePermission();
                        setState(() => _hasPermission = granted);
                      },
                      child: const Text('Enable', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Wellbeing & Automation
            const Text('Wellbeing & Automation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accentCyan)),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorderDark),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Bedtime Wind-Down Mode', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Dim screen & mute non-essential alerts after 10 PM', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    value: _bedtimeMode,
                    activeColor: AppColors.accentCyan,
                    onChanged: (val) {
                      setState(() => _bedtimeMode = val);
                      _savePreference('bedtime_mode', val);
                    },
                  ),
                  const Divider(color: AppColors.cardBorderDark, height: 1),
                  SwitchListTile(
                    title: const Text('Daily Productivity Prompts', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Receive a morning goal review and evening summary', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    value: _dailyNotifications,
                    activeColor: AppColors.accentCyan,
                    onChanged: (val) {
                      setState(() => _dailyNotifications = val);
                      _savePreference('daily_notifications', val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // AI Assistant Configuration
            const Text('AI Productivity Coach', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accentCyan)),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorderDark),
              ),
              child: ListTile(
                leading: const Icon(Icons.auto_awesome, color: AppColors.accentCyan),
                title: const Text('Gemini API Configuration', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _geminiApiKey.isNotEmpty ? 'Custom API Key active' : 'Offline Heuristic Coach (Default)',
                  style: TextStyle(color: _geminiApiKey.isNotEmpty ? AppColors.success : AppColors.textMuted, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: _showApiKeyDialog,
              ),
            ),
            const SizedBox(height: 24),

            // Privacy & Data
            const Text('Data & Privacy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accentCyan)),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorderDark),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: AppColors.success),
                    title: const Text('Offline-First Guarantee', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('All your app usage logs stay strictly on your device.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ),
                  const Divider(color: AppColors.cardBorderDark, height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: AppColors.danger),
                    title: const Text('Wipe All Local Data', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Delete local SQLite database records completely', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    onTap: _confirmClearData,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // About footer
            Center(
              child: Column(
                children: [
                  Text('FocusFlow v1.0.0', style: TextStyle(color: AppColors.textSecondary.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Take Control of Your Time • Local-First Architecture', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
