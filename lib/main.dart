import 'package:flutter/material.dart';
import 'package:cruze_mobile/screens/login_screen.dart';
import 'package:cruze_mobile/screens/map_screen.dart';

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
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/map': (context) => const MapScreen(),
      },
    );
  }
}

