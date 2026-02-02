import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../theme/colors.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool onLastPage = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0, height: MediaQuery.of(context).size.height * 0.65,
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.darkAccent : Colors.black,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(200), bottomRight: Radius.circular(200)),
              ),
            ),
          ),
          PageView(
            controller: _controller,
            onPageChanged: (index) => setState(() => onLastPage = (index == 2)),
            children: const [
              _OnboardingPage(title: "MindFull", subtitle: "A gentle space to empty your mind and fill your heart."),
              _OnboardingPage(title: "Reflect", subtitle: "Track your moods and discover the patterns in your life."),
              _OnboardingPage(title: "Heal", subtitle: "Get personalized music aimed at matching your vibe."),
            ],
          ),
          Container(
            alignment: const Alignment(0, 0.85),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SmoothPageIndicator(
                  controller: _controller, count: 3,
                  effect: WormEffect(activeDotColor: isDarkMode ? AppColors.darkAccent : AppColors.primaryButton, dotColor: Colors.grey.withOpacity(0.5), dotHeight: 10, dotWidth: 10),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _controller.jumpToPage(2),
                        child: Text("Skip", style: GoogleFonts.merriweather(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge!.color)),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (onLastPage) {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                          } else {
                            _controller.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeIn);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 30),
                          decoration: BoxDecoration(color: AppColors.primaryButton, borderRadius: BorderRadius.circular(30)),
                          child: Text(onLastPage ? "Start" : "Next", style: GoogleFonts.merriweather(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String title;
  final String subtitle;

  const _OnboardingPage({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Instead of fixed 450px, use Spacer to push content down dynamically
        const Spacer(flex: 6), 
        
        Text(
          title,
          style: GoogleFonts.domine(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge!.color,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.7),
            ),
          ),
        ),
        
        // Instead of fixed 180px, use Spacer to keep distance from bottom buttons
        const Spacer(flex: 2), 
      ],
    );
  }
}