import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';
import '../models/app_model.dart';

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
  String _selectedSource = 'Github';
  final StorageService _storage = StorageService();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _developerController.dispose();
    _idController.dispose();
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
      final appData = response.bodyBytes;
      await _storage.saveAppFile(id, appData);

      // Create app model
      final app = ByhunAppModel(
        id: id,
        name: name,
        developer: developer,
        source: downloadUrl.contains('github') ? 'Github' : 'MeanByte',
        addedDate: DateTime.now(),
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
}
