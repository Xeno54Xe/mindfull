import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; 
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../theme/colors.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class WritingPage extends StatefulWidget {
  final String prompt;
  final double moodValue;
  final List<String> selectedTags;
  final String weatherContext;
  final String city;

  const WritingPage({
    super.key,
    required this.prompt,
    required this.moodValue,
    required this.selectedTags,
    required this.weatherContext,
    required this.city,
  });

  @override
  State<WritingPage> createState() => _WritingPageState();
}

class _WritingPageState extends State<WritingPage> {
  final TextEditingController _journalController = TextEditingController();
  bool _isSaving = false;

  // --- SMART URL DETECTION ---
  String get _backendUrl {
    // REPLACE THIS STRING with your actual Render URL
    const String liveUrl = "https://mindfull-backend-15b6.onrender.com"; 
    
    if (kIsWeb) return liveUrl; 
    return liveUrl; // Always use live URL for the APK
  }

  Future<void> _saveEntry() async {
    if (_journalController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      String timeString = "${now.hour}:${now.minute.toString().padLeft(2, '0')}";
      final prefs = await SharedPreferences.getInstance();
      final musicProfile = prefs.getString('music_profile') ?? "General Pop";

      // 1. CALL AI
      Map<String, dynamic> aiAnalysis = {};
      try {
        final response = await http.post(
          Uri.parse("$_backendUrl/analyze"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "text": _journalController.text,
            "local_time": timeString,
            "music_profile": musicProfile
          }),
        );

        if (response.statusCode == 200) aiAnalysis = jsonDecode(response.body);
      } catch (e) {
        print("⚠️ AI Offline");
      }

      // 2. SAVE TO FIREBASE
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('entries')
          .add({
        'content': _journalController.text,
        'mood_score': aiAnalysis['score'] ?? widget.moodValue,
        'mood_label': aiAnalysis['mood'] ?? "Reflective",
        'tags': widget.selectedTags,
        'track_name': aiAnalysis['track_name'],
        'artist': aiAnalysis['artist'],
        'image_url': aiAnalysis['image_url'], 
        'timestamp': FieldValue.serverTimestamp(),
        'weather_context': widget.weatherContext,
        'location_city': widget.city,
        'prompt_used': widget.prompt, 
      });

      if (mounted) {
        // 3. SHOW THE RESULT POPUP
        _showAnalysisResult(aiAnalysis);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: $e"),
          backgroundColor: AppColors.clay,
        ));
      }
      setState(() => _isSaving = false);
    }
  }

  // --- THE FIXED "VIBE REPORT" POPUP ---
  void _showAnalysisResult(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true, // Allows full height if needed
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65, // Max height
        padding: const EdgeInsets.fromLTRB(30, 30, 30, 0),
        decoration: const BoxDecoration(
          color: AppColors.paperBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        // FIX: Wrapped in SingleChildScrollView to prevent overflow and allow scrolling
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(FontAwesomeIcons.circleCheck, color: AppColors.sage, size: 50),
              const SizedBox(height: 20),
              Text("Memory Captured", style: GoogleFonts.domine(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.ink)),
              Text("Here is your vibe report.", style: GoogleFonts.lato(color: AppColors.stone)),
              const SizedBox(height: 30),

              // MOOD SCORE
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.sage.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${data['mood'] ?? 'Reflective'} • ${data['score'] ?? widget.moodValue.toInt()}/10",
                  style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.sage),
                ),
              ),
              const SizedBox(height: 20),

              // SONG CARD
              if (data['track_name'] != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.stone.withOpacity(0.1), blurRadius: 20)],
                  ),
                  child: Row(
                    children: [
                      // ALBUM ART
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: data['image_url'] != null 
                          ? Image.network(data['image_url'], width: 60, height: 60, fit: BoxFit.cover)
                          : Container(width: 60, height: 60, color: AppColors.ink, child: const Icon(Icons.music_note, color: Colors.white)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['track_name'], style: GoogleFonts.domine(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(data['artist'], style: GoogleFonts.lato(color: AppColors.stone), maxLines: 1),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_circle_fill, color: Color(0xFF1DB954), size: 40),
                        onPressed: () async {
                           final query = Uri.encodeComponent("${data['track_name']} ${data['artist']}");
                           final url = Uri.parse("https://open.spotify.com/search/$query");
                           await launchUrl(url, mode: LaunchMode.externalApplication);
                        },
                      )
                    ],
                  ),
                ),

              const SizedBox(height: 20),
              // REASONING
              if (data['reason'] != null)
                Text(
                  "\"${data['reason']}\"",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(fontSize: 14, fontStyle: FontStyle.italic, color: AppColors.stone),
                ),
              
              const SizedBox(height: 30),
              
              // CONTINUE BUTTON
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close Modal
                    Navigator.pop(context); // Close Writing Page
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text("BACK TO HOME", style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 40), // Bottom spacer
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FIX: Prevents layout breaking when keyboard opens
      resizeToAvoidBottomInset: true, 
      backgroundColor: AppColors.paperBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton(
              onPressed: _isSaving ? null : _saveEntry,
              style: TextButton.styleFrom(
                backgroundColor: _isSaving ? Colors.transparent : AppColors.sage.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sage))
                : Text("DONE", style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: AppColors.sage)),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PROMPT HEADER
              Text("THINKING ABOUT:", style: GoogleFonts.lato(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold, color: AppColors.stone)),
              const SizedBox(height: 10),
              Text(widget.prompt, style: GoogleFonts.domine(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.ink)),
              
              const SizedBox(height: 30),
              const Divider(color: Color(0xFFEEEBE0)),
              const SizedBox(height: 20),

              // WRITING AREA
              Expanded(
                child: TextField(
                  controller: _journalController,
                  maxLines: null,
                  expands: true,
                  style: GoogleFonts.lato(fontSize: 18, height: 1.8, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: "Let it flow...",
                    hintStyle: GoogleFonts.lato(color: AppColors.stone.withOpacity(0.5), fontSize: 18),
                    border: InputBorder.none,
                  ),
                ),
              ),
              
              // FIX: Removed the manual SizedBox that was causing the 39px overflow
            ],
          ),
        ),
      ),
    );
  }
}