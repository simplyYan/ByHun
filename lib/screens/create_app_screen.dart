import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/encryption_service.dart';
import '../services/validation_service.dart';

// Create App Screen (for developers)
class CreateAppScreen extends StatefulWidget {
  const CreateAppScreen({super.key});

  @override
  State<CreateAppScreen> createState() => _CreateAppScreenState();
}

class _CreateAppScreenState extends State<CreateAppScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _developerController = TextEditingController();
  final _idController = TextEditingController();
  final EncryptionService _encryption = EncryptionService();
  String? _selectedZipPath;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _developerController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _selectZipFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowedExtensions: ['zip'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedZipPath = result.files.single.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting file: $e')));
      }
    }
  }

  Future<void> _createApp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedZipPath == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a ZIP file')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Read ZIP file
      final zipFile = File(_selectedZipPath!);
      if (!await zipFile.exists()) {
        throw Exception('Selected file does not exist');
      }

      // Verify ZIP contains index.html and validate structure
      final zipBytes = Uint8List.fromList(await zipFile.readAsBytes());
      
      final validation = ValidationService.validateDecryptedZip(zipBytes);
      if (!validation.isValid) {
        throw Exception(validation.error ?? 'Invalid ZIP file structure');
      }

      // Encrypt the ZIP
      final encryptedData = await _encryption.encryptData(
        zipBytes,
        _idController.text.trim(),
      );

      // Validate encrypted file structure
      final encryptedValidation = await ValidationService.validateByhunFile(
        encryptedData,
        _idController.text.trim(),
      );
      if (!encryptedValidation.isValid) {
        throw Exception(encryptedValidation.error ?? 'Encryption validation failed');
      }

      // Get save location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save .byhun file',
        fileName: '${_nameController.text.trim()}.byhun',
      );

      if (result != null) {
        final outputFile = File(result);
        await outputFile.writeAsBytes(encryptedData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App created successfully!')),
          );
          Navigator.pop(context);
        }
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
      appBar: AppBar(title: const Text('Create App')),
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
                  prefixIcon: Icon(Icons.key),
                  helperText: 'This will be used to encrypt the app',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter app ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ZIP File',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The ZIP file must contain an index.html file',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _selectZipFile,
                        icon: const Icon(Icons.folder_open),
                        label: Text(
                          _selectedZipPath == null
                              ? 'Select ZIP File'
                              : _selectedZipPath!
                                    .split(Platform.pathSeparator)
                                    .last,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createApp,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create .byhun File'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
