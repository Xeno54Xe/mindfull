import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; // IMPORT THIS
import 'firebase_options.dart'; 
import 'services/auth_gate.dart';
import 'screens/landing_screen.dart'; // IMPORT THIS
import 'theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- CHECK IF USER HAS SEEN INTRO ---
  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenIntro = prefs.getBool('hasSeenIntro') ?? false;

  runApp(MindFullApp(startScreen: hasSeenIntro ? const AuthGate() : const LandingScreen()));
}

class MindFullApp extends StatelessWidget {
  final Widget startScreen; // Receive the decision
  
  const MindFullApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindFull',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.paperBackground,
        primaryColor: AppColors.ink,
        textTheme: GoogleFonts.latoTextTheme(),
        useMaterial3: true,
      ),
      // Use the decision we made in main()
      home: startScreen, 
    );
  }
}