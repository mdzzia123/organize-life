import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localeKey = 'ol_app_locale';

/// 默认简体中文；null 表示跟随系统
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(const Locale('zh')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    if (code == null) {
      state = const Locale('zh');
      return;
    }
    if (code == 'system') {
      state = null;
      return;
    }
    state = Locale(code);
  }

  Future<void> setLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.setString(_localeKey, 'system');
      state = null;
    } else {
      await prefs.setString(_localeKey, locale.languageCode);
      state = locale;
    }
  }

  Future<void> setLanguageCode(String code) async {
    if (code == 'system') {
      await setLocale(null);
    } else {
      await setLocale(Locale(code));
    }
  }
}

const supportedAppLocales = [
  Locale('zh'),
  Locale('en'),
  Locale('ja'),
  Locale('fr'),
  Locale('de'),
  Locale('es'),
];

Locale resolveLocale(Locale? device, Locale? saved) {
  final target = saved ?? device ?? const Locale('zh');
  for (final l in supportedAppLocales) {
    if (l.languageCode == target.languageCode) return l;
  }
  return const Locale('zh');
}
