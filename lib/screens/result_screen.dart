import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../theme/colors.dart';

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const ResultScreen({super.key, required this.data});

  Future<void> _launchSpotify(BuildContext context) async {
    final Uri url = Uri.parse("https://open.spotify.com/search/"); // Search fallback  gotta update this later
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final String mood = data['mood'] ?? "Reflective";
    final String artist = data['artist'] ?? "Unknown Artist";
    final String track = data['track_name'] ?? "Unknown Track";
    final String reason = data['reason'] ?? "Just a vibe.";
    final String imageUrl = data['image_url'] ?? "";
    final int score = data['score'] ?? 5;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. BACKGROUND (Subtle Gradient based on Dark/Light)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDarkMode 
                  ? [Colors.black, const Color(0xFF1A1A1A)] 
                  : [Colors.white, const Color(0xFFF5F5F5)],
              ),
            ),
          ),

          // 2. CONTENT
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text("ANALYSIS COMPLETE", style: GoogleFonts.lato(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 48), // Balance
                    ],
                  ),
                  
                  const Spacer(),

                  // BIG MOOD TEXT
                  Text(mood.toUpperCase(), 
                    style: GoogleFonts.domine(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: -1)
                  ),
                  
                  // Score Badge
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text("VIBE SCORE: $score / 10", style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),

                  // ALBUM ART (Shadowed & Centered)
                  Container(
                    height: 280, width: 280,
                    decoration: BoxDecoration(
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 15))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(0), // Sharp edges = Editorial
                      child: Image.network(imageUrl, fit: BoxFit.cover),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // TRACK INFO
                  Text(track, textAlign: TextAlign.center, style: GoogleFonts.domine(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("by $artist", style: GoogleFonts.lato(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey)),
                  
                  const SizedBox(height: 30),

                  // REASON QUOTE
                  Text('"$reason"', 
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(fontSize: 14, height: 1.5, color: Colors.grey[600])
                  ),

                  const Spacer(),

                  // LISTEN BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: () => _launchSpotify(context),
                      icon: const Icon(FontAwesomeIcons.spotify, size: 18),
                      label: Text("LISTEN ON SPOTIFY", style: GoogleFonts.lato(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDarkMode ? Colors.white : Colors.black,
                        side: BorderSide(color: isDarkMode ? Colors.white : Colors.black),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}