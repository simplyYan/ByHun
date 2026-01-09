import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../services/settings_service.dart';

// Sandbox Service - Isolated file system for apps
class SandboxService {
  final SettingsService _settingsService = SettingsService();

  Future<String> getSandboxPath(String appId) async {
    final settings = await _settingsService.getSettings();
    String basePath;

    if (settings.sandboxPath.isNotEmpty) {
      basePath = settings.sandboxPath;
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      basePath = '${appDir.path}/byhun/sandbox';
    }

    final sandboxPath = '$basePath/$appId';
    final dir = Directory(sandboxPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return sandboxPath;
  }

  Future<bool> isPathInSandbox(String appId, String filePath) async {
    final sandboxPath = await getSandboxPath(appId);
    final normalizedSandbox = Directory(sandboxPath).absolute.path;
    final normalizedFilePath = Directory(filePath).absolute.path;

    // Check if file path is within sandbox
    return normalizedFilePath.startsWith(normalizedSandbox);
  }

  Future<String> normalizePath(String appId, String path) async {
    // Remove any attempts to escape sandbox (../, ..\\, etc.)
    path = path.replaceAll('../', '').replaceAll('..\\', '');
    path = path.replaceAll('//', '/').replaceAll('\\\\', '\\');

    final sandboxPath = await getSandboxPath(appId);
    
    // If path is absolute, make it relative to sandbox
    if (Platform.isWindows) {
      if (path.contains(':')) {
        // Absolute Windows path, extract relative part
        final parts = path.split(Platform.pathSeparator);
        path = parts.last;
      }
    } else {
      if (path.startsWith('/')) {
        // Absolute Unix path, extract relative part
        final parts = path.split('/');
        path = parts.last;
      }
    }

    // Ensure path is relative to sandbox
    if (path.isEmpty) {
      path = 'file';
    }

    final fullPath = Platform.isWindows
        ? '$sandboxPath\\$path'
        : '$sandboxPath/$path';

    // Validate final path is still in sandbox
    if (!await isPathInSandbox(appId, fullPath)) {
      throw SecurityException('Path outside sandbox: $path');
    }

    return fullPath;
  }

  Future<String> readFile(String appId, String filePath) async {
    final normalizedPath = await normalizePath(appId, filePath);
    final file = File(normalizedPath);

    if (!await file.exists()) {
      throw FileSystemException('File not found: $filePath');
    }

    return await file.readAsString();
  }

  Future<void> writeFile(
    String appId,
    String filePath,
    String content,
  ) async {
    final normalizedPath = await normalizePath(appId, filePath);
    final file = File(normalizedPath);

    // Ensure parent directory exists
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    await file.writeAsString(content);
  }

  Future<void> writeFileBytes(
    String appId,
    String filePath,
    Uint8List bytes,
  ) async {
    final normalizedPath = await normalizePath(appId, filePath);
    final file = File(normalizedPath);

    // Ensure parent directory exists
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    await file.writeAsBytes(bytes);
  }

  Future<void> deleteFile(String appId, String filePath) async {
    final normalizedPath = await normalizePath(appId, filePath);
    final file = File(normalizedPath);

    if (!await file.exists()) {
      throw FileSystemException('File not found: $filePath');
    }

    await file.delete();
  }

  Future<void> moveFile(
    String appId,
    String sourcePath,
    String destPath,
  ) async {
    final normalizedSource = await normalizePath(appId, sourcePath);
    final normalizedDest = await normalizePath(appId, destPath);

    final sourceFile = File(normalizedSource);
    if (!await sourceFile.exists()) {
      throw FileSystemException('Source file not found: $sourcePath');
    }

    // Ensure destination directory exists
    final destFile = File(normalizedDest);
    final parent = destFile.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    await sourceFile.rename(normalizedDest);
  }

  Future<List<String>> listFiles(String appId, String? directoryPath) async {
    final sandboxPath = await getSandboxPath(appId);
    final dirPath = directoryPath != null
        ? await normalizePath(appId, directoryPath)
        : sandboxPath;

    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      throw FileSystemException('Directory not found: $directoryPath');
    }

    final files = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        // Return relative path from sandbox
        final relativePath = entity.path.replaceFirst(sandboxPath, '');
        files.add(relativePath.startsWith(Platform.pathSeparator)
            ? relativePath.substring(1)
            : relativePath);
      }
    }

    return files;
  }

  Future<bool> fileExists(String appId, String filePath) async {
    try {
      final normalizedPath = await normalizePath(appId, filePath);
      final file = File(normalizedPath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getFileInfo(
    String appId,
    String filePath,
  ) async {
    final normalizedPath = await normalizePath(appId, filePath);
    final file = File(normalizedPath);

    if (!await file.exists()) {
      throw FileSystemException('File not found: $filePath');
    }

    final stat = await file.stat();

    return {
      'path': filePath,
      'size': stat.size,
      'modified': stat.modified.toIso8601String(),
      'isFile': stat.type == FileSystemEntityType.file,
      'isDirectory': stat.type == FileSystemEntityType.directory,
    };
  }

  Future<void> clearSandbox(String appId) async {
    final sandboxPath = await getSandboxPath(appId);
    final dir = Directory(sandboxPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
    }
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
  @override
  String toString() => 'SecurityException: $message';
}
