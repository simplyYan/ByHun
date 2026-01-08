import 'package:flutter/material.dart';
import 'widgets/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ByhunApp());
}

class ByhunApp extends StatelessWidget {
  const ByhunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Byhun',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}
