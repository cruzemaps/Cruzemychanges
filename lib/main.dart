import 'package:flutter/material.dart';
import 'package:cruze_mobile/screens/alerts_screen.dart';
import 'package:cruze_mobile/screens/login_screen.dart';
import 'package:cruze_mobile/screens/map_screen.dart';
import 'package:cruze_mobile/screens/profile_screen.dart';

void main() {
  runApp(const CruzeApp());
}

class CruzeApp extends StatelessWidget {
  const CruzeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cruze',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFff791a), // Primary Orange
          brightness: Brightness.dark,
          surface: const Color(0xFF121212), // Background Dark
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/map': (context) => const MapScreen(),
        '/alerts': (context) => const AlertsScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

