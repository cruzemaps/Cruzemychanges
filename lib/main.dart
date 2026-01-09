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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const CruzeApp());
}

class CruzeApp extends StatelessWidget {
  const CruzeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
                bottom: isNavigating ? -100 : 0, // Slide off-screen
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

