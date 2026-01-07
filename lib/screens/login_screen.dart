import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // For kIsWeb

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

    final String endpoint = _isLogin ? 'login' : 'signup';
    // Use localhost for Web/iOS, 10.0.2.2 for Android Emulator.
    // Since we removed dart:io to support Web, we default to localhost.
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
           Navigator.of(context).pushReplacementNamed('/map');
        } else {
           // Signup Success -> Switch to Login
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colors from Tailwind config
    const Color primaryColor = Color(0xFFff791a); // Safety Orange
    const Color backgroundDark = Color(0xFF121212); // Charcoal
    const Color surfaceDark = Color(0xFF1E1E1E); // Card Background
    const Color textMain = Colors.white;
    const Color textSecondary = Color(0xFF9CA3AF); // Gray 400

    return Scaffold(
      backgroundColor: backgroundDark,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo / Image Section
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[800]!),
                        image: const DecorationImage(
                          image: NetworkImage(
                              "https://lh3.googleusercontent.com/aida-public/AB6AXuA4kcrFRaU4wdjxM2PP6B3hJW7DQb3OZ_vBctBxeClw1Ib1-vWgfW_GRRAZVHfGh1k-n2US_NeiIvjmaVhUlsB4XS9ZJ8lURfkgsxz30lyWzHuTKWrDPYM7NYLFR4K6Hd7Z-AzyrYPdzR90U5uZbbnKoCZwJa6ZWVVFNVCrdhu3mWJmwmmKpwHOTMZndKESfj96jc5D-Wlghup6u4Q3MOYEhjLndM47zzMzCjypHNSWhHGGQqCGR9j6OfvZxxyc3WELfYqk-6FXeul0"),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'HiveMind Fleet',
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: textMain,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLogin ? 'Log in to your dashboard' : 'Create a new account',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Form Section
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           // Name Field (Signup Only)
                           if (!_isLogin) ...[
                              Text(
                                'Full Name',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textMain,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: nameController,
                                style: GoogleFonts.inter(
                                    color: textMain, fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'John Doe',
                                  hintStyle: GoogleFonts.inter(color: Colors.grey[600]),
                                  filled: true,
                                  fillColor: surfaceDark,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                ),
                              ),
                              const SizedBox(height: 20),
                           ],
                        
                          // Email Field (Renamed from Username)
                          Text(
                            'Email',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textMain,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: emailController,
                            style: GoogleFonts.inter(
                                color: textMain, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'user@company.com',
                              hintStyle: GoogleFonts.inter(color: Colors.grey[600]),
                              filled: true,
                              fillColor: surfaceDark,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                    color: primaryColor, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Password Field
                          Text(
                            'Password',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textMain,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: passwordController,
                            obscureText: !_isPasswordVisible,
                            style: GoogleFonts.inter(
                                color: textMain, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              hintStyle: GoogleFonts.inter(color: Colors.grey[600]),
                              filled: true,
                              fillColor: surfaceDark,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                    color: primaryColor, width: 2),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey[400],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                          ),
                          
                          // Forgot Password Link (Login Only)
                          if (_isLogin)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Reset link sent to email')),
                                  );
                                },
                                child: Text(
                                  'Forgot Password?',
                                  style: GoogleFonts.inter(
                                    color: textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                          else
                             const SizedBox(height: 24),

                          const SizedBox(height: 16),

                          // Login/Signup Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _handleAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: primaryColor.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Text(
                                _isLogin ? 'Log In' : 'Sign Up',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                           // Toggle Login/Signup
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                  // Clear fields
                                  emailController.clear();
                                  passwordController.clear();
                                  nameController.clear();
                                });
                              },
                              child: Text.rich(
                                TextSpan(
                                  text: _isLogin ? "Don't have an account? " : "Already have an account? ",
                                  style: GoogleFonts.inter(
                                    color: textSecondary,
                                    fontSize: 14,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: _isLogin ? 'Sign Up' : 'Log In',
                                      style: GoogleFonts.inter(
                                        color: primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
