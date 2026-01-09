import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/app_settings.dart';

// Settings Service
class SettingsService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _settingsKey = 'byhun_settings';
  
  AppSettings? _cachedSettings;

  Future<AppSettings> getSettings() async {
    if (_cachedSettings != null) {
      return _cachedSettings!;
    }

    try {
      final settingsJson = await _storage.read(key: _settingsKey);
      if (settingsJson == null) {
        _cachedSettings = AppSettings();
        return _cachedSettings!;
      }

      final Map<String, dynamic> settingsMap = jsonDecode(settingsJson);
      _cachedSettings = AppSettings.fromJson(settingsMap);
      return _cachedSettings!;
    } catch (e) {
      _cachedSettings = AppSettings();
      return _cachedSettings!;
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    try {
      final settingsJson = jsonEncode(settings.toJson());
      await _storage.write(key: _settingsKey, value: settingsJson);
      _cachedSettings = settings;
    } catch (e) {
      throw Exception('Failed to save settings: $e');
    }
  }

  Future<void> updateSettings(AppSettings Function(AppSettings) updater) async {
    final current = await getSettings();
    final updated = updater(current);
    await saveSettings(updated);
  }
}
