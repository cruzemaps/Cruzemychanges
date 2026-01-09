import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cruze_mobile/widgets/glass_card.dart'; // Ensure GlassCard is imported

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Styles
    const Color primaryColor = Color(0xFFff791a); // Safety Orange
    const Color goldColor = Color(0xFFD4AF37); // Metallic Gold
    const Color textPrimary = Colors.white;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
             // Custom Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 60, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                       // If pushed from map, can pop. If from tab, maybe do nothing or show logout?
                       // Since it's in a tab view now, back button might not be relevant unless it's a sub-page.
                       // We'll change it to Logout for utility.
                       Navigator.of(context).pushReplacementNamed('/');
                    }, 
                    icon: const Icon(Icons.logout, color: Colors.white54),
                    tooltip: "Logout",
                  ),
                  Text(
                    'DRIVER PROFILE',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.settings_outlined, color: Colors.white54),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), // Bottom padding for content
                child: Column(
                  children: [
                    // Avatar & Name
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 40, spreadRadius: 10),
                            ],
                          ),
                        ),
                        // Avatar
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: goldColor, width: 2),
                            image: const DecorationImage(
                              image: NetworkImage("https://lh3.googleusercontent.com/aida-public/AB6AXuCLrD2crOep5pSZ993-uKKfJR2xTyQIlbmmfOiJSwX5mg9MhFKppl8kGsMwZOI_zd4V-uHwlZIpjljtVComNA2NCbBM1UmRzN5KLBMTbTzSaMqJRNFR0ax_P_Na1GFEhTHNeJPmbzB-atoRux5x8IU1HNfxX-dIBdPxSlTRreLMzSN-h9MsRj2nzCxe58IunEmJV597eOqjOG_9N889f39Lf6c_2hEHpNZcJ3u4ruXTPEASgPTZ1VAyOH8nmVjCSR2E5UOAE-xQUiUa"),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Rank Badge
                        Positioned(
                          bottom: -10, // Moved down slightly to reduce overlap with face
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: goldColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, size: 12, color: Colors.black),
                                const SizedBox(width: 4),
                                Text(
                                  "ELITE DRIVER",
                                  style: GoogleFonts.outfit(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'JOHN DOE',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'ID: #DRV-8821 • SAN ANTONIO HUB',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    ),
                    
                    const SizedBox(height: 32),

                    // Stats Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem("SAFETY SCORE", "98", primaryColor, suffix: "/100"),
                        ),
                        const SizedBox(width: 24), // Increased spacing
                        Expanded(
                          child: _buildStatItem("WEEKLY MILES", "1,240", Colors.white, suffix: " mi"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                     Row(
                      children: [
                        Expanded(
                          child: _buildStatItem("HOURS LOGGED", "38.5", Colors.white, suffix: " hrs"),
                        ),
                        const SizedBox(width: 24), // Increased spacing
                        Expanded(
                          child: _buildStatItem("RANKING", "#4", goldColor, suffix: " in Hub"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    
                    // Vehicle Info
                    GlassCard(
                      padding: const EdgeInsets.all(0),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("ASSIGNED VEHICLE", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                                const Icon(Icons.directions_car, color: primaryColor, size: 18),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Colors.white10),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 80,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: const DecorationImage(
                                      image: NetworkImage("https://lh3.googleusercontent.com/aida-public/AB6AXuDk1lrYP9gi0JyqsWodUNgHMRfc4TdrDjhI8pX1FmqJdCgN2WkCIm5G427MOk9Et4j_lWv3QeZlyomCdznAEszI0uMuFtEPEEbOviYlN-pSGFqSZsWfV5nURLjDP6JSpizt1JioY2NaFfmRVuLdkS8Z7au9ZiNP16Mdhjh4oO8MvjRlZE8MCaYyHPET0jBA4xjX1DDO2ETP5o7WbA1E3CnR_1kWnMstQm-pcfJhmQuUMD84v7etctSJR0Z7xYEJx91wdFFKAr7ZyeNy"),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Volvo VNL 860", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text("Plate: 4K29-LA", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                     // Documents
                    GlassCard(
                       child: Column(
                         children: [
                           _buildMenuItem(Icons.description_outlined, "License & Documents", "Action Required", Colors.redAccent),
                           const Divider(height: 1, color: Colors.white10),
                           _buildMenuItem(Icons.history, "Trip History", "View Log", Colors.white54),
                           const Divider(height: 1, color: Colors.white10),
                           _buildMenuItem(Icons.headset_mic_outlined, "Support & Dispatch", null, null),
                         ],
                       ),
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

  Widget _buildStatItem(String label, String value, Color valueColor, {String? suffix}) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  color: valueColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (suffix != null)
                 Text(
                   suffix,
                   style: GoogleFonts.outfit(
                     color: Colors.white38,
                     fontSize: 14,
                     fontWeight: FontWeight.w500,
                   ),
                 ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String? trailing, Color? trailingColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
          if (trailing != null)
             Text(trailing, style: GoogleFonts.inter(color: trailingColor ?? Colors.white54, fontSize: 12)),
          if (trailing == null)
             const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
        ],
      ),
    );
  }
}
