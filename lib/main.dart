import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'screens/main_navigation_screen.dart';

import 'services/schedule_notification_service.dart';
import 'services/usage_tracking_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ScheduleNotificationService.instance.start();
  // Request Android runtime notification permission on startup
  UsageTrackingService.requestNotificationPermission();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const FocusFlowApp(),
    ),
  );
}

class FocusFlowApp extends StatelessWidget {
  const FocusFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'FocusFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const MainNavigationScreen(),
    );
  }
}
