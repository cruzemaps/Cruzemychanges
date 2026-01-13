import 'package:flutter/material.dart';
import 'package:cruze_mobile/screens/alerts_screen.dart';
import 'package:cruze_mobile/screens/login_screen.dart';
import 'package:cruze_mobile/screens/map_screen.dart';
import 'package:cruze_mobile/screens/profile_screen.dart';
import 'package:cruze_mobile/widgets/nav_bar.dart'; // Import custom NavBar
import 'package:cruze_mobile/services/navigation_service.dart'; // Import NavigationService
//hi
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts

import 'package:cruze_mobile/services/micro_braking_service.dart';
import 'package:cruze_mobile/services/pothole_service.dart'; // Import PotholeService
import 'package:cruze_mobile/services/diagnostics_service.dart'; // Import DiagnosticsService
import 'package:cruze_mobile/services/black_box_service.dart'; // Import BlackBoxService
import 'package:cruze_mobile/services/rollover_service.dart'; // Import RolloverService

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  // Start Services
  MicroBrakingService.instance.startMonitoring();
  PotholeService.instance.startMonitoring();
  DiagnosticsService.instance.startMonitoring();
  BlackBoxService.instance.startRecording();
  RolloverService.instance.startMonitoring();
  
  runApp(const CruzeApp());
}

class CruzeApp extends StatelessWidget {
  const CruzeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Hides the "DEBUG" banner
      title: 'Cruze',
      // ENFORCE BOUNCING SCROLL PHYSICS GLOBALLY (Better Touch Feel)
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(),
      ),
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
        '/home': (context) => const MainScaffold(),
      },
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const MapScreen(),
    const AlertsScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Important for floating nav bar
      body: Stack(
        children: [
          // Background (Global Texture)
           Container(
             decoration: const BoxDecoration(
               gradient: LinearGradient(
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
                 colors: [
                   Color(0xFF0F0F0F), // Darker charcoal
                   Color(0xFF1A1A1A), // Lighter charcoal
                 ],
               ),
             ),
           ),
           
           // Screen Content
          _screens[_selectedIndex],

          // Floating Nav Bar (Hidden in Drive Mode)
          ValueListenableBuilder<bool>(
            valueListenable: NavigationService.instance.isNavigating,
            builder: (context, isNavigating, child) {
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                bottom: isNavigating ? -200 : 0, // Slide off-screen (increased for safe area)
                left: 0,
                right: 0,
                child: GlassNavBar(
                  selectedIndex: _selectedIndex,
                  onItemSelected: _onItemTapped,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

