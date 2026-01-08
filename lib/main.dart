import 'package:flutter/material.dart';
import 'package:cruze_mobile/screens/alerts_screen.dart';
import 'package:cruze_mobile/screens/login_screen.dart';
import 'package:cruze_mobile/screens/map_screen.dart';
import 'package:cruze_mobile/screens/profile_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "env/.env");
  runApp(const CruzeApp());
}

class CruzeApp extends StatelessWidget {
  const CruzeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cruze',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF121212), // Deep Matte Charcoal
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFff791a), // International Orange
          primary: const Color(0xFFff791a),
          secondary: const Color(0xFFD4AF37), // Metallic Gold
          surface: const Color(0xFF121212),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.montserratTextTheme(
          ThemeData.dark().textTheme.apply(
            bodyColor: Colors.white,
            displayColor: const Color(0xFFC0C0C0), // Silver headers
          ),
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

