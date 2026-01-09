import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/encryption_service.dart';
import '../models/app_model.dart';
import '../screens/auth_screen.dart';
import '../screens/add_app_screen.dart';
import '../screens/create_app_screen.dart';
import '../screens/app_webview_screen.dart';
import '../screens/app_details_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/backup_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/github_search_screen.dart';

// Library Screen
class LibraryScreen extends StatefulWidget {
  final Function(String)? onThemeChanged;
  final String currentThemeMode;

  const LibraryScreen({
    super.key,
    this.onThemeChanged,
    this.currentThemeMode = 'system',
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  final TextEditingController _searchController = TextEditingController();
  List<ByhunAppModel> _apps = [];
  List<ByhunAppModel> _filteredApps = [];
  bool _isLoading = true;
  int _currentTabIndex = 0; // 0: All, 1: Favorites, 2: By Category
  String? _selectedCategory;
  List<String> _categories = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _searchController.addListener(_filterApps);
    _loadApps();
    _cleanupTempFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {
      _currentTabIndex = _tabController.index;
      _filterApps();
    });
  }

  Future<void> _cleanupTempFiles() async {
    await _storage.cleanupTempFiles();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    try {
      final apps = await _storage.getApps();
      final categories = await _storage.getAllCategories();
      setState(() {
        _apps = apps;
        _categories = categories;
        _filteredApps = apps;
        _isLoading = false;
      });
      _filterApps();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading apps: $e')),
        );
      }
    }
  }

  void _filterApps() {
    final query = _searchController.text.toLowerCase();
    List<ByhunAppModel> filtered = _apps;

    // Filter by tab
    if (_currentTabIndex == 1) {
      // Favorites
      filtered = filtered.where((app) => app.isFavorite).toList();
    } else if (_currentTabIndex == 2 && _selectedCategory != null) {
      // By Category
      filtered = filtered.where((app) => app.category == _selectedCategory).toList();
    }

    // Filter by search query
    if (query.isNotEmpty) {
      filtered = filtered.where((app) {
        return app.name.toLowerCase().contains(query) ||
            app.developer.toLowerCase().contains(query) ||
            app.category.toLowerCase().contains(query) ||
            app.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    setState(() {
      _filteredApps = filtered;
    });
  }

  Future<void> _logout() async {
    final encryption = EncryptionService();
    await encryption.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting app: $e')),
          );
        }
      }
    }
  }

  Future<void> _launchApp(ByhunAppModel app) async {
    try {
      await _storage.markAppAsUsed(app.id);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppWebViewScreen(app: app),
        ),
      );
      await _loadApps();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Byhun Library'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Favorites'),
            Tab(text: 'Categories'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search on GitHub',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GitHubSearchScreen()),
              );
              if (result == true) {
                _loadApps();
              }
            },
          ),
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
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Statistics',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.backup),
            tooltip: 'Backup & Restore',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              if (result != null && widget.onThemeChanged != null) {
                widget.onThemeChanged!(result);
              }
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
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search apps...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Category selector (only for Categories tab)
          if (_currentTabIndex == 2)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = selected ? category : null;
                        });
                        _filterApps();
                      },
                    ),
                  );
                },
              ),
            ),
          // Apps grid/list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredApps.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.apps_outlined,
                              size: 64,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _currentTabIndex == 1
                                  ? 'No favorite apps'
                                  : _currentTabIndex == 2
                                      ? 'No apps in this category'
                                      : 'No apps found',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Try a different search term'
                                  : 'Tap the + button to add an app',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          return Card(
                            child: InkWell(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AppDetailsScreen(app: app),
                                  ),
                                );
                                await _loadApps();
                              },
                              onLongPress: () => _deleteApp(app),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Stack(
                                      children: [
                                        Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.apps,
                                            size: 32,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                        if (app.isFavorite)
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.yellow,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.star,
                                                size: 12,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      app.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      app.developer,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (app.category.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Chip(
                                        label: Text(
                                          app.category,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _filteredApps.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                final firstApp = _filteredApps[0];
                _launchApp(firstApp);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Launch'),
            )
          : null,
    );
  }
}
