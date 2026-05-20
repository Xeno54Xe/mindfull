import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/auth_gate.dart';
import '../theme/colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isSignUp = false;
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);
    final auth = FirebaseAuth.instance;
    try {
      if (isSignUp) {
        UserCredential cred = await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await cred.user?.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Account created! Check your email to verify before signing in."),
            backgroundColor: AppColors.sage,
            duration: Duration(seconds: 5),
          ));
          setState(() => isSignUp = false);
        }
      } else {
        final credential = await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (credential.user != null && !credential.user!.emailVerified) {
          await auth.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Please verify your email first. Check your inbox for the link."),
              backgroundColor: AppColors.clay,
              duration: Duration(seconds: 5),
            ));
          }
          return;
        }
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AuthGate()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message ?? "Authentication Error"),
          backgroundColor: AppColors.clay,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) { setState(() => _isLoading = false); return; }
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          ),
        );
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthGate()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Google Sign-In Failed: $e"),
          backgroundColor: AppColors.clay,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.sage))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (Navigator.canPop(context))
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: context.colors.ink),
                        onPressed: () => Navigator.pop(context),
                      ),
                    const SizedBox(height: 30),
                    Text(
                      isSignUp ? "Begin Journal." : "Welcome Back.",
                      style: GoogleFonts.domine(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: context.colors.ink),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isSignUp ? "A safe space for your mind." : "Resume your story.",
                      style: GoogleFonts.lato(fontSize: 18, color: context.colors.stone),
                    ),
                    const SizedBox(height: 50),

                    _SocialButton(
                      text: "Continue with Google",
                      icon: FontAwesomeIcons.google,
                      bgColor: const Color(0xFFDB4437),
                      onTap: _signInWithGoogle,
                    ),
                    const SizedBox(height: 30),

                    Row(children: [
                      Expanded(child: Divider(color: context.colors.stone, thickness: 0.5)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text("OR",
                            style: TextStyle(
                                color: context.colors.stone,
                                fontWeight: FontWeight.bold)),
                      ),
                      Expanded(child: Divider(color: context.colors.stone, thickness: 0.5)),
                    ]),
                    const SizedBox(height: 30),

                    _LightInput(controller: _emailController, label: "Email", icon: Icons.email_outlined),
                    const SizedBox(height: 20),
                    _LightInput(controller: _passwordController, label: "Password", icon: Icons.lock_outline, isPassword: true),
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sage,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: Text(
                          isSignUp ? "Create Account" : "Sign In",
                          style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    Center(
                      child: GestureDetector(
                        onTap: () => setState(() => isSignUp = !isSignUp),
                        child: RichText(
                          text: TextSpan(
                            text: isSignUp ? "Already a member? " : "New here? ",
                            style: TextStyle(color: context.colors.stone),
                            children: [
                              TextSpan(
                                text: isSignUp ? "Sign In" : "Join Now",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.sage),
                              ),
                            ],
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

  const _LightInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: TextStyle(color: context.colors.ink, fontSize: 16),
      cursorColor: AppColors.sage,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.colors.stone),
        prefixIcon: Icon(icon, color: context.colors.stone),
        filled: true,
        fillColor: context.colors.card,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: context.colors.stone.withValues(alpha: 0.15))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.sage, width: 2)),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String text;
  final FaIconData icon;
  final Color bgColor;
  final VoidCallback onTap;

  const _SocialButton({
    required this.text,
    required this.icon,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(text,
                style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
