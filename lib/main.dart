import 'package:flutter/material.dart';
import 'widgets/auth_wrapper.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ByhunApp());
}

class ByhunApp extends StatefulWidget {
  const ByhunApp({super.key});

  @override
  State<ByhunApp> createState() => _ByhunAppState();
}

class _ByhunAppState extends State<ByhunApp> {
  final ThemeService _themeService = ThemeService();
  ThemeMode _themeMode = ThemeMode.system;
  String _currentThemeMode = 'system';

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await _themeService.getCurrentThemeMode();
    final modeString = await _themeService.getThemeModeString();
    if (mounted) {
      setState(() {
        _themeMode = mode;
        _currentThemeMode = modeString;
      });
    }
  }

  void _updateTheme(String mode) {
    setState(() {
      _currentThemeMode = mode;
      _themeMode = _themeService.getThemeMode(mode);
    });
    _themeService.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Byhun',
      debugShowCheckedModeBanner: false,
      theme: _themeService.getLightTheme(),
      darkTheme: _themeService.getDarkTheme(),
      themeMode: _themeMode,
      home: AuthWrapper(
        onThemeChanged: _updateTheme,
        currentThemeMode: _currentThemeMode,
      ),
    );
  }
}
