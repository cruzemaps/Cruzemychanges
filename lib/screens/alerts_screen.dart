import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cruze_mobile/widgets/glass_card.dart'; // Ensure GlassCard is imported
import 'package:cruze_mobile/services/safety_service.dart'; // Import SafetyService

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  // Styles based on Tailwind config
  static const Color primaryColor = Color(0xFFff791a); // Safety Orange
  static const Color safeColor = Color(0xFF1A8FFF);    // Midnight Blue (using blue for safe)
  
  String _selectedFilter = 'All';

  void _handleMarkAllRead() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All alerts marked as read!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Note: No Scaffold here because MainScaffold provides the background and structure
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Filter Chips
            _buildFilterChips(),
            
            // Expanded List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), // Bottom padding for content above Nav
                children: [
                  // DRIVER SCORECARD SECTION
                  _buildSafetyScorecard(),
                  
                  const SizedBox(height: 24),

                   // TODAY Section
                  _buildSectionHeader('TODAY'),
                  const SizedBox(height: 16),
                  
                  // Live Events from Service
                  ValueListenableBuilder<List<SafetyEvent>>(
                    valueListenable: SafetyService.instance.events,
                    builder: (context, events, child) {
                      return Column(
                        children: events.map((event) {
                          return Column(
                            children: [
                              _buildAlertCard(
                                icon: Icons.warning_amber_rounded,
                                iconColor: Colors.redAccent,
                                title: event.title,
                                subtitle: event.description,
                                time: "${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}",
                                statusWidget: _buildStatusChip('-${event.penalty} pts', Colors.red),
                                isHighlight: true,
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        }).toList(),
                      );
                    },
                  ),
                  
                  // Fleet Alerts (Static)
                  _buildAlertCard(
                    icon: Icons.warning_amber_rounded,
                    iconColor: primaryColor,
                    title: 'Engine Overheat',
                    subtitle: 'Truck #402 • Route 66, Near Exit 4',
                    time: '10:42 AM',
                    statusWidget: _buildStatusChip('High Priority', Colors.red),
                    isHighlight: false, // Removed highlight to emphasize driver alerts
                  ),
                  const SizedBox(height: 16),
                  
                  _buildAlertCard(
                    icon: Icons.speed,
                    iconColor: primaryColor,
                    title: 'Harsh Braking Event',
                    subtitle: 'Van #105 • Downtown Delivery Zone',
                    time: '09:15 AM',
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
                    icon: Icons.check_circle_outline,
                    iconColor: safeColor,
                    title: 'Maintenance Completed',
                    subtitle: 'Truck #331 • Service Center A',
                    time: '08:30 AM',
                    borderColor: safeColor,
                  ),
                  
                   const SizedBox(height: 24),
                   // YESTERDAY Section
                  _buildSectionHeader('YESTERDAY'),
                  const SizedBox(height: 16),
                  
                  _buildAlertCard(
                    icon: Icons.alt_route,
                    iconColor: safeColor,
                    title: 'Route Optimization',
                    subtitle: 'System Alert • 14% fuel saved',
                    time: 'Yesterday',
                    borderColor: safeColor,
                  ),
                  const SizedBox(height: 16),
                  
                   _buildAlertCard(
                    icon: Icons.tire_repair,
                    iconColor: Colors.grey,
                    title: 'Low Tire Pressure',
                    subtitle: 'Truck #202 • Resolved by Driver',
                    time: 'Yesterday',
                    borderColor: Colors.grey,
                    titleStrikethrough: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyScorecard() {
    return ValueListenableBuilder<double>(
      valueListenable: SafetyService.instance.safetyScore,
      builder: (context, score, child) {
        // Evaluate Score Color
        Color scoreColor = Colors.green;
        if (score < 90) scoreColor = Colors.orange;
        if (score < 70) scoreColor = Colors.red;

        return GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         "YOUR SAFETY SCORE",
                         style: GoogleFonts.outfit(
                           color: Colors.white54,
                           fontSize: 12,
                           letterSpacing: 2.0,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                       const SizedBox(height: 8),
                       Text(
                         score.toInt().toString(),
                         style: GoogleFonts.outfit(
                           color: scoreColor,
                           fontSize: 64,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ],
                   ),
                   // Progress Circle
                   SizedBox(
                     height: 100,
                     width: 100,
                     child: Stack(
                       fit: StackFit.expand,
                       children: [
                         CircularProgressIndicator(
                           value: score / 100,
                           strokeWidth: 10,
                           backgroundColor: Colors.white10,
                           valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                         ),
                         Center(
                           child: Icon(
                             score > 80 ? Icons.verified_user : Icons.warning_rounded,
                             color: scoreColor,
                             size: 40,
                           ),
                         ),
                       ],
                     ),
                   ),
                 ],
               ),
               const SizedBox(height: 16),
               const Divider(color: Colors.white10),
               const SizedBox(height: 16),
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceAround,
                 children: [
                   _buildStatCompact("Trip Miles", "${SafetyService.instance.totalDistanceMiles.toStringAsFixed(1)} mi"),
                   _buildStatCompact("Total Penalties", "-${SafetyService.instance.accumulatedPenalty} pts"),
                 ],
               ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCompact(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16), // Top padding for status bar
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Safety & Alerts', // Renamed header
            style: GoogleFonts.outfit( // Using Outfit for headers
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          TextButton(
            onPressed: _handleMarkAllRead,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: Colors.white.withOpacity(0.05),
              shape: const StadiumBorder(),
            ),
            child: Text(
              'Mark all read',
              style: GoogleFonts.inter(
                color: primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
          _buildChip('All', isSelected: _selectedFilter == 'All'),
          const SizedBox(width: 12),
          _buildChip('Danger', isSelected: _selectedFilter == 'Danger', badgeCount: 3),
          const SizedBox(width: 12),
          _buildChip('Resolved', isSelected: _selectedFilter == 'Resolved'),
          const SizedBox(width: 12),
          _buildChip('Geofence', isSelected: _selectedFilter == 'Geofence'),
        ],
      ),
    );
  }

  Widget _buildChip(String label, {bool isSelected = false, int? badgeCount}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(999),
          border: isSelected ? null : Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.4),
                    blurRadius: 12,
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
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (badgeCount != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.0,
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
    Color? borderColor,
    Widget? content,
    Widget? statusWidget,
    bool isHighlight = false,
    bool titleStrikethrough = false,
  }) {
    return GlassCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor.withOpacity(0.3)),
                  boxShadow: isHighlight ? [BoxShadow(color: iconColor.withOpacity(0.2), blurRadius: 10)] : null,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.outfit(
                              color: titleStrikethrough ? Colors.white38 : Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              decoration: titleStrikethrough ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        Text(
                          time,
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    if (statusWidget != null) ...[
                      const SizedBox(height: 8),
                      statusWidget,
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          if (content != null) ...[
             const SizedBox(height: 12),
             Padding(
               padding: const EdgeInsets.only(left: 64),
               child: content,
             ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
