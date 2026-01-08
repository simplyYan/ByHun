import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/encryption_service.dart';
import '../models/app_model.dart';
import '../screens/auth_screen.dart';
import '../screens/add_app_screen.dart';
import '../screens/create_app_screen.dart';
import '../screens/app_webview_screen.dart';

// Library Screen
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final StorageService _storage = StorageService();
  List<ByhunAppModel> _apps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    try {
      final apps = await _storage.getApps();
      setState(() {
        _apps = apps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading apps: $e')));
      }
    }
  }

  Future<void> _logout() async {
    final encryption = EncryptionService();
    await encryption.logout();
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  Future<void> _deleteApp(ByhunAppModel app) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete App'),
        content: Text('Are you sure you want to delete ${app.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _storage.deleteApp(app.id);
        await _loadApps();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting app: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Byhun Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add App',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddAppScreen()),
              );
              if (result == true) {
                _loadApps();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.build),
            tooltip: 'Create App',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateAppScreen()),
              );
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _apps.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.apps_outlined, size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        'No apps in library',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the + button to add an app',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _apps.length,
                  itemBuilder: (context, index) {
                    final app = _apps[index];
                    return Card(
                      child: InkWell(
                        onTap: () async {
                          try {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AppWebViewScreen(app: app),
                              ),
                            );
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
                        },
                        onLongPress: () => _deleteApp(app),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.apps,
                                  size: 32,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                app.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                app.developer,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
