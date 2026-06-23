import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'ol_theme_mode';

enum AppThemePreference { system, light, dark }

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, AppThemePreference>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<AppThemePreference> {
  ThemeModeNotifier() : super(AppThemePreference.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeModeKey) ?? 'system';
    state = _fromString(saved);
  }

  AppThemePreference _fromString(String value) {
    switch (value) {
      case 'light':
        return AppThemePreference.light;
      case 'dark':
        return AppThemePreference.dark;
      default:
        return AppThemePreference.system;
    }
  }

  ThemeMode get themeMode => switch (state) {
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
        AppThemePreference.system => ThemeMode.system,
      };

  Future<void> setPreference(AppThemePreference preference) async {
    state = preference;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, preference.name);
  }
}
