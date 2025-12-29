import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/splash/presentation/pages/splash_screen.dart'; // Keep for legacy refs if any
import 'features/auth/presentation/pages/auth_check.dart';
import 'features/notifications/data/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
     await Firebase.initializeApp();
  } catch (e) {
     print("Firebase Init Error (Expected if no config): $e");
  }
  
  await Hive.initFlutter();
  await Hive.openBox('filesBox');
  
  // Init Notifications (Register Adapter + Open Box)
  await NotificationService().init();

  runApp(const AirDashApp());
}

class AirDashApp extends StatelessWidget {
  const AirDashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController().themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'AirDash',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeMode,
          home: const AuthCheck(),
        );
      },
    );
  }
}
