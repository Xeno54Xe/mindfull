import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart'; 
import 'services/auth_gate.dart'; // <--- IMPORT THIS
import 'theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MindFullApp());
}

class MindFullApp extends StatelessWidget {
  const MindFullApp({super.key});

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
      // THE GATEKEEPER - This handles Login -> Onboarding -> MainScreen flow
      home: const AuthGate(), 
    );
  }
}