import 'dart:io';
import 'dart:convert';
import '../services/sandbox_service.dart';
import '../services/settings_service.dart';

// Developer API Bridge - JavaScript <-> Dart communication
class DeveloperAPIBridge {
  final String appId;
  final SandboxService _sandbox;
  final SettingsService _settingsService;

  DeveloperAPIBridge(this.appId)
      : _sandbox = SandboxService(),
        _settingsService = SettingsService();

  // Generate JavaScript code to inject into WebView
  Future<String> generateBridgeCode() async {
    final settings = await _settingsService.getSettings();
    
    if (!settings.enableDeveloperAPI) {
      return '''
// Developer API is disabled
window.byhunAPI = {
  enabled: false,
  error: "Developer API is disabled in settings"
};
''';
    }

    // Use a simpler approach with postMessage and window.byhunPostMessage
    return '''
(function() {
  if (window.byhunAPI) return; // Already initialized
  
  const API_ENABLED = true;
  const APP_ID = "$appId";
  let messageId = 0;
  const pendingCalls = {};
  
  // Listen for responses from Flutter
  window.addEventListener("message", function(event) {
    if (event.data && event.data.type === "byhunAPIResponse" && event.data.id) {
      const id = event.data.id;
      if (pendingCalls[id]) {
        if (event.data.success) {
          pendingCalls[id].resolve(event.data.result);
        } else {
          pendingCalls[id].reject(new Error(event.data.error));
        }
        delete pendingCalls[id];
      }
    }
  });
  
  function callAPI(type, params) {
    return new Promise((resolve, reject) => {
      if (!API_ENABLED) {
        reject(new Error("API is disabled"));
        return;
      }
      const id = ++messageId;
      pendingCalls[id] = { resolve, reject };
      
      const message = {
        type: "byhunAPICall",
        id: id,
        apiType: type,
        appId: APP_ID,
        params: params
      };
      
      // Use JavaScriptChannel for Flutter
      if (window.byhunPostMessage) {
        window.byhunPostMessage.postMessage(JSON.stringify(message));
      } else {
        console.warn("Byhun API bridge not available - Developer API may be disabled");
        reject(new Error("API bridge not available"));
      }
    });
  }
  
  window.byhunAPI = {
    enabled: API_ENABLED,
    appId: APP_ID,
    
    // System Info
    getSystemInfo: function() {
      return callAPI("getSystemInfo", {});
    },
    
    // File Operations
    readFile: function(path) {
      return callAPI("readFile", { path: path }).then(result => result.content);
    },
    
    writeFile: function(path, content) {
      return callAPI("writeFile", { path: path, content: content });
    },
    
    deleteFile: function(path) {
      return callAPI("deleteFile", { path: path });
    },
    
    moveFile: function(sourcePath, destPath) {
      return callAPI("moveFile", { sourcePath: sourcePath, destPath: destPath });
    },
    
    listFiles: function(directoryPath) {
      return callAPI("listFiles", { directoryPath: directoryPath || null }).then(result => result.files);
    },
    
    fileExists: function(path) {
      return callAPI("fileExists", { path: path }).then(result => result.exists);
    },
    
    getFileInfo: function(path) {
      return callAPI("getFileInfo", { path: path });
    }
  };
  
  console.log("Byhun Developer API initialized for app:", APP_ID);
})();
''';
  }

  // Handle API calls from JavaScript
  Future<Map<String, dynamic>> handleAPICall(String messageJson) async {
    try {
      final message = jsonDecode(messageJson) as Map<String, dynamic>;
      final id = message['id'] as int?;
      final apiType = message['apiType'] as String;
      final appId = message['appId'] as String;
      final params = message['params'] as Map<String, dynamic>? ?? {};

      // Verify app ID matches
      if (appId != this.appId) {
        return {
          'type': 'byhunAPIResponse',
          'id': id,
          'success': false,
          'error': 'App ID mismatch',
        };
      }

      // Check if API is enabled
      final settings = await _settingsService.getSettings();
      if (!settings.enableDeveloperAPI) {
        return {
          'type': 'byhunAPIResponse',
          'id': id,
          'success': false,
          'error': 'Developer API is disabled',
        };
      }

      Map<String, dynamic> result;
      switch (apiType) {
        case 'getSystemInfo':
          result = await _handleGetSystemInfo();
          break;

        case 'readFile':
          final path = params['path'] as String;
          result = await _handleReadFile(path);
          break;

        case 'writeFile':
          final path = params['path'] as String;
          final content = params['content'] as String;
          result = await _handleWriteFile(path, content);
          break;

        case 'deleteFile':
          final path = params['path'] as String;
          result = await _handleDeleteFile(path);
          break;

        case 'moveFile':
          final sourcePath = params['sourcePath'] as String;
          final destPath = params['destPath'] as String;
          result = await _handleMoveFile(sourcePath, destPath);
          break;

        case 'listFiles':
          final directoryPath = params['directoryPath'] as String?;
          result = await _handleListFiles(directoryPath);
          break;

        case 'fileExists':
          final path = params['path'] as String;
          result = await _handleFileExists(path);
          break;

        case 'getFileInfo':
          final path = params['path'] as String;
          result = await _handleGetFileInfo(path);
          break;

        default:
          result = {
            'success': false,
            'error': 'Unknown API call type: $apiType',
          };
      }

      return {
        'type': 'byhunAPIResponse',
        'id': id,
        ...result,
      };
    } catch (e) {
      return {
        'type': 'byhunAPIResponse',
        'id': (messageJson as Map?)?['id'] as int?,
        'success': false,
        'error': 'Error handling API call: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> _handleGetSystemInfo() async {
    try {
      return {
        'success': true,
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
        'sandboxEnabled': true,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _handleReadFile(String path) async {
    try {
      final content = await _sandbox.readFile(appId, path);
      return {
        'success': true,
        'content': content,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _handleWriteFile(
    String path,
    String content,
  ) async {
    try {
      await _sandbox.writeFile(appId, path, content);
      return {
        'success': true,
        'message': 'File written successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _handleDeleteFile(String path) async {
    try {
      await _sandbox.deleteFile(appId, path);
      return {
        'success': true,
        'message': 'File deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _handleMoveFile(
    String sourcePath,
    String destPath,
  ) async {
    try {
      await _sandbox.moveFile(appId, sourcePath, destPath);
      return {
        'success': true,
        'message': 'File moved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _handleListFiles(String? directoryPath) async {
    try {
      final files = await _sandbox.listFiles(appId, directoryPath);
      return {
        'success': true,
        'files': files,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _handleFileExists(String path) async {
    try {
      final exists = await _sandbox.fileExists(appId, path);
      return {
        'success': true,
        'exists': exists,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _handleGetFileInfo(String path) async {
    try {
      final info = await _sandbox.getFileInfo(appId, path);
      return {
        'success': true,
        ...info,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

