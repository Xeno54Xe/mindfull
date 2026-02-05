import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/colors.dart';

// IMPORT YOUR TABS
import 'tabs/reflect_tab.dart';
import 'tabs/sanctuary_tab.dart';
import 'tabs/patterns_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Default to Index 0 (Reflect Tab) as the Home
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const ReflectTab(),    // Index 0: Write
    const SanctuaryTab(),  // Index 1: Memory
    const PatternsTab(),   // Index 2: Analysis
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paperBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.paperBackground,
          border: Border(top: BorderSide(color: AppColors.stone.withOpacity(0.1))),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: BottomNavigationBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            selectedItemColor: AppColors.sage,
            unselectedItemColor: AppColors.stone.withOpacity(0.5),
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: true,
            showUnselectedLabels: false,
            selectedLabelStyle: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, height: 1.5),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(FontAwesomeIcons.penNib, size: 20),
                activeIcon: Icon(FontAwesomeIcons.penNib, size: 22),
                label: "Reflect",
              ),
              BottomNavigationBarItem(
                icon: Icon(FontAwesomeIcons.bookOpen, size: 20),
                activeIcon: Icon(FontAwesomeIcons.bookOpen, size: 22),
                label: "Sanctuary",
              ),
              BottomNavigationBarItem(
                icon: Icon(FontAwesomeIcons.chartPie, size: 20),
                activeIcon: Icon(FontAwesomeIcons.chartPie, size: 22),
                label: "Patterns",
              ),
            ],
          ),
        ),
      ),
    );
  }
}