import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart'; 
import 'package:intl/intl.dart'; 
import 'package:speech_to_text/speech_to_text.dart' as stt; 
import 'package:avatar_glow/avatar_glow.dart'; 
import '../theme/colors.dart';
import '../widgets/paper_background.dart';
import 'result_screen.dart';

class WriteScreen extends StatefulWidget {
  const WriteScreen({super.key});

  @override
  State<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends State<WriteScreen> {
  final TextEditingController _journalController = TextEditingController();
  bool _isLoading = false;
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _journalController.text = val.recognizedWords;
              _journalController.selection = TextSelection.fromPosition(TextPosition(offset: _journalController.text.length));
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<Position?> _determinePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
      return await Geolocator.getCurrentPosition();
    } catch (e) { return null; }
  }

  Future<void> analyzeAndRedirect() async {
    final text = _journalController.text;
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null) return;

    setState(() => _isLoading = true);

    try {
      Position? position = await _determinePosition();
      String timeNow = DateFormat('h:mm a').format(DateTime.now());
      double lat = position?.latitude ?? 0.0;
      double lon = position?.longitude ?? 0.0;

      final response = await http.post(
        Uri.parse("http://localhost:8000/analyze"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({ "text": text, "lat": lat, "lon": lon, "local_time": timeNow }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('entries').add({
          'text': text,
          'mood': data['mood'],
          'artist': data['artist'],
          'track_name': data['track_name'],
          'image_url': data['image_url'],
          'timestamp': FieldValue.serverTimestamp(),
          'weather_context': lat != 0.0 ? "Real Weather" : "No Loc",
          'mood_score': data['score'] ?? 5,
        });
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ResultScreen(data: data)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String dateStr = DateFormat('MMMM d, yyyy').format(DateTime.now()).toUpperCase();

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.stone),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(dateStr, style: GoogleFonts.lato(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppColors.stone)),
                    const SizedBox(width: 48), 
                  ],
                ),
                const SizedBox(height: 40),

                Text("Unload your mind.", style: GoogleFonts.domine(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.ink)),
                const SizedBox(height: 10),
                Text(_isListening ? "Listening..." : "Tap the mic or write freely.", style: GoogleFonts.lato(fontSize: 14, color: _isListening ? AppColors.clay : AppColors.stone)),
                
                const SizedBox(height: 30),

                Expanded(
                  child: TextField(
                    controller: _journalController,
                    maxLines: null, 
                    keyboardType: TextInputType.multiline,
                    cursorColor: AppColors.ink,
                    style: GoogleFonts.lato(fontSize: 20, height: 1.6, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: "Today I felt...",
                      hintStyle: GoogleFonts.domine(color: AppColors.stone.withOpacity(0.4), fontSize: 20, fontStyle: FontStyle.italic),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                // Footer Controls
                Row(
                  children: [
                    AvatarGlow(
                      animate: _isListening,
                      glowColor: AppColors.clay,
                      child: FloatingActionButton(
                        heroTag: 'mic',
                        onPressed: _listen,
                        backgroundColor: _isListening ? AppColors.clay : Colors.white,
                        elevation: 2,
                        child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.white : AppColors.ink),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : analyzeAndRedirect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), 
                            elevation: 0,
                          ),
                          child: _isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                            : Text("ANALYZE", style: GoogleFonts.lato(fontWeight: FontWeight.bold, letterSpacing: 2)),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}