import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/splash/screens/splash_screen.dart'; // Keep for legacy refs if any
import 'features/auth/screens/auth_check.dart';
import 'features/notifications/services/notification_service.dart';
import 'core/widgets/session_manager.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

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

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController().themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'AirDash',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeMode,
          builder: (context, child) {
             return SessionManager(
               navigatorKey: navigatorKey,
               child: child!
             );
          },
          home: const AuthCheck(),
          routes: {
             // '/': (context) => const AuthCheck(), // 'home' already defines '/'
          },
        );
      },
    );
  }
}
