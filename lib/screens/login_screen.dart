import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cruze_mobile/widgets/glass_card.dart'; // Import GlassCard

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLogin = true; // Toggle between Login and Signup

  Future<void> _handleAuth() async {
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();
    final String name = nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    // Demo Mode Logic
    if (email.toLowerCase().contains("demo")) {
       Navigator.of(context).pushReplacementNamed('/home');
       return;
    }

    final String endpoint = _isLogin ? 'login' : 'signup';
    final String baseUrl = 'http://127.0.0.1:7071/api'; 
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          if (!_isLogin) 'name': name,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        if (_isLogin) {
           Navigator.of(context).pushReplacementNamed('/home');
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created! Please log in.')),
          );
           setState(() {
             _isLogin = true;
           });
        }
      } else {
         if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Fallback for demo if backend is down
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFff791a); // Safety Orange
    const Color textMain = Colors.white;
    const Color textSecondary = Color(0xFF9CA3AF);

    return Scaffold(
      body: Stack(
        children: [
          // Background Image (Cyberpunk / Night City)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage("https://lh3.googleusercontent.com/aida-public/AB6AXuCLrD2crOep5pSZ993-uKKfJR2xTyQIlbmmfOiJSwX5mg9MhFKppl8kGsMwZOI_zd4V-uHwlZIpjljtVComNA2NCbBM1UmRzN5KLBMTbTzSaMqJRNFR0ax_P_Na1GFEhTHNeJPmbzB-atoRux5x8IU1HNfxX-dIBdPxSlTRreLMzSN-h9MsRj2nzCxe58IunEmJV597eOqjOG_9N889f39Lf6c_2hEHpNZcJ3u4ruXTPEASgPTZ1VAyOH8nmVjCSR2E5UOAE-xQUiUa"),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
              ),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Logo Section
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(seconds: 1),
                      builder: (context, double value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 50 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                              border: Border.all(color: primaryColor.withOpacity(0.5), width: 2),
                              boxShadow: const [
                                BoxShadow(color: primaryColor, blurRadius: 20, spreadRadius: -10),
                              ],
                            ),
                            child: const Icon(Icons.hub, color: primaryColor, size: 48),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'HIVE MIND',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: textMain,
                              letterSpacing: 4,
                            ),
                          ),
                          Text(
                            'FLEET INTELLIGENCE',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: primaryColor,
                              letterSpacing: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 48),

                    // Glass Login Form
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           if (!_isLogin) ...[
                              _buildTextField(nameController, 'Full Name', Icons.person),
                              const SizedBox(height: 16),
                           ],
                           _buildTextField(emailController, 'Email', Icons.email),
                           const SizedBox(height: 16),
                           _buildTextField(passwordController, 'Password', Icons.lock, isPassword: true),
                           
                           const SizedBox(height: 24),

                           SizedBox(
                             width: double.infinity,
                             height: 50,
                             child: ElevatedButton(
                               onPressed: _handleAuth,
                               style: ElevatedButton.styleFrom(
                                 backgroundColor: primaryColor,
                                 foregroundColor: Colors.white,
                                 shadowColor: primaryColor.withOpacity(0.5),
                                 elevation: 8,
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                               ),
                               child: Text(
                                 _isLogin ? 'ACCESS DASHBOARD' : 'INITIALIZE ACCOUNT',
                                 style: GoogleFonts.outfit(
                                   fontWeight: FontWeight.bold,
                                   fontSize: 14,
                                   letterSpacing: 1,
                                 ),
                               ),
                             ),
                           ),
                           
                           const SizedBox(height: 16),
                           
                           Center(
                             child: GestureDetector(
                               onTap: () {
                                 setState(() {
                                   _isLogin = !_isLogin;
                                   emailController.clear();
                                   passwordController.clear();
                                   nameController.clear();
                                 });
                               },
                               child: Text(
                                 _isLogin ? "New Unit? Register Hardware" : "Already Registered? Login",
                                 style: GoogleFonts.inter(
                                   color: textSecondary,
                                   fontSize: 12,
                                   fontWeight: FontWeight.w500,
                                 ),
                               ),
                             ),
                           ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                     // Need Help
                    Center(
                      child: TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Calling Dispatch...')),
                          );
                        },
                        child: Text(
                          'Contact Dispatch',
                          style: GoogleFonts.inter(
                            color: textSecondary,
                            fontSize: 12,
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

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.5), size: 20),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFff791a), width: 1),
        ),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            )
          : null,
      ),
    );
  }
}
