import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_gate.dart';
import 'services/theme_provider.dart';
import 'screens/landing_screen.dart';
import 'theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint("Firebase already initialized. Continuing...");
  }

  // 2. Intro flag + theme preference
  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenIntro = prefs.getBool('hasSeenIntro') ?? false;

  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  // 3. Status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    ChangeNotifierProvider.value(
      value: themeProvider,
      child: MindFullApp(
        startScreen: hasSeenIntro ? const AuthGate() : const LandingScreen(),
      ),
    ),
  );
}

class MindFullApp extends StatelessWidget {
  final Widget startScreen;
  const MindFullApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'MindFull',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme:     _buildTheme(AppThemeColors.light, Brightness.light),
      darkTheme: _buildTheme(AppThemeColors.dark,  Brightness.dark),
      home: startScreen,
    );
  }

  ThemeData _buildTheme(AppThemeColors c, Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: c.background,
      primaryColor: c.ink,
      useMaterial3: true,
      extensions: [c],
      textTheme: GoogleFonts.latoTextTheme().apply(
        bodyColor: c.ink,
        displayColor: c.ink,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.sage,
        brightness: brightness,
        primary: c.ink,
        secondary: AppColors.sage,
        surface: c.background,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        elevation: 0,
        titleTextStyle: GoogleFonts.domine(
          color: c.ink,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: c.ink),
      ),
      dialogBackgroundColor: c.card,
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.background),
      dividerColor: c.stone.withValues(alpha: 0.15),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.sage : c.stone,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.sage.withValues(alpha: 0.4)
              : c.stone.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}
