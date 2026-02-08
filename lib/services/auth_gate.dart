import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/main_screen.dart'; // <--- FIXED: Points to your existing Shell

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

        // 2. User IS logged in -> Check Firestore for 'diary_name'
        final user = snapshot.data!;
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            // Waiting for data...
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final userData = userSnapshot.data?.data() as Map<String, dynamic>?;

            // 3. If "diary_name" is missing, they haven't onboarded yet.
            if (userData == null || userData['diary_name'] == null) {
              return const OnboardingScreen();
            }

            // 4. All good? Go to the MainScreen (which defaults to Reflect Tab)
            return const MainScreen(); 
          },
        );
      },
    );
  }
}