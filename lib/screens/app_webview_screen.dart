import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:archive/archive.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';
import '../services/storage_service.dart';
import '../services/encryption_service.dart';
import '../models/app_model.dart';

// App WebView Screen - Platform-agnostic implementation
class AppWebViewScreen extends StatefulWidget {
  final ByhunAppModel app;

  const AppWebViewScreen({super.key, required this.app});

  @override
  State<AppWebViewScreen> createState() => _AppWebViewScreenState();
}

class _AppWebViewScreenState extends State<AppWebViewScreen> {
  final StorageService _storage = StorageService();
  final EncryptionService _encryption = EncryptionService();

  // Android: webview_flutter
  WebViewController? _androidController;

  // Windows: webview_windows
  WebviewController? _windowsController;

  bool _isLoading = true;
  String? _error;
  String? _extractedPath;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Load app file
      final appData = await _storage.loadAppFile(widget.app.id);

      // Decrypt app
      final decryptedData = await _encryption.decryptData(
        appData,
        widget.app.id,
      );

      // Extract to temp directory
      final tempPath = await _storage.getTempExtractPath(widget.app.id);
      final tempDir = Directory(tempPath);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await tempDir.create(recursive: true);

      // Extract ZIP
      final archive = ZipDecoder().decodeBytes(decryptedData);
      for (final file in archive) {
        final filename = file.name.replaceAll('\\', '/');
        if (filename.isEmpty) continue;

        final filePath = Platform.isWindows
            ? '$tempPath\\${filename.replaceAll('/', '\\')}'
            : '$tempPath/$filename';
        final separator = Platform.isWindows ? '\\' : '/';
        final lastSeparator = filePath.lastIndexOf(separator);
        if (lastSeparator > 0) {
          final fileDir = Directory(filePath.substring(0, lastSeparator));
          if (!await fileDir.exists()) {
            await fileDir.create(recursive: true);
          }
        }

        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }

      // Find index.html
      final indexPath = Platform.isWindows
          ? '$tempPath\\index.html'
          : '$tempPath/index.html';
      final indexFile = File(indexPath);
      if (!await indexFile.exists()) {
        // Try to find it in subdirectories
        final dir = Directory(tempPath);
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('index.html')) {
            _extractedPath = entity.parent.path;
            break;
          }
        }
        if (_extractedPath == null) {
          throw Exception('index.html not found in app');
        }
      } else {
        _extractedPath = tempPath;
      }

      // Initialize webview based on platform
      final fileUrl = Platform.isWindows
          ? 'file:///${_extractedPath!.replaceAll('\\', '/')}/index.html'
          : 'file:///$_extractedPath/index.html';

      if (Platform.isWindows) {
        // Windows: Use webview_windows
        _windowsController = WebviewController();

        await _windowsController!.initialize();
        await _windowsController!.loadUrl(fileUrl);

        // Set loading to false after a short delay (webview_windows doesn't have loading callbacks)
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        });
      } else {
        // Android: Use webview_flutter
        _androidController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (String url) {
                if (mounted) {
                  setState(() => _isLoading = true);
                }
              },
              onPageFinished: (String url) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              onWebResourceError: (WebResourceError error) {
                if (mounted) {
                  setState(() {
                    _error = 'WebView error: ${error.description}';
                    _isLoading = false;
                  });
                }
              },
            ),
          )
          ..loadRequest(Uri.parse(fileUrl));

        // Android loading is handled by NavigationDelegate callbacks
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error initializing app: ${e.toString()}';
          _isLoading = false;
        });

        // Try to handle WebView2 on Windows
        if (Platform.isWindows &&
            (e.toString().contains('WebView') ||
                e.toString().contains('platform') ||
                e.toString().contains('WebView2'))) {
          _showWebView2InstallDialog();
        }
      }
    }
  }

  void _showWebView2InstallDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WebView2 Required'),
        content: const Text(
          'Microsoft WebView2 Runtime is required to run apps on Windows.\n\n'
          'Would you like to download WebView2 now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final url = Uri.parse(
                'https://go.microsoft.com/fwlink/p/?LinkId=2124703',
              );
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Download WebView2'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Dispose controllers
    _windowsController?.dispose();

    // Cleanup temp directory after a delay
    Future.delayed(const Duration(seconds: 5), () async {
      try {
        if (_extractedPath != null) {
          final tempDir = Directory(_extractedPath!);
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.app.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                // Windows WebView
                if (Platform.isWindows && _windowsController != null)
                  Webview(_windowsController!),
                // Android WebView
                if (!Platform.isWindows && _androidController != null)
                  WebViewWidget(controller: _androidController!),
                // Loading indicator
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }
}
