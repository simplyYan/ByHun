import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import '../services/encryption_service.dart';
import '../models/app_settings.dart';
import '../screens/auth_screen.dart';

// Settings Screen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final ThemeService _themeService = ThemeService();
  AppSettings? _settings;
  bool _isLoading = true;
  final Map<String, TextEditingController> _customControllers = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    for (final controller in _customControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _settingsService.getSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;

    try {
      await _settingsService.saveSettings(_settings!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    }
  }

  Future<void> _updateAccountInfo() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'New Username',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_outline),
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
              if (passwordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Passwords do not match'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (usernameController.text.isEmpty &&
                  passwordController.text.isEmpty) {
                Navigator.pop(context);
                return;
              }
              Navigator.pop(
                context,
                {
                  'username': usernameController.text,
                  'password': passwordController.text,
                },
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final encryption = EncryptionService();
        if (result['username']!.isNotEmpty) {
          // Update username would require re-encryption
          // For now, show message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Username change requires re-encryption. Please logout and create a new account.',
              ),
            ),
          );
        }
        if (result['password']!.isNotEmpty) {
          // Update password
          await encryption.saveUserData(
            usernameController.text.isNotEmpty
                ? usernameController.text
                : 'user',
            result['password']!,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating account: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _settings == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        await _saveSettings();
        Navigator.pop(context, _settings!.themeMode);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () async {
                await _saveSettings();
                Navigator.pop(context, _settings!.themeMode);
              },
              tooltip: 'Save Settings',
            ),
          ],
        ),
        body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Theme Mode'),
                    subtitle: Text(_settings!.themeMode),
                    trailing: DropdownButton<String>(
                      value: _settings!.themeMode,
                      items: const [
                        DropdownMenuItem(value: 'system', child: Text('System')),
                        DropdownMenuItem(value: 'light', child: Text('Light')),
                        DropdownMenuItem(value: 'dark', child: Text('Dark')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _settings = _settings!.copyWith(themeMode: value);
                          });
                          _themeService.setThemeMode(value);
                          _saveSettings();
                        }
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Language'),
                    subtitle: const Text('English (Coming Soon)'),
                    trailing: const Icon(Icons.language),
                    enabled: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // WebView Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WebView Settings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Quality'),
                    subtitle: Text('Level ${_settings!.webViewQuality}/5'),
                    trailing: Slider(
                      value: _settings!.webViewQuality.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: 'Level ${_settings!.webViewQuality}',
                      onChanged: (value) {
                        setState(() {
                          _settings = _settings!.copyWith(
                            webViewQuality: value.toInt(),
                          );
                        });
                      },
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Enable Optimizations'),
                    subtitle: const Text('Performance improvements'),
                    value: _settings!.enableOptimizations,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings!.copyWith(
                          enableOptimizations: value,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // General Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'General',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Auto Check Updates'),
                    subtitle: const Text('Check for app updates automatically'),
                    value: _settings!.autoUpdateCheck,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings!.copyWith(
                          autoUpdateCheck: value,
                        );
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Enable Notifications'),
                    subtitle: const Text('Show update notifications'),
                    value: _settings!.enableNotifications,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings!.copyWith(
                          enableNotifications: value,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Developer API Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Developer API',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Allow apps to access file system (restricted to sandbox)',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Enable Developer API'),
                    subtitle: const Text(
                      'WARNING: Only enable if you trust the apps',
                    ),
                    value: _settings!.enableDeveloperAPI,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings!.copyWith(
                          enableDeveloperAPI: value,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Account Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Update Account Info'),
                    subtitle: const Text('Change username or password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _updateAccountInfo,
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Logout'),
                    subtitle: const Text('Sign out of your account'),
                    trailing: const Icon(Icons.logout, color: Colors.red),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text(
                            'Are you sure you want to logout?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Logout', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        final encryption = EncryptionService();
                        await encryption.logout();
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const AuthScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
