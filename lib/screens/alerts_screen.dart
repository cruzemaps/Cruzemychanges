import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  // Styles based on Tailwind config
  static const Color primaryColor = Color(0xFFff791a); // Safety Orange
  static const Color safeColor = Color(0xFF1A8FFF);    // Midnight Blue (using blue for safe)
  static const Color backgroundDark = Color(0xFF121212); // Charcoal
  static const Color surfaceDark = Color(0xFF1E1E1E);    // Card Background
  static const Color surfaceLighter = Color(0xFF2A2A2A); // Chip Background

  int _selectedIndex = 2; // "Alerts" selected by default

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Outer background
      body: Center(
        child: Container(
          // Simulate the max-width container from HTML
          constraints: const BoxConstraints(maxWidth: 450),
          decoration: BoxDecoration(
            color: backgroundDark,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.symmetric(
              vertical: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
          ),
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Filter Chips
              _buildFilterChips(),
              
              // Expanded List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), // Bottom padding for FAB
                  children: [
                    _buildSectionHeader('TODAY'),
                    const SizedBox(height: 16),
                    _buildAlertCard(
                      icon: Icons.warning,
                      iconColor: primaryColor,
                      title: 'Engine Overheat',
                      subtitle: 'Truck #402 • Route 66, Near Exit 4',
                      time: '10:42 AM',
                      borderColor: primaryColor,
                      content: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.withOpacity(0.2)),
                            ),
                            child: Text(
                              'High Priority',
                              style: GoogleFonts.inter(
                                color: Colors.red[400],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'Details',
                                style: GoogleFonts.inter(
                                  color: primaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, size: 16, color: primaryColor),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAlertCard(
                      icon: Icons.speed,
                      iconColor: primaryColor,
                      title: 'Harsh Braking Event',
                      subtitle: 'Van #105 • Downtown Delivery Zone',
                      time: '09:15 AM',
                      borderColor: primaryColor,
                      content: Text(
                        'Recorded deceleration of -12 km/h/s. Driver signaled for review.',
                        style: GoogleFonts.inter(
                          color: Colors.grey[300],
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAlertCard(
                      icon: Icons.check_circle,
                      iconColor: safeColor,
                      title: 'Maintenance Completed',
                      subtitle: 'Truck #331 • Service Center A',
                      time: '08:30 AM',
                      borderColor: safeColor,
                      opacity: 0.9,
                    ),
                    const SizedBox(height: 16),
                    _buildAlertCard(
                      icon: Icons.shield,
                      iconColor: safeColor,
                      title: 'Safety Inspection Pass',
                      subtitle: 'Fleet A • Weekly Check',
                      time: '08:00 AM',
                      borderColor: safeColor,
                      opacity: 0.9,
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionHeader('YESTERDAY'),
                    const SizedBox(height: 8), // HTML had margin top 4 = 16px
                    
                    _buildAlertCard(
                      icon: Icons.route,
                      iconColor: safeColor,
                      title: 'Route Optimization',
                      subtitle: 'System Alert • 14% fuel saved',
                      time: 'Yesterday',
                      borderColor: safeColor,
                      opacity: 0.8,
                      showChevron: true,
                    ),
                    const SizedBox(height: 16),
                     _buildAlertCard(
                      icon: Icons.tire_repair,
                      iconColor: Colors.grey[400]!,
                      title: 'Low Tire Pressure',
                      subtitle: 'Truck #202 • Resolved by Driver',
                      time: 'Yesterday',
                      borderColor: Colors.white.withOpacity(0.1),
                      opacity: 0.75,
                      titleStrikethrough: true,
                      bgColor: Colors.white.withOpacity(0.05),
                      iconBgColor: Colors.white.withOpacity(0.1),
                    ),
                  ],
                ),
              ),
              
              // Bottom Nav
              _buildBottomNav(),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80, right: 8),
        child: FloatingActionButton(
          onPressed: () {},
          backgroundColor: primaryColor,
          elevation: 8,
          child: const Icon(Icons.add_alert, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Fleet Alerts',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: Colors.transparent,
              shape: const StadiumBorder(),
            ),
            child: Text(
              'Mark all read',
              style: GoogleFonts.inter(
                color: primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _buildChip('All', isSelected: true),
          const SizedBox(width: 12),
          _buildChip('Danger', badgeCount: 3),
          const SizedBox(width: 12),
          _buildChip('Resolved'),
          const SizedBox(width: 12),
          _buildChip('Geofence'),
        ],
      ),
    );
  }

  Widget _buildChip(String label, {bool isSelected = false, int? badgeCount}) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isSelected ? primaryColor : surfaceLighter,
        borderRadius: BorderRadius.circular(999),
        border: isSelected ? null : Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          if (badgeCount != null) ...[
            const SizedBox(width: 8),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  badgeCount.toString(),
                  style: GoogleFonts.inter(
                    color: primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: backgroundDark.withOpacity(0.95),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white.withOpacity(0.6),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
  
  Widget _buildAlertCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
    required Color borderColor,
    Widget? content,
    double opacity = 1.0,
    bool showChevron = false,
    bool titleStrikethrough = false,
    Color? bgColor,
    Color? iconBgColor,
  }) {
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor ?? surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: borderColor, width: 6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: iconBgColor ?? iconColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.inter(
                                color: titleStrikethrough ? Colors.grey[400] : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                decoration: titleStrikethrough ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: GoogleFonts.inter(
                                color: Colors.grey[400], // text-gray-400
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (showChevron)
                   Icon(Icons.chevron_right, color: Colors.grey[600])
                else
                  Text(
                    time,
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            
            // Optional Content
            if (content != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 54), // 40 + 14 padding
                child: content,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: backgroundDark,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(Icons.dashboard_outlined, 'Home', 0),
            _buildNavItem(Icons.map_outlined, 'Map', 1, onTap: () {
               // Navigate to Map
              Navigator.of(context).pushReplacementNamed('/map');
            }),
            _buildNavItem(Icons.notifications, 'Alerts', 2, isAlert: true),
            _buildNavItem(Icons.local_shipping_outlined, 'Fleet', 3),
            _buildProfileNavItem(4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, {bool isAlert = false, VoidCallback? onTap}) {
    final isSelected = index == _selectedIndex;
    final color = isSelected ? primaryColor : Colors.white.withOpacity(0.4);
    
    return InkWell(
      onTap: () {
        if (onTap != null) {
          onTap();
        } else {
          setState(() {
            _selectedIndex = index;
          });
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Icon(icon, color: color, size: 28),
              if (isAlert)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: backgroundDark, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileNavItem(int index) {
     final isSelected = index == _selectedIndex;
    
    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed('/profile');
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : Colors.white.withOpacity(0.2)),
              image: const DecorationImage(
                image: NetworkImage("https://lh3.googleusercontent.com/aida-public/AB6AXuDa3kuGjIPThb6wBfRuRguWBkdQK9QGC3fEEvsXi8dScnyVE_yEJlg-AOIdxNYcoNgH-7ljYYRzPPBce-Wjw0cPzyMhvUXXpYVC4Vv4Ryooul6EydE0QF5kMIwU9uLI8wfRhzR244d-dli3i7xe93HLuxdRdF42ocZcvCKtJBlz80AvKFoz9LscjuJ7QsSnhGGcTwPntyG-onnatPC51fgXj-70AzXa1Pi1-LMfDQalqdfFINGmWfpRiN25G4g2ZZrK7WjAyuGTXpRf"), 
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Profile',
            style: GoogleFonts.inter(
              color: isSelected ? primaryColor : Colors.white.withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
