import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/background/background_service.dart';
import 'features/notifications/alert_notification_service.dart';
import 'features/notifications/notification_settings_service.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise notifications and settings before runApp.
  // Wrapped in try-catch so web / desktop preview never hangs on a white screen.
  try {
    await NotificationSettingsService.instance.init();
    await AlertNotificationService.instance.initialise();
    await initBackgroundService();
  } catch (e, stack) {
    debugPrint('Startup service initialization warning: $e\n$stack');
  }

  runApp(
    const ProviderScope(
      child: RemoteCtrlApp(),
    ),
  );
}

class RemoteCtrlApp extends StatelessWidget {
  const RemoteCtrlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RemoteHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
    );
  }
}
