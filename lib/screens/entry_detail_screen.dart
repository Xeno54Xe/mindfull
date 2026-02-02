import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';

class EntryDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const EntryDetailScreen({super.key, required this.data});

  Future<void> _launchSpotify(BuildContext context) async {
    final String track = data['track_name'] ?? "";
    // Simple search link if we don't have the direct URI
    final Uri url = Uri.parse("https://open.spotify.com/search/$track");
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Extract Data safely
    final String text = data['text'] ?? "";
    final String mood = data['mood'] ?? "Unknown";
    final String artist = data['artist'] ?? "Unknown";
    final String track = data['track_name'] ?? "Unknown";
    final String imageUrl = data['image_url'] ?? "";
    final String weather = data['weather_context'] ?? "";
    final int score = data['mood_score'] ?? 5;
    
    // Timestamp handling
    final DateTime date = data['timestamp'] != null 
        ? (data['timestamp'] as dynamic).toDate() 
        : DateTime.now();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // We use a CustomScrollView for that "Elastic" feel when scrolling
      body: CustomScrollView(
        slivers: [
          // 1. BIG IMAGE HEADER
          SliverAppBar(
            expandedHeight: 400.0,
            floating: false,
            pinned: true,
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover, 
                      color: Colors.black.withOpacity(0.3), colorBlendMode: BlendMode.darken)
                  : Container(color: Colors.grey),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 2. THE CONTENT
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              transform: Matrix4.translationValues(0.0, -30.0, 0.0), // Overlap effect
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Date & Score
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMMM d, yyyy').format(date),
                        style: GoogleFonts.lato(fontSize: 14, color: Colors.grey, letterSpacing: 1),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getScoreColor(score).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getScoreColor(score).withOpacity(0.5)),
                        ),
                        child: Text("Vibe: $score/10", 
                          style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: _getScoreColor(score))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Mood Title
                  Text(mood, style: GoogleFonts.domine(fontSize: 36, fontWeight: FontWeight.bold)),
                  
                  // Song Info
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(FontAwesomeIcons.spotify, size: 16, color: Color(0xFF1DB954)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text("$track • $artist", 
                          style: GoogleFonts.lato(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 30),

                  // The Journal Entry (The Aesthetic Part)
                  Text(
                    text,
                    style: GoogleFonts.lato(
                      fontSize: 18, 
                      height: 1.8, // Tall line height for readability
                      color: Theme.of(context).textTheme.bodyLarge!.color
                    ),
                  ),

                  const SizedBox(height: 40),
                  
                  // Context Details (Small footer)
                  if (weather.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.cloud_queue, size: 14, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text("Context: $weather", style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    
                  const SizedBox(height: 40),
                  
                  // Re-Listen Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton(
                      onPressed: () => _launchSpotify(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.2)),
                      ),
                      child: Text("Play on Spotify", style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge!.color)),
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 8) return Colors.green;
    if (score >= 5) return Colors.amber;
    return Colors.red;
  }
}