import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// 1. WE ALIAS THE PACKAGE TO AVOID CONFLICTS
import 'package:google_sign_in/google_sign_in.dart' as g_signin; 
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/paper_background.dart'; 
import '../theme/colors.dart';
import 'main_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  
  // 2. USE THE ALIAS HERE
  final g_signin.GoogleSignIn _googleSignIn = g_signin.GoogleSignIn(); 

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // 3. AND HERE
      final g_signin.GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; 
      }
      final g_signin.GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaperBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              
              Text("Reflect.", 
                style: GoogleFonts.domine(
                  fontSize: 56, 
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                )
              ),
              const SizedBox(height: 12),
              Text("A sanctuary for your thoughts.", 
                style: GoogleFonts.lato(
                  fontSize: 18, 
                  color: AppColors.stone,
                  letterSpacing: 0.5
                )
              ),

              const SizedBox(height: 60),

              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(color: AppColors.sage.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
                  ]
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(FontAwesomeIcons.google, size: 20, color: Colors.white),
                    label: Text(
                      _isLoading ? "CONNECTING..." : "Continue with Google", 
                      style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ink, 
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), 
                    ),
                  ),
                ),
              ),

              const Spacer(),
              
              Center(
                child: Text("Mindful. Private. Yours.", 
                  style: GoogleFonts.lato(fontSize: 12, color: AppColors.stone.withOpacity(0.6))
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}