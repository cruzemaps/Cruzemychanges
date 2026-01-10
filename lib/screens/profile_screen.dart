import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cruze_mobile/widgets/glass_card.dart';
import 'package:cruze_mobile/services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        // Show loading indicator or toast?
        await UserService.instance.uploadProfileImage(image);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Profile Picture Updated")),
           );
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Styles
    const Color primaryColor = Color(0xFFff791a); // Safety Orange
    const Color goldColor = Color(0xFFD4AF37); // Metallic Gold
    const Color textPrimary = Colors.white;

    return Center(
      child: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
               // Custom Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                         UserService.instance.logout();
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
                      onPressed: () => _showEditProfileDialog(context),
                      icon: const Icon(Icons.settings_outlined, color: Colors.white54),
                      tooltip: "Settings",
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 120 + MediaQuery.of(context).padding.bottom),
                  child: Column(
                    children: [
                      // Avatar & Name (Reactive)
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
                          // Avatar Section with Edit
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: goldColor, width: 2),
                              boxShadow: const [BoxShadow(color: primaryColor, blurRadius: 15, spreadRadius: -5)],
                            ),
                            child: ValueListenableBuilder<String?>(
                              valueListenable: UserService.instance.profileImage,
                              builder: (context, imageUrl, child) {
                                return CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.grey[900],
                                  backgroundImage: imageUrl != null 
                                      ? NetworkImage(imageUrl)
                                      : const NetworkImage("https://lh3.googleusercontent.com/aida-public/AB6AXuDk1lrYP9gi0JyqsWodUNgHMRfc4TdrDjhI8pX1FmqJdCgN2WkCIm5G427MOk9Et4j_lWv3QeZlyomCdznAEszI0uMuFtEPEEbOviYlN-pSGFqSZsWfV5nURLjDP6JSpizt1JioY2NaFfmRVuLdkS8Z7au9ZiNP16Mdhjh4oO8MvjRlZE8MCaYyHPET0jBA4xjX1DDO2ETP5o7WbA1E3CnR_1kWnMstQm-pcfJhmQuUMD84v7etctSJR0Z7xYEJx91wdFFKAr7ZyeNy") as ImageProvider,
                                );
                              },
                            ),
                          ),
                          GestureDetector(
                            onTap: _pickImage, // Trigger Upload
                            child: Container(
                              margin: const EdgeInsets.only(right: 4, bottom: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                          // Rank Badge
                          Positioned(
                            bottom: -10,
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
                                  ValueListenableBuilder<String>(
                                    valueListenable: UserService.instance.role,
                                    builder: (context, role, child) {
                                      return Text(
                                        role.toUpperCase(),
                                        style: GoogleFonts.outfit(
                                          color: Colors.black,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Dynamic Name
                      ValueListenableBuilder<String>(
                        valueListenable: UserService.instance.name,
                        builder: (context, name, child) {
                          return Text(
                            name.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                              letterSpacing: 1,
                            ),
                          );
                        },
                      ),
                      
                      ValueListenableBuilder<String>(
                        valueListenable: UserService.instance.email,
                         builder: (context, email, child) {
                          return Text(
                            email.isEmpty ? 'ID: #DRV-8821 • SAN ANTONIO HUB' : email.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white54,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                            ),
                          );
                         } 
                      ),
                      
                      const SizedBox(height: 32),

                      // Stats Grid
                      Row(
                        children: [
                          Expanded(
                            child: ValueListenableBuilder<int>(
                              valueListenable: UserService.instance.safetyScore,
                              builder: (context, score, child) {
                                return _buildStatItem("SAFETY SCORE", "$score", primaryColor, suffix: "/100");
                              },
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: ValueListenableBuilder<double>(
                              valueListenable: UserService.instance.totalMiles,
                              builder: (context, miles, child) {
                                return _buildStatItem("TOTAL MILES", miles.toStringAsFixed(1), Colors.white, suffix: " mi");
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                       Row(
                        children: [
                          Expanded(
                            child: _buildStatItem("HOURS LOGGED", "38.5", Colors.white, suffix: " hrs"),
                          ),
                          const SizedBox(width: 24),
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
                             _buildMenuItem(context, Icons.description_outlined, "License & Documents", "Action Required", trailingColor: Colors.redAccent),
                             const Divider(height: 1, color: Colors.white10),
                             _buildMenuItem(context, Icons.history, "Trip History", "View Log", trailingColor: Colors.white54),
                             const Divider(height: 1, color: Colors.white10),
                             _buildMenuItem(context, Icons.headset_mic_outlined, "Support & Dispatch", null),
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
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController(text: UserService.instance.name.value);
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
                Text("EDIT PROFILE", style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Full Name",
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFff791a)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFff791a)),
                      onPressed: () {
                         if (controller.text.isNotEmpty) {
                            UserService.instance.updateName(controller.text);
                            Navigator.pop(ctx);
                         }
                      },
                      child: const Text("SAVE", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
             ],
          ),
        ),
      ),
    );
  }
  
  void _showFeatureUnavailable(BuildContext context, String feature) {
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$feature unavailable in Demo Mode')),
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

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, String? trailing, {Color? trailingColor}) {
    return InkWell(
      onTap: () => _showFeatureUnavailable(context, title),
      child: Padding(
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
      ),
    );
  }
}
