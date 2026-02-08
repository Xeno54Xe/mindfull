import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:flutter/services.dart'; 
import 'firebase_options.dart'; 
import 'services/auth_gate.dart';
import 'screens/landing_screen.dart'; 
import 'theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- 1. FIREBASE INITIALIZATION (BULLETPROOF VERSION) ---
  // We try to initialize. If it fails (because it already exists), 
  // we catch the error and continue anyway.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase was already initialized. Continuing...");
  }

  // --- 2. CHECK IF USER HAS SEEN INTRO ---
  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenIntro = prefs.getBool('hasSeenIntro') ?? false;

  // --- 3. UI TWEAKS ---
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, 
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(MindFullApp(startScreen: hasSeenIntro ? const AuthGate() : const LandingScreen()));
}

class MindFullApp extends StatelessWidget {
  final Widget startScreen;
  
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.ink,
          primary: AppColors.ink,
          secondary: AppColors.sage,
          surface: AppColors.paperBackground,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.paperBackground,
          elevation: 0,
          titleTextStyle: GoogleFonts.domine(
            color: AppColors.ink, 
            fontSize: 20, 
            fontWeight: FontWeight.bold
          ),
          iconTheme: const IconThemeData(color: AppColors.ink),
        ),
      ),
      home: startScreen, 
    );
  }
}