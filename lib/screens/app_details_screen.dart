import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/app_model.dart';
import '../services/storage_service.dart';
import '../screens/app_webview_screen.dart';

// App Details Screen
class AppDetailsScreen extends StatefulWidget {
  final ByhunAppModel app;

  const AppDetailsScreen({super.key, required this.app});

  @override
  State<AppDetailsScreen> createState() => _AppDetailsScreenState();
}

class _AppDetailsScreenState extends State<AppDetailsScreen> {
  final StorageService _storage = StorageService();
  late ByhunAppModel _app;
  bool _isLoading = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _app = widget.app;
    _loadAppDetails();
  }

  Future<void> _loadAppDetails() async {
    setState(() => _isLoading = true);
    try {
      final apps = await _storage.getApps();
      final app = apps.firstWhere((a) => a.id == _app.id,
          orElse: () => _app);

      // Get file size if not set
      if (app.fileSizeBytes == 0) {
        try {
          final fileSize = await _storage.getAppFileSize(app.id);
          final updatedApp = app.copyWith(fileSizeBytes: fileSize);
          await _storage.updateApp(updatedApp);
          setState(() {
            _app = updatedApp;
          });
        } catch (e) {
          // Ignore errors
        }
      }

      // Calculate hash if not set
      if (app.sha256Hash == null || app.sha256Hash!.isEmpty) {
        try {
          final hash = await _storage.calculateFileHash(app.id);
          final updatedApp = app.copyWith(sha256Hash: hash);
          await _storage.updateApp(updatedApp);
          setState(() {
            _app = updatedApp;
          });
        } catch (e) {
          // Ignore errors
        }
      } else {
        setState(() {
          _app = app;
        });
      }
    } catch (e) {
      // Ignore errors
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateApp() async {
    setState(() => _isUpdating = true);

    try {
      final name = _app.name;
      final developer = _app.developer;

      // Get download URL based on source
      String downloadUrl;
      if (_app.source == 'Github') {
        downloadUrl =
            'https://raw.githubusercontent.com/$developer/$name/refs/heads/main/main.byhun';
      } else {
        downloadUrl =
            'https://meanbyteapp.42web.io/apps/$developer/$name/main.byhun';
      }

      // Try to download
      http.Response? response;
      try {
        response = await http.get(Uri.parse(downloadUrl));
        if (response.statusCode != 200) {
          throw Exception('Failed to download from $downloadUrl');
        }
      } catch (e) {
        // Try alternative source
        if (_app.source == 'Github') {
          final meanByteUrl =
              'https://meanbyteapp.42web.io/apps/$developer/$name/main.byhun';
          try {
            response = await http.get(Uri.parse(meanByteUrl));
            if (response.statusCode == 200) {
              downloadUrl = meanByteUrl;
            } else {
              throw Exception('App not found in both sources');
            }
          } catch (e2) {
            throw Exception('App not found. Please verify the app name and developer.');
          }
        } else {
          throw Exception('App not found. Please verify the app name and developer.');
        }
      }

      // Save new file
      final appData = response.bodyBytes;
      final fileSize = appData.length;
      final hash = await _storage.calculateFileHash(_app.id);
      
      // Re-save file
      await _storage.saveAppFile(_app.id, appData);

      // Update app model
      final updatedApp = _app.copyWith(
        fileSizeBytes: fileSize,
        sha256Hash: hash,
        lastUpdated: DateTime.now(),
        source: downloadUrl.contains('github') ? 'Github' : 'MeanByte',
      );

      await _storage.updateApp(updatedApp);

      if (mounted) {
        setState(() {
          _app = updatedApp;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating app: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _editApp() async {
    final nameController = TextEditingController(text: _app.name);
    final developerController = TextEditingController(text: _app.developer);
    final categoryController = TextEditingController(text: _app.category);
    String category = _app.category;
    List<String> tags = List.from(_app.tags);
    final categories = await _storage.getAllCategories();

    final result = await showDialog<ByhunAppModel>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit App'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'App Name',
                    prefixIcon: Icon(Icons.apps),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: developerController,
                  decoration: const InputDecoration(
                    labelText: 'Developer Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: [
                    ...categories.map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        )),
                    const DropdownMenuItem(
                      value: 'Custom',
                      child: Text('Custom...'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == 'Custom') {
                      // Show custom category dialog
                      showDialog(
                        context: context,
                        builder: (context) {
                          final customController = TextEditingController();
                          return AlertDialog(
                            title: const Text('Custom Category'),
                            content: TextField(
                              controller: customController,
                              decoration: const InputDecoration(
                                hintText: 'Enter category name',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  if (customController.text.isNotEmpty) {
                                    setDialogState(() {
                                      category = customController.text;
                                      categoryController.text = category;
                                    });
                                    Navigator.pop(context);
                                  }
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    } else if (value != null) {
                      setDialogState(() {
                        category = value;
                        categoryController.text = category;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma-separated)',
                    prefixIcon: Icon(Icons.label),
                    helperText: 'e.g., game, utility, productivity',
                  ),
                  onChanged: (value) {
                    tags = value
                        .split(',')
                        .map((tag) => tag.trim())
                        .where((tag) => tag.isNotEmpty)
                        .toList();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final updatedApp = _app.copyWith(
                  name: nameController.text.trim(),
                  developer: developerController.text.trim(),
                  category: category,
                  tags: tags,
                );
                Navigator.pop(context, updatedApp);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        await _storage.updateApp(result);
        setState(() {
          _app = result;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App updated successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating app: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      await _storage.toggleFavorite(_app.id);
      await _loadAppDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _verifyIntegrity() async {
    setState(() => _isLoading = true);
    try {
      final currentHash = await _storage.calculateFileHash(_app.id);
      final isValid = currentHash == _app.sha256Hash;

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(isValid ? 'Integrity Verified' : 'Integrity Check Failed'),
            content: Text(
              isValid
                  ? 'The app file is valid and has not been modified.'
                  : 'The app file may have been modified or corrupted.\n\nStored: ${_app.sha256Hash?.substring(0, 16)}...\nCurrent: ${currentHash.substring(0, 16)}...',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
              if (!isValid)
                TextButton(
                  onPressed: () async {
                    final updatedApp = _app.copyWith(sha256Hash: currentHash);
                    await _storage.updateApp(updatedApp);
                    setState(() {
                      _app = updatedApp;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hash updated')),
                    );
                  },
                  child: const Text('Update Hash'),
                ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error verifying integrity: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _launchApp() async {
    try {
      await _storage.markAppAsUsed(_app.id);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppWebViewScreen(app: _app),
        ),
      );
      await _loadAppDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching app: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[date.month - 1];
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$month $day, $year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(_app.name),
        actions: [
          IconButton(
            icon: Icon(_app.isFavorite ? Icons.star : Icons.star_border),
            onPressed: _toggleFavorite,
            tooltip: 'Toggle Favorite',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editApp,
            tooltip: 'Edit App',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.apps,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _app.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _app.developer,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(color: Colors.grey),
                                ),
                                if (_app.category.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Chip(
                                    label: Text(_app.category),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Launch Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isUpdating ? null : _launchApp,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Launch App'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Update Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _isUpdating ? null : _updateApp,
                      icon: _isUpdating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: Text(_isUpdating ? 'Updating...' : 'Update App'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Information Section
                  Text(
                    'Information',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            'Added Date',
                            _formatDate(_app.addedDate),
                            Icons.calendar_today,
                          ),
                          const Divider(),
                          if (_app.lastUsedDate != null)
                            _buildInfoRow(
                              'Last Used',
                              _formatDate(_app.lastUsedDate!),
                              Icons.access_time,
                            ),
                          if (_app.lastUsedDate != null) const Divider(),
                          if (_app.lastUpdated != null)
                            _buildInfoRow(
                              'Last Updated',
                              _formatDate(_app.lastUpdated!),
                              Icons.update,
                            ),
                          if (_app.lastUpdated != null) const Divider(),
                          _buildInfoRow(
                            'File Size',
                            _app.fileSizeFormatted,
                            Icons.storage,
                          ),
                          const Divider(),
                          _buildInfoRow(
                            'Source',
                            _app.source,
                            Icons.cloud,
                          ),
                          const Divider(),
                          _buildInfoRow(
                            'Usage Count',
                            '${_app.usageCount} times',
                            Icons.trending_up,
                          ),
                          if (_app.sha256Hash != null) ...[
                            const Divider(),
                            _buildInfoRow(
                              'SHA256 Hash',
                              '${_app.sha256Hash!.substring(0, 16)}...',
                              Icons.fingerprint,
                              onTap: _verifyIntegrity,
                              isAction: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_app.tags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Tags',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _app.tags.map((tag) {
                        return Chip(
                          label: Text(tag),
                          avatar: const Icon(Icons.label, size: 16),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
    bool isAction = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isAction
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isAction
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
          ],
        ),
      ),
    );
  }
}
