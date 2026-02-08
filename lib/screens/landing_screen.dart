import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_gate.dart'; // To navigate after finishing
import '../theme/colors.dart';
import '../widgets/paper_background.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final PageController _controller = PageController();
  bool onLastPage = false;

  // --- THE LOGIC: SAVE & NAVIGATE ---
  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenIntro', true); // Mark as seen!

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthGate()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaperBackground(
        child: Stack(
          children: [
            // 1. THE SLIDES
            PageView(
              controller: _controller,
              onPageChanged: (index) {
                setState(() => onLastPage = (index == 2));
              },
              children: const [
                _IntroSlide(
                  icon: FontAwesomeIcons.featherPointed,
                  title: "Unload Your Mind.",
                  subtitle: "A safe space to write your thoughts, big or small. No judgment, just clarity.",
                ),
                _IntroSlide(
                  icon: FontAwesomeIcons.headphonesSimple,
                  title: "Soundtrack Your Life.",
                  subtitle: "We analyze your mood and curate the perfect Spotify playlist to match your vibe.",
                ),
                _IntroSlide(
                  icon: FontAwesomeIcons.wandMagicSparkles,
                  title: "Discover Yourself.",
                  subtitle: "Visualize your emotional trends and uncover the hidden patterns in your life.",
                ),
              ],
            ),

            // 2. BOTTOM CONTROLS
            Container(
              alignment: const Alignment(0, 0.85),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // SKIP BUTTON
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: Text("SKIP", style: GoogleFonts.lato(color: AppColors.stone, fontWeight: FontWeight.bold)),
                  ),

                  // DOT INDICATOR
                  SmoothPageIndicator(
                    controller: _controller,
                    count: 3,
                    effect: const WormEffect(
                      activeDotColor: AppColors.ink,
                      dotColor: Color(0xFFD6D3C8),
                      dotHeight: 10,
                      dotWidth: 10,
                    ),
                  ),

                  // NEXT / DONE BUTTON
                  onLastPage
                      ? TextButton(
                          onPressed: _completeOnboarding,
                          child: Text("START", style: GoogleFonts.lato(color: AppColors.sage, fontWeight: FontWeight.bold)),
                        )
                      : TextButton(
                          onPressed: () {
                            _controller.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeIn);
                          },
                          child: Text("NEXT", style: GoogleFonts.lato(color: AppColors.ink, fontWeight: FontWeight.bold)),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroSlide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _IntroSlide({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: AppColors.ink)
              .animate().fade(duration: 600.ms).scale(delay: 200.ms),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.domine(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.ink),
          ).animate().fade(delay: 300.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 20),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(fontSize: 16, height: 1.5, color: AppColors.stone),
          ).animate().fade(delay: 500.ms),
        ],
      ),
    );
  }
}