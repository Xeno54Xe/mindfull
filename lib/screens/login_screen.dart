import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/colors.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isSignUp = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false; 

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      await FirebaseAuth.instance.signInWithPopup(googleProvider);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paperBackground,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.sage)) 
        : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 30),
              
              Text(
                isSignUp ? "Begin Journal." : "Welcome Back.",
                style: GoogleFonts.domine(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.ink),
              ),
              const SizedBox(height: 12),
              Text(
                isSignUp ? "A safe space for your mind." : "Resume your story.",
                style: GoogleFonts.lato(fontSize: 18, color: AppColors.stone), 
              ),
              const SizedBox(height: 50),
              
              _SocialButton(
                text: "Continue with Google",
                icon: FontAwesomeIcons.google,
                bgColor: const Color(0xFFDB4437), // Muted Google Red
                onTap: _signInWithGoogle, 
              ),
              const SizedBox(height: 16),
              _SocialButton(
                text: "Continue with Spotify",
                icon: FontAwesomeIcons.spotify,
                bgColor: const Color(0xFF1DB954), // Spotify Green
                onTap: () {},
              ),
              
              const SizedBox(height: 30),
              const Row(children: [
                Expanded(child: Divider(color: AppColors.stone, thickness: 0.5)), 
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("OR", style: TextStyle(color: AppColors.stone, fontWeight: FontWeight.bold))), 
                Expanded(child: Divider(color: AppColors.stone, thickness: 0.5))
              ]),
              const SizedBox(height: 30),

              // LIGHT THEME INPUTS
              _LightInput(controller: _emailController, label: "Email", icon: Icons.email_outlined),
              const SizedBox(height: 20),
              _LightInput(controller: _passwordController, label: "Password", icon: Icons.lock_outline, isPassword: true),
              
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sage, // Pastel Green Button
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: Text(isSignUp ? "Create Account" : "Sign In", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 30),
              Center(
                child: GestureDetector(
                  onTap: () => setState(() => isSignUp = !isSignUp),
                  child: RichText(
                    text: TextSpan(
                      text: isSignUp ? "Already a member? " : "New here? ",
                      style: const TextStyle(color: AppColors.stone),
                      children: [TextSpan(text: isSignUp ? "Sign In" : "Join Now", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.sage))],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LightInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;

  const _LightInput({required this.controller, required this.label, required this.icon, this.isPassword = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: AppColors.ink, fontSize: 16),
      cursorColor: AppColors.sage,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.stone), 
        prefixIcon: Icon(icon, color: AppColors.stone),
        filled: true,
        fillColor: AppColors.cardColor, // White/Cream Box
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.stone.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.sage, width: 2)),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String text; final IconData icon; final Color bgColor; final VoidCallback onTap;
  const _SocialButton({required this.text, required this.icon, required this.bgColor, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            Icon(icon, color: Colors.white, size: 20), 
            const SizedBox(width: 12), 
            Text(text, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))
          ]
        ),
      ),
    );
  }
}