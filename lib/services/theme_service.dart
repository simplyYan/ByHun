import 'package:flutter/material.dart';
import '../services/settings_service.dart';

// Theme Service
class ThemeService {
  final SettingsService _settingsService = SettingsService();

  ThemeMode getThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  ThemeData getLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  ThemeData getDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Future<ThemeMode> getCurrentThemeMode() async {
    final settings = await _settingsService.getSettings();
    return getThemeMode(settings.themeMode);
  }

  Future<String> getThemeModeString() async {
    final settings = await _settingsService.getSettings();
    return settings.themeMode;
  }

  Future<void> setThemeMode(String mode) async {
    await _settingsService.updateSettings((settings) {
      return settings.copyWith(themeMode: mode);
    });
  }
}
