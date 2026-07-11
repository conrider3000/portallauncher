import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

  /// Loads theme mode from shared preferences.
  static Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeStr = prefs.getString('theme_mode') ?? 'system';
      if (themeStr == 'dark') {
        themeModeNotifier.value = ThemeMode.dark;
      } else if (themeStr == 'light') {
        themeModeNotifier.value = ThemeMode.light;
      } else {
        themeModeNotifier.value = ThemeMode.system;
      }
    } catch (_) {
      themeModeNotifier.value = ThemeMode.system;
    }
  }

  /// Toggles theme mode and saves the choice in shared preferences.
  static Future<void> toggleTheme(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', mode.name);
    } catch (_) {}
  }
}
