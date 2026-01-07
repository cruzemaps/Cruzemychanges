import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Styles
    const Color primaryColor = Color(0xFFff791a); // Safety Orange
    const Color backgroundDark = Color(0xFF121212); // Charcoal
    const Color surface = Color(0xFF1E1E1E); // Surface
    const Color textPrimary = Colors.white;
    const Color textSecondary = Color(0xFFA0A0A0);
    const Color borderDark = Color(0x1AFFFFFF); // rgba(255, 255, 255, 0.1)

    return Scaffold(
      backgroundColor: backgroundDark,
      body: Stack(
        children: [
          // Main Content
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Bottom padding for footer
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header (Back, Title, Settings)
                const SizedBox(height: 12), // Safe Area top padding approx
                SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: textPrimary),
                      ),
                      Text(
                        'Driver Profile',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.settings, color: textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Profile Section
                Stack(
                  children: [
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: surface, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        image: const DecorationImage(
                          image: NetworkImage(
                              "https://lh3.googleusercontent.com/aida-public/AB6AXuCLrD2crOep5pSZ993-uKKfJR2xTyQIlbmmfOiJSwX5mg9MhFKppl8kGsMwZOI_zd4V-uHwlZIpjljtVComNA2NCbBM1UmRzN5KLBMTbTzSaMqJRNFR0ax_P_Na1GFEhTHNeJPmbzB-atoRux5x8IU1HNfxX-dIBdPxSlTRreLMzSN-h9MsRj2nzCxe58IunEmJV597eOqjOG_9N889f39Lf6c_2hEHpNZcJ3u4ruXTPEASgPTZ1VAyOH8nmVjCSR2E5UOAE-xQUiUa"),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: backgroundDark, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'John Doe',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Driver ID: #DRV-8821',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Edit Profile Button
                Container(
                  width: 200,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: primaryColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.edit, color: primaryColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Edit Profile',
                        style: GoogleFonts.inter(
                          color: primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stats Grid
                Row(
                  children: [
                    Expanded(child: _buildStatCard('SAFETY', '98/100', textPrimary: primaryColor, subtextWidget: _buildTrend(true, '2.5%'))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('HOURS', '34h', subtext: 'This Week')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('MILES', '1.2k', subtext: 'Total')),
                  ],
                ),
                const SizedBox(height: 16),

                // License Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderDark),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('License Details',
                              style: GoogleFonts.inter(
                                  fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.green.withOpacity(0.2))),
                            child: Text(
                              'Active',
                              style: GoogleFonts.inter(
                                  color: Colors.green[400], fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('License Number', 'D99281-001'),
                      const Divider(color: borderDark),
                      _buildInfoRow('Class', 'Class A Commercial'),
                      const Divider(color: borderDark),
                      _buildInfoRow('State', 'CA'),
                      const Divider(color: borderDark),
                      _buildInfoRow('Expiration Date', '12/20/2025'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Vehicle Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderDark),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Assigned Vehicle',
                              style: GoogleFonts.inter(
                                  fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                          TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text('Change',
                                style: GoogleFonts.inter(
                                    color: primaryColor, fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 96,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderDark),
                              image: const DecorationImage(
                                image: NetworkImage("https://lh3.googleusercontent.com/aida-public/AB6AXuDk1lrYP9gi0JyqsWodUNgHMRfc4TdrDjhI8pX1FmqJdCgN2WkCIm5G427MOk9Et4j_lWv3QeZlyomCdznAEszI0uMuFtEPEEbOviYlN-pSGFqSZsWfV5nURLjDP6JSpizt1JioY2NaFfmRVuLdkS8Z7au9ZiNP16Mdhjh4oO8MvjRlZE8MCaYyHPET0jBA4xjX1DDO2ETP5o7WbA1E3CnR_1kWnMstQm-pcfJhmQuUMD84v7etctSJR0Z7xYEJx91wdFFKAr7ZyeNy"),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Volvo VNL 860',
                                    style: GoogleFonts.inter(
                                        fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                                Text('Plate: 4K29-LA',
                                    style: GoogleFonts.inter(
                                        fontSize: 14, color: textSecondary)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 8,
                                      height: 8,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('In Transit',
                                        style: GoogleFonts.inter(fontSize: 12, color: textSecondary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Recent Activity
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderDark),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recent Activity',
                          style: GoogleFonts.inter(
                              fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                      const SizedBox(height: 16),
                      _buildActivityItem(
                        icon: Icons.warning,
                        iconColor: primaryColor,
                        title: 'Hard Braking Event',
                        subtitle: 'Today, 10:42 AM • Hwy 101 South',
                      ),
                      const SizedBox(height: 16),
                      _buildActivityItem(
                        icon: Icons.check_circle,
                        iconColor: Colors.green,
                        title: 'Delivery Completed',
                        subtitle: 'Yesterday, 4:15 PM • Warehouse B',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Actions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
               color: backgroundDark.withOpacity(0.95), // Using color with opacity to simulate blur backdrop
               padding: const EdgeInsets.all(16),
               child: SafeArea(
                 top: false,
                 child: Row(
                   children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0x1AFFFFFF)), // border-border-dark
                              backgroundColor: surface,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.chat_bubble_outline, color: textPrimary, size: 20),
                                const SizedBox(width: 8),
                                Text('Message', style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {},
                             style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.call, color: textPrimary, size: 20),
                                const SizedBox(width: 8),
                                Text('Call Driver', style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                   ],
                 ),
               ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, {Color? textPrimary, String? subtext, Widget? subtextWidget}) {
    const Color surface = Color(0xFF1E1E1E);
    const Color borderDark = Color(0x1AFFFFFF);
    const Color textMain = Colors.white;
    const Color textSecondary = Color(0xFFA0A0A0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderDark),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.inter(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(color: textPrimary ?? textMain, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          if (subtextWidget != null)
             subtextWidget
          else
             Text(subtext ?? '', style: GoogleFonts.inter(color: textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTrend(bool isUp, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(isUp ? Icons.trending_up : Icons.trending_down, size: 12, color: Colors.green),
        const SizedBox(width: 2),
        Text(value, style: GoogleFonts.inter(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    const Color textPrimary = Colors.white;
    const Color textSecondary = Color(0xFFA0A0A0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: textSecondary, fontSize: 14)),
          Text(value, style: GoogleFonts.inter(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActivityItem({required IconData icon, required Color iconColor, required String title, required String subtitle}) {
     const Color textPrimary = Colors.white;
     const Color textSecondary = Color(0xFFA0A0A0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: iconColor.withOpacity(0.2)),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
              Text(subtitle, style: GoogleFonts.inter(color: textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
