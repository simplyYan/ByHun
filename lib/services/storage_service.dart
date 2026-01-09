import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_model.dart';
import 'package:crypto/crypto.dart';

// Private key storage - separate from app data for security
class PrivateKeyStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _keyPrefix = 'byhun_private_key_';

  static Future<void> savePrivateKey(String appId, String privateKey) async {
    // Store the private key securely
    await _storage.write(
      key: '$_keyPrefix$appId',
      value: privateKey,
    );
  }

  static Future<String?> getPrivateKey(String appId) async {
    return await _storage.read(key: '$_keyPrefix$appId');
  }

  static Future<void> deletePrivateKey(String appId) async {
    await _storage.delete(key: '$_keyPrefix$appId');
  }

  static Future<bool> hasPrivateKey(String appId) async {
    final key = await getPrivateKey(appId);
    return key != null && key.isNotEmpty;
  }
}

// Storage Service
class StorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String> _getAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final appDir = Directory('${dir.path}/byhun');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir.path;
  }

  Future<String> _getAppsDir() async {
    final appDir = await _getAppDir();
    final appsDir = Directory('$appDir/apps');
    if (!await appsDir.exists()) {
      await appsDir.create(recursive: true);
    }
    return appsDir.path;
  }

  Future<String> _getTempDir() async {
    final appDir = await _getAppDir();
    final tempDir = Directory('$appDir/temp');
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir.path;
  }

  Future<List<ByhunAppModel>> getApps() async {
    try {
      final appsJson = await _storage.read(key: 'byhun_apps');
      if (appsJson == null) return [];

      final List<dynamic> appsList = jsonDecode(appsJson);
      return appsList.map((json) => ByhunAppModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveApps(List<ByhunAppModel> apps) async {
    try {
      final appsJson = jsonEncode(apps.map((app) => app.toJson()).toList());
      await _storage.write(key: 'byhun_apps', value: appsJson);
    } catch (e) {
      throw Exception('Failed to save apps: $e');
    }
  }

  Future<void> addApp(ByhunAppModel app) async {
    final apps = await getApps();
    apps.add(app);
    await saveApps(apps);
  }

  Future<void> deleteApp(String appId) async {
    final apps = await getApps();
    apps.removeWhere((app) => app.id == appId);
    await saveApps(apps);

    // Delete app file
    try {
      final appsDir = await _getAppsDir();
      final appFile = File('$appsDir/$appId.byhun');
      if (await appFile.exists()) {
        await appFile.delete();
      }
    } catch (e) {
      // Ignore file deletion errors
    }

    // Delete private key if exists
    try {
      await PrivateKeyStorage.deletePrivateKey(appId);
    } catch (e) {
      // Ignore key deletion errors
    }
  }

  Future<String> getAppFilePath(String appId) async {
    final appsDir = await _getAppsDir();
    return '$appsDir/$appId.byhun';
  }

  Future<String> getTempExtractPath(String appId) async {
    final tempDir = await _getTempDir();
    return '$tempDir/$appId';
  }

  Future<void> saveAppFile(String appId, Uint8List data) async {
    final appsDir = await _getAppsDir();
    final appFile = File('$appsDir/$appId.byhun');
    await appFile.writeAsBytes(data);
  }

  Future<Uint8List> loadAppFile(String appId) async {
    final appsDir = await _getAppsDir();
    final appFile = File('$appsDir/$appId.byhun');
    if (!await appFile.exists()) {
      throw Exception('App file not found');
    }
    return await appFile.readAsBytes();
  }

  Future<int> getAppFileSize(String appId) async {
    try {
      final appsDir = await _getAppsDir();
      final appFile = File('$appsDir/$appId.byhun');
      if (await appFile.exists()) {
        return await appFile.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<String> calculateFileHash(String appId) async {
    try {
      final data = await loadAppFile(appId);
      final hash = sha256.convert(data);
      return hash.toString();
    } catch (e) {
      throw Exception('Failed to calculate hash: $e');
    }
  }

  Future<void> updateApp(ByhunAppModel updatedApp) async {
    final apps = await getApps();
    final index = apps.indexWhere((app) => app.id == updatedApp.id);
    if (index != -1) {
      apps[index] = updatedApp;
      await saveApps(apps);
    }
  }

  Future<void> markAppAsUsed(String appId) async {
    final apps = await getApps();
    final app = apps.firstWhere((app) => app.id == appId,
        orElse: () => throw Exception('App not found'));
    final updatedApp = app.copyWith(
      lastUsedDate: DateTime.now(),
      usageCount: app.usageCount + 1,
    );
    await updateApp(updatedApp);
  }

  Future<void> toggleFavorite(String appId) async {
    final apps = await getApps();
    final app = apps.firstWhere((app) => app.id == appId,
        orElse: () => throw Exception('App not found'));
    final updatedApp = app.copyWith(isFavorite: !app.isFavorite);
    await updateApp(updatedApp);
  }

  Future<List<ByhunAppModel>> getFavoriteApps() async {
    final apps = await getApps();
    return apps.where((app) => app.isFavorite).toList();
  }

  Future<List<ByhunAppModel>> getAppsByCategory(String category) async {
    final apps = await getApps();
    return apps.where((app) => app.category == category).toList();
  }

  Future<List<String>> getAllCategories() async {
    final apps = await getApps();
    final categories = apps.map((app) => app.category).toSet().toList();
    categories.sort();
    return categories;
  }

  Future<List<String>> getAllTags() async {
    final apps = await getApps();
    final tags = <String>{};
    for (final app in apps) {
      tags.addAll(app.tags);
    }
    final tagList = tags.toList();
    tagList.sort();
    return tagList;
  }

  Future<Map<String, dynamic>> exportLibrary() async {
    final apps = await getApps();
    return {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'apps': apps.map((app) => app.toJson()).toList(),
    };
  }

  Future<void> importLibrary(Map<String, dynamic> data) async {
    try {
      final appsList = data['apps'] as List<dynamic>;
      final importedApps = appsList
          .map((json) => ByhunAppModel.fromJson(json))
          .toList();

      // Merge with existing apps (don't overwrite by default)
      final existingApps = await getApps();
      final existingIds = existingApps.map((app) => app.id).toSet();

      for (final importedApp in importedApps) {
        if (!existingIds.contains(importedApp.id)) {
          existingApps.add(importedApp);
        }
      }

      await saveApps(existingApps);
    } catch (e) {
      throw Exception('Failed to import library: $e');
    }
  }

  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await _getTempDir();
      final dir = Directory(tempDir);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is Directory) {
            try {
              await entity.delete(recursive: true);
            } catch (e) {
              // Ignore errors for active extractions
            }
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }
}
