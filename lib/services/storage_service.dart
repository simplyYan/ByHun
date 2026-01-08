import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_model.dart';

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
}
