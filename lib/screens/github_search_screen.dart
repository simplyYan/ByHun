import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';
import '../services/validation_service.dart';
import '../services/encryption_service.dart';
import '../models/app_model.dart';

// GitHub Search Screen
class GitHubSearchScreen extends StatefulWidget {
  const GitHubSearchScreen({super.key});

  @override
  State<GitHubSearchScreen> createState() => _GitHubSearchScreenState();
}

class _GitHubSearchScreenState extends State<GitHubSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StorageService _storage = StorageService();
  List<GitHubRepository> _repositories = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchGitHub() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a search query')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _repositories = [];
    });

    try {
      // Build GitHub search URL
      // Format: https://github.com/search?q=+language%3AHTML+query+Byhun&type=repositories
      final encodedQuery = Uri.encodeComponent('+language:HTML $query Byhun');
      final url =
          'https://api.github.com/search/repositories?q=$encodedQuery&type=Repositories&sort=stars&order=desc';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>;

        final repos = items.map((item) {
          final repo = item as Map<String, dynamic>;
          final owner = repo['owner'] as Map<String, dynamic>;
          return GitHubRepository(
            name: repo['name'] as String,
            owner: owner['login'] as String,
            description: repo['description'] as String? ?? '',
            stars: repo['stargazers_count'] as int,
            url: repo['html_url'] as String,
          );
        }).toList();

        setState(() {
          _repositories = repos;
          _isSearching = false;
        });
      } else {
        throw Exception('GitHub API error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching GitHub: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addRepository(GitHubRepository repo) async {
    // Show dialog to get app ID
    final idController = TextEditingController();
    final categoryController = TextEditingController(text: 'Uncategorized');
    final tagsController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${repo.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  labelText: 'App ID (Encryption Key)',
                  prefixIcon: Icon(Icons.key),
                  helperText:
                      'Required: This is used to decrypt the app file',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                  prefixIcon: Icon(Icons.label),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This app will be downloaded from:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'https://raw.githubusercontent.com/${repo.owner}/${repo.name}/refs/heads/main/main.byhun',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue,
                      fontFamily: 'monospace',
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
              if (idController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('App ID is required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(
                context,
                {
                  'id': idController.text.trim(),
                  'category': categoryController.text.trim(),
                  'tags': tagsController.text.trim(),
                },
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);

      try {
        // Check if app already exists
        final existingApps = await _storage.getApps();
        if (existingApps.any((app) => app.id == result['id']!)) {
          throw Exception('App with this ID already exists');
        }

        // Try to download from GitHub
        final downloadUrl =
            'https://raw.githubusercontent.com/${repo.owner}/${repo.name}/refs/heads/main/main.byhun';

        http.Response? response;
        try {
          response = await http.get(Uri.parse(downloadUrl));
          if (response.statusCode != 200) {
            throw Exception('File not found at: $downloadUrl');
          }
        } catch (e) {
          throw Exception(
            'Failed to download app. Make sure the repository has a main.byhun file in the main branch.',
          );
        }

        // Validate file
        final appData = response.bodyBytes;
        final validation = await ValidationService.validateByhunFile(
          appData,
          result['id']!,
        );

        if (!validation.isValid) {
          throw Exception(validation.error ?? 'Invalid .byhun file structure');
        }

        // Try to decrypt and validate ZIP structure
        try {
          final encryption = EncryptionService();
          final decryptedData = await encryption.decryptData(
            appData,
            result['id']!,
          );
          final zipValidation =
              ValidationService.validateDecryptedZip(decryptedData);
          if (!zipValidation.isValid) {
            throw Exception(
              zipValidation.error ?? 'Invalid ZIP structure',
            );
          }
        } catch (e) {
          throw Exception(
            'File validation failed: $e. Please check the App ID.',
          );
        }

        // Save file and add to library
        await _storage.saveAppFile(result['id']!, appData);

        final fileSize = appData.length;
        final hash = await _storage.calculateFileHash(result['id']!);

        // Parse tags
        final tags = result['tags']!
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();

        final app = ByhunAppModel(
          id: result['id']!,
          name: repo.name,
          developer: repo.owner,
          source: 'Github',
          addedDate: DateTime.now(),
          fileSizeBytes: fileSize,
          sha256Hash: hash,
          category: result['category']!,
          tags: tags,
        );

        await _storage.addApp(app);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('App added successfully!'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search GitHub'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for apps... (e.g., "food app")',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _repositories = [];
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _searchGitHub(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  onPressed: _isSearching ? null : _searchGitHub,
                  tooltip: 'Search',
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _repositories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 64,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isSearching
                                  ? 'Searching...'
                                  : 'Enter a search query to find apps on GitHub',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                            if (!_isSearching) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Example: "food app", "game", "productivity"',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey[500]),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _repositories.length,
                        itemBuilder: (context, index) {
                          final repo = _repositories[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.code,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                repo.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${repo.owner}/${repo.name}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (repo.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      repo.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 16,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${repo.stars}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle),
                                onPressed: () => _addRepository(repo),
                                tooltip: 'Add to library',
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class GitHubRepository {
  final String name;
  final String owner;
  final String description;
  final int stars;
  final String url;

  GitHubRepository({
    required this.name,
    required this.owner,
    required this.description,
    required this.stars,
    required this.url,
  });
}
