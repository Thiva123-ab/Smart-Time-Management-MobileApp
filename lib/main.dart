import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'screens/main_navigation_screen.dart';

import 'services/schedule_notification_service.dart';
import 'services/usage_tracking_service.dart';
import 'services/transport_tracking_service.dart';
import 'services/urgent_task_tracking_service.dart';
import 'services/sleep_tracking_service.dart';
import 'services/bedtime_routine_service.dart';
import 'services/focus_audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ScheduleNotificationService.instance.start();
  await TransportTrackingService.instance.init();
  await UrgentTaskTrackingService.instance.init();
  await SleepTrackingService.instance.init();
  await BedtimeRoutineService.instance.init();
  await FocusAudioService.instance.init();
  // Request Android runtime notification permission on startup
  UsageTrackingService.requestNotificationPermission();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: TransportTrackingService.instance),
        ChangeNotifierProvider.value(value: UrgentTaskTrackingService.instance),
        ChangeNotifierProvider.value(value: SleepTrackingService.instance),
        ChangeNotifierProvider.value(value: BedtimeRoutineService.instance),
        ChangeNotifierProvider.value(value: FocusAudioService.instance),
      ],
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
