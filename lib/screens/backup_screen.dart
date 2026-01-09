import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/storage_service.dart';
import '../services/validation_service.dart';
import '../models/app_model.dart';

// Backup Screen
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final StorageService _storage = StorageService();
  bool _isExporting = false;
  bool _isImporting = false;

  Future<void> _exportLibrary() async {
    setState(() => _isExporting = true);

    try {
      final libraryData = await _storage.exportLibrary();
      final jsonString = jsonEncode(libraryData);

      // Get save location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Library',
        fileName: 'byhun_library_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(jsonString);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Library exported successfully to ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting library: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importLibrary() async {
    setState(() => _isImporting = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final libraryData = jsonDecode(jsonString) as Map<String, dynamic>;

        // Confirm import
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import Library'),
            content: Text(
              'This will add ${libraryData['apps'] != null ? (libraryData['apps'] as List).length : 0} apps to your library. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Import'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await _storage.importLibrary(libraryData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Library imported successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing library: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _importByhunFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['byhun'],
        dialogTitle: 'Import .byhun File',
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileData = await file.readAsBytes();

        // Show dialog to get app details
        final nameController = TextEditingController();
        final developerController = TextEditingController();
        final idController = TextEditingController();

        final details = await showDialog<Map<String, String>>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import .byhun File'),
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
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      labelText: 'App ID (Encryption Key)',
                      prefixIcon: Icon(Icons.key),
                      helperText:
                          'Must match the encryption key used to create this file',
                    ),
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
                  if (nameController.text.isNotEmpty &&
                      developerController.text.isNotEmpty &&
                      idController.text.isNotEmpty) {
                    Navigator.pop(
                      context,
                      {
                        'name': nameController.text.trim(),
                        'developer': developerController.text.trim(),
                        'id': idController.text.trim(),
                      },
                    );
                  }
                },
                child: const Text('Import'),
              ),
            ],
          ),
        );

        if (details != null) {
          // Validate file structure
          final validation = await ValidationService.validateByhunFile(
            fileData,
            details['id']!,
          );

          if (!validation.isValid) {
            throw Exception(validation.error ?? 'Invalid file');
          }

          // Check if app already exists
          final existingApps = await _storage.getApps();
          if (existingApps.any((app) => app.id == details['id']!)) {
            throw Exception('App with this ID already exists');
          }

          // Save file and add to library
          await _storage.saveAppFile(details['id']!, fileData);

          final fileSize = fileData.length;
          final hash = await _storage.calculateFileHash(details['id']!);

          final app = ByhunAppModel(
            id: details['id']!,
            name: details['name']!,
            developer: details['developer']!,
            source: 'Local Import',
            addedDate: DateTime.now(),
            fileSizeBytes: fileSize,
            sha256Hash: hash,
          );

          await _storage.addApp(app);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('App imported successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Backup Information',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Export your library to a JSON file to backup your apps list, categories, tags, and settings. This does not include the actual .byhun files.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Export',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportLibrary,
                icon: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload),
                label: Text(_isExporting ? 'Exporting...' : 'Export Library'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Import',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: OutlinedButton.icon(
                onPressed: _isImporting ? null : _importLibrary,
                icon: _isImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(_isImporting ? 'Importing...' : 'Import Library'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: OutlinedButton.icon(
                onPressed: _importByhunFile,
                icon: const Icon(Icons.file_upload),
                label: const Text('Import .byhun File'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
