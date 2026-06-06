import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'write_screen.dart';
import 'calendar_screen.dart';
import 'tabs/reflect_tab.dart';
import 'tabs/patterns_tab.dart';
import 'tabs/sanctuary_tab.dart';
import 'tabs/profile_tab.dart';
import '../widgets/paper_background.dart';
import '../theme/colors.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  List<Widget> get _tabs => [
        ReflectTab(onHistoryTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CalendarScreen()),
        )),
        const PatternsTab(),
        const SizedBox(),
        const SanctuaryTab(),
        const ProfileTab(),
      ];

  void _onItemTapped(int index) {
    if (index == 2) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: context.colors.background,
      body: PaperBackground(child: _tabs[_currentIndex]),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        height: 65,
        width: 65,
        child: FloatingActionButton(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WriteScreen())),
          backgroundColor: context.colors.ink,
          elevation: 5,
          shape: const CircleBorder(),
          child: const FaIcon(FontAwesomeIcons.penNib,
              color: Colors.white, size: 24),
        ),
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        color: Colors.transparent,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(icon: Icons.grid_view_rounded,  index: 0),
              _buildNavItem(icon: Icons.pie_chart_rounded,  index: 1),
              const SizedBox(width: 40),
              _buildNavItem(icon: Icons.music_note_rounded, index: 3),
              _buildNavItem(icon: Icons.person_rounded,     index: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required int index}) {
    final isSelected = _currentIndex == index;
    return IconButton(
      icon: Icon(icon, size: 28),
      color: isSelected
          ? context.colors.ink
          : context.colors.stone.withValues(alpha: 0.5),
      onPressed: () => _onItemTapped(index),
    );
  }
}
