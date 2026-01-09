import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../services/storage_service.dart';
import '../services/encryption_service.dart';
import '../services/validation_service.dart';
import '../models/app_model.dart';
import 'package:crypto/crypto.dart';

// Add App Screen
class AddAppScreen extends StatefulWidget {
  const AddAppScreen({super.key});

  @override
  State<AddAppScreen> createState() => _AddAppScreenState();
}

class _AddAppScreenState extends State<AddAppScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _developerController = TextEditingController();
  final _idController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  String _selectedSource = 'Github';
  String _selectedCategory = 'Uncategorized';
  List<String> _availableCategories = [];
  final StorageService _storage = StorageService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await _storage.getAllCategories();
    setState(() {
      _availableCategories = categories;
      if (_availableCategories.isNotEmpty) {
        _selectedCategory = _availableCategories[0];
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _developerController.dispose();
    _idController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  String _getDownloadUrl() {
    final name = _nameController.text.trim();
    final developer = _developerController.text.trim();

    if (_selectedSource == 'Github') {
      return 'https://raw.githubusercontent.com/$developer/$name/refs/heads/main/main.byhun';
    } else {
      return 'https://meanbyteapp.42web.io/apps/$developer/$name/main.byhun';
    }
  }

  Future<void> _downloadApp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final developer = _developerController.text.trim();
      final id = _idController.text.trim();

      // Check if app already exists
      final existingApps = await _storage.getApps();
      if (existingApps.any((app) => app.id == id)) {
        throw Exception('App with this ID already exists');
      }

      // Try to download from selected source
      String? downloadUrl = _getDownloadUrl();
      http.Response? response;

      try {
        response = await http.get(Uri.parse(downloadUrl));
        if (response.statusCode != 200) {
          throw Exception('Failed to download from $downloadUrl');
        }
      } catch (e) {
        // If Github fails, try MeanByte
        if (_selectedSource == 'Github') {
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
            throw Exception(
              'App not found. Please verify the app name, developer, and source.',
            );
          }
        } else {
          throw Exception(
            'App not found. Please verify the app name, developer, and source.',
          );
        }
      }

      // Save app file
      final appData = Uint8List.fromList(response.bodyBytes);
      
      // Validate file structure
      final validation = await ValidationService.validateByhunFile(appData, id);
      if (!validation.isValid) {
        throw Exception(validation.error ?? 'Invalid .byhun file structure');
      }

      // Try to decrypt and validate ZIP structure
      // First, try without private key (for public apps)
      String? privateKey;
      bool isPrivate = false;
      try {
        final encryption = EncryptionService();
        final decryptedData = await encryption.decryptData(appData, id);
        final zipValidation = ValidationService.validateDecryptedZip(decryptedData);
        if (!zipValidation.isValid) {
          throw Exception(zipValidation.error ?? 'Invalid ZIP structure');
        }
      } catch (e) {
        // If decryption fails, it might be a private app
        // Check if the error indicates private key is required
        if (e.toString().contains('private key is required')) {
          isPrivate = true;
          // Request private key from user
          privateKey = await _requestPrivateKey(context);
          if (privateKey == null || privateKey.isEmpty) {
            throw Exception('Private key is required for this app');
          }

          // Try again with private key
          try {
            final encryption = EncryptionService();
            final decryptedData = await encryption.decryptData(appData, id, privateKey: privateKey);
            final zipValidation = ValidationService.validateDecryptedZip(decryptedData);
            if (!zipValidation.isValid) {
              throw Exception(zipValidation.error ?? 'Invalid ZIP structure');
            }
          } catch (e2) {
            throw Exception('File validation failed: $e2. Please check the App ID and Private Key.');
          }
        } else {
          throw Exception('File validation failed: $e. Please check the App ID.');
        }
      }

      // Calculate file size and hash
      final fileSize = appData.length;
      await _storage.saveAppFile(id, appData);
      final hash = await _storage.calculateFileHash(id);

      // Store private key securely if app is private
      String? privateKeyHash;
      if (isPrivate && privateKey != null) {
        await PrivateKeyStorage.savePrivateKey(id, privateKey);
        privateKeyHash = sha256.convert(utf8.encode(privateKey)).toString();
      }

      // Parse tags
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      // Create app model
      final app = ByhunAppModel(
        id: id,
        name: name,
        developer: developer,
        source: downloadUrl.contains('github') ? 'Github' : 'MeanByte',
        addedDate: DateTime.now(),
        fileSizeBytes: fileSize,
        sha256Hash: hash,
        category: _selectedCategory,
        tags: tags,
        isPrivate: isPrivate,
        privateKeyHash: privateKeyHash,
      );

      await _storage.addApp(app);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App added successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add App')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'App Name',
                  hintText: 'ElisaLanches',
                  prefixIcon: Icon(Icons.apps),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter app name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _developerController,
                decoration: const InputDecoration(
                  labelText: 'Developer Name',
                  hintText: 'Carlos',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter developer name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: 'App ID (Encryption Key)',
                  hintText: 'Unique identifier',
                  prefixIcon: Icon(Icons.key),
                  helperText: 'This is used as the encryption key',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter app ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedSource,
                decoration: const InputDecoration(
                  labelText: 'Source',
                  prefixIcon: Icon(Icons.cloud_download),
                ),
                items: const [
                  DropdownMenuItem(value: 'Github', child: Text('Github')),
                  DropdownMenuItem(value: 'MeanByte', child: Text('MeanByte')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedSource = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: [
                  ..._availableCategories.map((cat) => DropdownMenuItem(
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
                                  setState(() {
                                    _selectedCategory = customController.text.trim();
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
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                  hintText: 'e.g., game, utility, productivity',
                  prefixIcon: Icon(Icons.label),
                  helperText: 'Separate multiple tags with commas',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Colors.grey[600],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _importByhunFile,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import .byhun File'),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _downloadApp,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add App'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        final fileData = Uint8List.fromList(await file.readAsBytes());

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
          setState(() => _isLoading = true);

          try {
            // Validate file structure
            final validation = await ValidationService.validateByhunFile(
              fileData,
              details['id']!,
            );

            if (!validation.isValid) {
              throw Exception(validation.error ?? 'Invalid file');
            }

            // Try to decrypt and validate ZIP structure
            // First, try without private key (for public apps)
            String? privateKey;
            bool isPrivate = false;
            try {
              final encryption = EncryptionService();
              final decryptedData = await encryption.decryptData(
                fileData,
                details['id']!,
              );
              final zipValidation =
                  ValidationService.validateDecryptedZip(decryptedData);
              if (!zipValidation.isValid) {
                throw Exception(
                  zipValidation.error ?? 'Invalid ZIP structure',
                );
              }
            } catch (e) {
              // If decryption fails, it might be a private app
              if (e.toString().contains('private key is required')) {
                isPrivate = true;
                // Request private key from user
                privateKey = await _requestPrivateKey(context);
                if (privateKey == null || privateKey.isEmpty) {
                  throw Exception('Private key is required for this app');
                }

                // Try again with private key
                try {
                  final encryption = EncryptionService();
                  final decryptedData = await encryption.decryptData(
                    fileData,
                    details['id']!,
                    privateKey: privateKey,
                  );
                  final zipValidation =
                      ValidationService.validateDecryptedZip(decryptedData);
                  if (!zipValidation.isValid) {
                    throw Exception(
                      zipValidation.error ?? 'Invalid ZIP structure',
                    );
                  }
                } catch (e2) {
                  throw Exception(
                    'File validation failed: $e2. Please check the App ID and Private Key.',
                  );
                }
              } else {
                throw Exception(
                  'File validation failed: $e. Please check the App ID.',
                );
              }
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

            // Store private key securely if app is private
            String? privateKeyHash;
            if (isPrivate && privateKey != null) {
              await PrivateKeyStorage.savePrivateKey(details['id']!, privateKey);
              privateKeyHash = sha256.convert(utf8.encode(privateKey)).toString();
            }

            // Parse tags
            final tags = _tagsController.text
                .split(',')
                .map((tag) => tag.trim())
                .where((tag) => tag.isNotEmpty)
                .toList();

            final app = ByhunAppModel(
              id: details['id']!,
              name: details['name']!,
              developer: details['developer']!,
              source: 'Local Import',
              addedDate: DateTime.now(),
              fileSizeBytes: fileSize,
              sha256Hash: hash,
              category: _selectedCategory,
              tags: tags,
              isPrivate: isPrivate,
              privateKeyHash: privateKeyHash,
            );

            await _storage.addApp(app);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('App imported successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context, true);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } finally {
            if (mounted) {
              setState(() => _isLoading = false);
            }
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

  // Helper method to request private key from user
  Future<String?> _requestPrivateKey(BuildContext context) async {
    final privateKeyController = TextEditingController();
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Private Key Required'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This is a private/commercial app that requires a private key to decrypt.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: privateKeyController,
                decoration: const InputDecoration(
                  labelText: 'Private Key',
                  prefixIcon: Icon(Icons.key),
                  helperText:
                      'Enter the private key provided by the app developer',
                ),
                obscureText: true,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The private key is required to decrypt and use this app. Contact the developer if you don\'t have it.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final key = privateKeyController.text.trim();
              if (key.isNotEmpty) {
                Navigator.pop(context, key);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
