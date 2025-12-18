import 'package:flutter/material.dart';

class ThemeController {
  // Singleton instance
  static final ThemeController _instance = ThemeController._internal();
  factory ThemeController() => _instance;
  ThemeController._internal();

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  void toggleTheme() {
    if (themeMode.value == ThemeMode.light) {
      themeMode.value = ThemeMode.dark;
    } else {
      themeMode.value = ThemeMode.light;
    }
  }

  void setTheme(ThemeMode mode) {
    themeMode.value = mode;
  }
}
