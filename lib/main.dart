import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

import 'features/splash/presentation/pages/splash_screen.dart';

import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  await Hive.initFlutter();
  await Hive.openBox('filesBox');
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
          home: const SplashScreen(),
        );
      },
    );
  }
}
