import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_gate.dart';
import '../theme/colors.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isEmailVerified = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    // Check if they are already verified
    isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!isEmailVerified) {
      // Auto-check every 3 seconds
      timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> checkEmailVerified() async {
    // Reload user data from Firebase to get the latest status
    try {
      await FirebaseAuth.instance.currentUser?.reload();
    } catch (_) {
      return; // offline — try again on the next tick
    }
    if (!mounted) return;

    setState(() {
      isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    });

    if (isEmailVerified) {
      timer?.cancel();
      // Verified! Push them into the app
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthGate()),
        );
      }
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email resent. Check your spam!'), backgroundColor: AppColors.sage),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.clay),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.ink),
          onPressed: () {
            // Log them out if they cancel — AuthGate then shows the login screen
            FirebaseAuth.instance.signOut();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 100, color: AppColors.sage),
            const SizedBox(height: 30),
            Text(
              "Verify your email",
              style: GoogleFonts.domine(fontSize: 32, fontWeight: FontWeight.bold, color: context.colors.ink),
            ),
            const SizedBox(height: 20),
            Text(
              "We've sent a verification link to your email address. Please click the link to activate your account.",
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(fontSize: 18, color: context.colors.stone, height: 1.5),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: AppColors.sage),
            const SizedBox(height: 20),
            Text("Waiting for verification...", style: GoogleFonts.lato(color: context.colors.stone)),
            const SizedBox(height: 40),
            TextButton(
              onPressed: resendVerificationEmail,
              child: Text(
                "I didn't receive the email (Resend)",
                style: GoogleFonts.lato(color: AppColors.sage, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}