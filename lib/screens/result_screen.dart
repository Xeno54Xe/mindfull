import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';
import '../widgets/paper_background.dart';
import '../services/auth_gate.dart';

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const ResultScreen({super.key, required this.data});

  Future<void> _launchSpotify(String trackName) async {
    final query = Uri.encodeComponent(trackName);
    final url = Uri.parse("https://open.spotify.com/search/$query");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract Data safely
    final String mood = data['mood'] ?? "Neutral";
    final int score = data['score'] ?? 5;
    final String artist = data['artist'] ?? "Unknown Artist";
    final String track = data['track_name'] ?? "Unknown Track";
    final String reason = data['reason'] ?? "Just a vibe.";
    final String imageUrl = data['image_url'] ?? "";

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          // FIX: Added SingleChildScrollView to prevent overflow
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HEADER (Close Button)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("ANALYSIS COMPLETE", style: GoogleFonts.lato(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppColors.stone)),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.ink),
                      onPressed: () {
                        // Go back to the main app (Sanctuary)
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const AuthGate()),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),

                // 2. MOOD SECTION
                Text(mood.toUpperCase(), style: GoogleFonts.domine(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.ink)),
                Text("Mood Score: $score/10", style: GoogleFonts.lato(fontSize: 18, color: AppColors.sage, fontWeight: FontWeight.bold)),
                
                const SizedBox(height: 20),
                
                // 3. ANALYSIS TEXT
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.stone.withOpacity(0.1)),
                  ),
                  child: Text(
                    reason,
                    style: GoogleFonts.lato(fontSize: 16, height: 1.5, color: AppColors.ink),
                  ),
                ),

                const SizedBox(height: 40),

                // 4. MUSIC RECOMMENDATION CARD
                Text("SONG FOR YOU", style: GoogleFonts.lato(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppColors.stone)),
                const SizedBox(height: 15),

                GestureDetector(
                  onTap: () => _launchSpotify("$track $artist"),
                  child: Container(
                    height: 140, // Fixed height for consistency
                    decoration: BoxDecoration(
                      color: AppColors.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                      ],
                    ),
                    child: Row(
                      children: [
                        // Album Art
                        ClipRRect(
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                          child: Image.network(
                            imageUrl,
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              width: 140, height: 140, color: AppColors.stone, 
                              child: const Icon(Icons.music_note, color: Colors.white, size: 40)
                            ),
                          ),
                        ),
                        
                        // Text Info
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(track, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.domine(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink)),
                                const SizedBox(height: 4),
                                Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 14, color: AppColors.stone)),
                                const Spacer(),
                                Row(
                                  children: [
                                    const Icon(FontAwesomeIcons.spotify, size: 16, color: Color(0xFF1DB954)),
                                    const SizedBox(width: 8),
                                    Text("Listen Now", style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1DB954))),
                                  ],
                                )
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // 5. CONTINUE BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                       Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const AuthGate()),
                          (route) => false,
                        );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text("CONTINUE", style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                
                // Extra padding at the bottom so scrolling feels nice
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}