import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // REQUIRED to check user
import 'firebase_options.dart';
import 'theme/colors.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart'; // Import Home
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MindFull',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBackground,
        textTheme: TextTheme(bodyLarge: TextStyle(color: AppColors.lightText)),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        textTheme: TextTheme(bodyLarge: TextStyle(color: AppColors.darkText)),
      ),
      themeMode: ThemeMode.system,
      // --- THE GATEKEEPER LOGIC ---
      home: StreamBuilder<User?>(
        // Listen to the "Auth State" stream (Login/Logout events)
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Is it checking? Show a spinner.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // 2. Is there a user? Go STRAIGHT to Home.
          if (snapshot.hasData) {
            return const MainScreen();
          }

          // 3. No user? Go to Onboarding.
          return const OnboardingScreen();
        },
      ),
      // ----------------------------
    );
  }
}