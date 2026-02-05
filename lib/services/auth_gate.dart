import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart'; // <--- IMPORT THE NEW HOME SCREEN

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. User is NOT logged in
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // 2. User IS logged in -> Check Onboarding Status
        final user = snapshot.data!;
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final userData = userSnapshot.data?.data() as Map<String, dynamic>?;

            // 3. If no diary name, go to Onboarding
            if (userData == null || userData['diary_name'] == null) {
              return const OnboardingScreen();
            }

            // 4. All set? Go to HOME (which defaults to Reflect)
            return const HomeScreen(); 
          },
        );
      },
    );
  }
}