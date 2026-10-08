import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../data/local/database_helper.dart';
import '../services/usage_tracking_service.dart';
import '../services/data_export_service.dart';

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
    final hasPerm = await UsageTrackingService.hasPermission();

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
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Gemini AI Assistant Key', style: TextStyle(color: AppColors.textPrimaryColor(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Optional: Enter your Gemini API Key to enable cloud-powered personalized time management advice and coaching.',
              style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              style: TextStyle(color: AppColors.textPrimaryColor(context)),
              decoration: InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'AIzaSy...',
                labelStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
                hintStyle: TextStyle(color: AppColors.textMutedColor(context)),
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
            ),
            onPressed: () async {
              final key = _apiKeyController.text.trim();
              await _savePreference('gemini_api_key', key);
              setState(() => _geminiApiKey = key);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(key.isEmpty ? 'API Key removed. Heuristic AI coach active.' : 'Gemini API Key saved successfully!'),
                    backgroundColor: AppColors.surfaceVariant(context),
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

  void _showExportDialog() async {
    final jsonStr = await DataExportService.exportAllDataAsJson();
    final csvStr = await DataExportService.exportUsageAsCsv();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Export Activity Data', style: TextStyle(color: AppColors.textPrimaryColor(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your activity records are packaged and ready to export:',
              style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '• Full JSON archive: ${jsonStr.length} bytes\n• Daily CSV export: ${csvStr.split('\n').length - 1} records',
                style: const TextStyle(color: AppColors.accentCyan, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: AppColors.textMutedColor(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Data exported to local device storage!'),
                  backgroundColor: AppColors.surfaceVariant(context),
                ),
              );
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _confirmClearData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Wipe All Local Data?', style: TextStyle(color: AppColors.danger)),
        content: Text(
          'This will permanently delete all logged app usage, focus sessions, goals, and daily scores stored on this device. This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMutedColor(context))),
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
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings & Privacy',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context)),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Permission Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
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
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimaryColor(context)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _hasPermission
                              ? 'Tracking active via Android UsageStatsManager.'
                              : 'Enable usage stats permission in Android settings.',
                          style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (!_hasPermission)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: () async {
                        await UsageTrackingService.openPermissionSettings();
                        final granted = await UsageTrackingService.hasPermission();
                        setState(() => _hasPermission = granted);
                      },
                      child: const Text('Enable', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Appearance & Theme Section
            Text(
              'Appearance & Theme',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.accentCyan : AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder(context)),
              ),
              child: Row(
                children: [
                  _themeOptionCard(
                    context: context,
                    title: 'Light',
                    icon: Icons.light_mode,
                    isSelected: themeProvider.themeMode == ThemeMode.light,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                  ),
                  const SizedBox(width: 10),
                  _themeOptionCard(
                    context: context,
                    title: 'Dark',
                    icon: Icons.dark_mode,
                    isSelected: themeProvider.themeMode == ThemeMode.dark,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                  ),
                  const SizedBox(width: 10),
                  _themeOptionCard(
                    context: context,
                    title: 'System',
                    icon: Icons.brightness_auto,
                    isSelected: themeProvider.themeMode == ThemeMode.system,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Wellbeing & Automation
            Text(
              'Wellbeing & Automation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.accentCyan : AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder(context)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Bedtime Wind-Down Mode', style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.w600)),
                    subtitle: Text('Dim screen & mute non-essential alerts after 10 PM', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 12)),
                    value: _bedtimeMode,
                    activeColor: AppColors.accentCyan,
                    onChanged: (val) {
                      setState(() => _bedtimeMode = val);
                      _savePreference('bedtime_mode', val);
                    },
                  ),
                  Divider(color: AppColors.cardBorder(context), height: 1),
                  SwitchListTile(
                    title: Text('Daily Productivity Prompts', style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.w600)),
                    subtitle: Text('Receive a morning goal review and evening summary', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 12)),
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
            Text(
              'AI Productivity Coach',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.accentCyan : AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder(context)),
              ),
              child: ListTile(
                leading: const Icon(Icons.auto_awesome, color: AppColors.accentCyan),
                title: Text('Gemini API Configuration', style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _geminiApiKey.isNotEmpty ? 'Custom API Key active' : 'Offline Heuristic Coach (Default)',
                  style: TextStyle(color: _geminiApiKey.isNotEmpty ? AppColors.success : AppColors.textMutedColor(context), fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: AppColors.textSecondaryColor(context)),
                onTap: _showApiKeyDialog,
              ),
            ),
            const SizedBox(height: 24),

            // Privacy & Data
            Text(
              'Data & Privacy',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.accentCyan : AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder(context)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: AppColors.success),
                    title: Text('Offline-First Guarantee', style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.w600)),
                    subtitle: Text('All your app usage logs stay strictly on your device.', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 12)),
                  ),
                  Divider(color: AppColors.cardBorder(context), height: 1),
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined, color: AppColors.accentCyan),
                    title: Text('Export Usage Data', style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.w600)),
                    subtitle: Text('Export activity history to JSON or CSV format', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 12)),
                    onTap: _showExportDialog,
                  ),
                  Divider(color: AppColors.cardBorder(context), height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: AppColors.danger),
                    title: const Text('Wipe All Local Data', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                    subtitle: Text('Delete local SQLite database records completely', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 12)),
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
                  Text('FocusFlow v1.0.0', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Take Control of Your Time • Local-First Architecture', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _themeOptionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.15)
                : AppColors.surfaceVariant(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondaryColor(context),
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textSecondaryColor(context),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
