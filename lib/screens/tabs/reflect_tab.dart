import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../theme/colors.dart';
import '../writing_page.dart'; // Make sure this import exists

class ReflectTab extends StatefulWidget {
  const ReflectTab({super.key});

  @override
  State<ReflectTab> createState() => _ReflectTabState();
}

class _ReflectTabState extends State<ReflectTab> {
  // --- 2D EMOTION STATE ---
  // X-Axis = Mood (Valence): 0 (Unpleasant) -> 10 (Pleasant)
  // Y-Axis = Energy (Arousal): 0 (Low) -> 10 (High)
  double _moodValue = 5.0;
  double _energyValue = 5.0;
  
  // --- CONTEXT TAGS ---
  final List<String> _allTags = ["Work", "Study", "Social", "Family", "Romance", "Sleep", "Health", "Finance", "Nature", "Gaming"];
  final Set<String> _selectedTags = {};

  // --- WEATHER STATE ---
  String _weatherLabel = "Loading...";
  IconData _weatherIcon = FontAwesomeIcons.cloud;
  Color _weatherColor = AppColors.stone;
  String _city = "Locating...";
  bool _isLoadingWeather = true;

  // --- SHUFFLE DECK ---
  final List<String> _prompts = [
    "How are you truly feeling right now?",
    "What is one thing you can control today?",
    "Who made you smile recently?",
    "What is a small win you had today?",
    "Describe the weather inside your head.",
    "What is draining your energy?",
    "What are you looking forward to?",
  ];
  late String _currentPrompt;

  @override
  void initState() {
    super.initState();
    _currentPrompt = _prompts[Random().nextInt(_prompts.length)];
    _fetchLiveWeather();
  }

  // --- WEATHER FETCHER ---
  Future<void> _fetchLiveWeather() async {
    try {
      final locResponse = await http.get(Uri.parse('http://ip-api.com/json'));
      if (locResponse.statusCode != 200) throw Exception("Location Error");
      final locData = jsonDecode(locResponse.body);
      double lat = locData['lat'];
      double lon = locData['lon'];
      String city = locData['city'] ?? "Unknown";

      final weatherUrl = "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true";
      final weatherResponse = await http.get(Uri.parse(weatherUrl));
      if (weatherResponse.statusCode != 200) throw Exception("Weather API Error");
      final weatherData = jsonDecode(weatherResponse.body);
      
      int code = weatherData['current_weather']['weathercode'];
      double temp = weatherData['current_weather']['temperature'];
      
      String label = "Clear";
      IconData icon = FontAwesomeIcons.sun;
      Color color = Colors.orange;

      if (code >= 95) { label = "Stormy"; icon = FontAwesomeIcons.cloudBolt; color = AppColors.ink; }
      else if (code >= 61) { label = "Rainy"; icon = FontAwesomeIcons.cloudRain; color = Colors.blueGrey; }
      else if (code >= 51) { label = "Drizzle"; icon = FontAwesomeIcons.cloudRain; color = AppColors.sage; }
      else if (code >= 45) { label = "Foggy"; icon = FontAwesomeIcons.smog; color = AppColors.stone; }
      else if (code >= 1) { label = "Cloudy"; icon = FontAwesomeIcons.cloud; color = AppColors.stone; }
      
      if (mounted) {
        setState(() {
          _weatherLabel = "$label • ${temp.toStringAsFixed(0)}°C";
          _weatherIcon = icon;
          _weatherColor = color;
          _city = city;
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weatherLabel = "Tap to Set";
          _city = "Offline";
          _isLoadingWeather = false;
        });
      }
    }
  }

  void _toggleWeatherManual() {
    List<Map<String, dynamic>> options = [
      {"l": "Sunny", "i": FontAwesomeIcons.sun, "c": Colors.orange},
      {"l": "Rainy", "i": FontAwesomeIcons.cloudRain, "c": Colors.blueGrey},
      {"l": "Cloudy", "i": FontAwesomeIcons.cloud, "c": AppColors.stone},
      {"l": "Night", "i": FontAwesomeIcons.moon, "c": AppColors.ink},
    ];
    int idx = options.indexWhere((o) => _weatherLabel.startsWith(o['l']));
    int next = (idx + 1) % options.length;
    setState(() {
      _weatherLabel = options[next]['l'];
      _weatherIcon = options[next]['i'];
      _weatherColor = options[next]['c'];
    });
  }

  void _shufflePrompt() {
    setState(() {
      _currentPrompt = _prompts[Random().nextInt(_prompts.length)];
    });
  }

  // --- NAVIGATION ---
  void _goToWritingPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WritingPage(
          prompt: _currentPrompt,
          moodValue: _moodValue,
          // We pass energy as a specialized tag for now, or you can update WritingPage to accept it directly.
          // To keep it simple without breaking your WritingPage file, I'll append it to tags.
          selectedTags: [..._selectedTags, "Energy: ${_energyValue.toStringAsFixed(1)}"], 
          weatherContext: _weatherLabel,
          city: _city,
        ),
      ),
    );
  }

  // --- HELPER: GET 2D EMOTION LABEL ---
  String _getEmotionLabel() {
    if (_energyValue > 6 && _moodValue > 6) return "EXCITED";
    if (_energyValue > 6 && _moodValue < 4) return "ANXIOUS";
    if (_energyValue < 4 && _moodValue > 6) return "ZEN";
    if (_energyValue < 4 && _moodValue < 4) return "DRAINED";
    if (_moodValue > 4 && _moodValue < 6) return "NEUTRAL";
    return "REFLECTIVE";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paperBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Reflect", style: GoogleFonts.domine(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.ink)),
                  IconButton(
                    icon: const Icon(Icons.history, color: AppColors.stone),
                    onPressed: () {}, 
                  )
                ],
              ),
              const SizedBox(height: 20),

              // WEATHER & DATE
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_city.toUpperCase(), 
                        style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.sage)),
                      Text(DateFormat('MMMM d').format(DateTime.now()), 
                        style: GoogleFonts.domine(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink)),
                    ],
                  ),
                  GestureDetector(
                    onTap: _toggleWeatherManual,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.stone.withOpacity(0.2)),
                        boxShadow: [BoxShadow(color: AppColors.stone.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: _isLoadingWeather 
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sage))
                        : Row(
                            children: [
                              Icon(_weatherIcon, size: 16, color: _weatherColor),
                              const SizedBox(width: 8),
                              Text(_weatherLabel, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ink)),
                            ],
                          ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // 1. PROMPT CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.sage.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: AppColors.sage.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("THOUGHT STARTER", style: GoogleFonts.lato(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold, color: AppColors.sage)),
                        InkWell(
                          onTap: _shufflePrompt,
                          child: const Icon(FontAwesomeIcons.shuffle, size: 14, color: AppColors.sage),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(_currentPrompt, style: GoogleFonts.domine(fontSize: 18, color: AppColors.ink)),
                    const SizedBox(height: 20),
                    
                    // START BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _goToWritingPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sage,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text("WRITE ABOUT THIS", style: GoogleFonts.lato(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    )
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 30),

              // 2. THE VIBE MAP (Double Axis Slider)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("VIBE MAP", style: GoogleFonts.lato(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold, color: AppColors.stone)),
                  Text(_getEmotionLabel(), style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: AppColors.sage)),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double size = constraints.maxWidth;
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.stone.withOpacity(0.2)),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFF0F0), // Red tint (High Energy, Bad Mood)
                              Color(0xFFF0FFF4), // Green tint (High Energy, Good Mood)
                              // Note: Gradients interpolate, so we use 2 corner colors to simulate the field
                            ],
                            stops: [0.2, 0.8],
                          ),
                          boxShadow: [BoxShadow(color: AppColors.stone.withOpacity(0.05), blurRadius: 10)],
                        ),
                        child: Stack(
                          children: [
                            // GRID LINES
                            Center(child: Container(width: 1, height: size, color: AppColors.stone.withOpacity(0.1))),
                            Center(child: Container(width: size, height: 1, color: AppColors.stone.withOpacity(0.1))),
                            
                            // LABELS
                            Positioned(top: 10, left: 0, right: 0, child: Center(child: Text("High Energy", style: GoogleFonts.lato(fontSize: 10, color: AppColors.stone.withOpacity(0.5))))),
                            Positioned(bottom: 10, left: 0, right: 0, child: Center(child: Text("Low Energy", style: GoogleFonts.lato(fontSize: 10, color: AppColors.stone.withOpacity(0.5))))),
                            Positioned(left: 10, top: 0, bottom: 0, child: Center(child: RotatedBox(quarterTurns: -1, child: Text("Unpleasant", style: GoogleFonts.lato(fontSize: 10, color: AppColors.stone.withOpacity(0.5)))))),
                            Positioned(right: 10, top: 0, bottom: 0, child: Center(child: RotatedBox(quarterTurns: -1, child: Text("Pleasant", style: GoogleFonts.lato(fontSize: 10, color: AppColors.stone.withOpacity(0.5)))))),

                            // INTERACTIVE LAYER
                            GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  double dx = details.localPosition.dx.clamp(0.0, size);
                                  double dy = details.localPosition.dy.clamp(0.0, size);
                                  
                                  // Map X (0 to size) -> Mood (0 to 10)
                                  _moodValue = (dx / size) * 10;
                                  
                                  // Map Y (0 to size) -> Energy (10 to 0) -> Inverted because Y=0 is top
                                  _energyValue = 10 - ((dy / size) * 10);
                                });
                              },
                              onTapDown: (details) {
                                setState(() {
                                  double dx = details.localPosition.dx.clamp(0.0, size);
                                  double dy = details.localPosition.dy.clamp(0.0, size);
                                  _moodValue = (dx / size) * 10;
                                  _energyValue = 10 - ((dy / size) * 10);
                                });
                              },
                              child: Container(color: Colors.transparent), // Transparent hit-test layer
                            ),

                            // THE DOT
                            Positioned(
                              left: (_moodValue / 10) * size - 15, // -15 to center the 30px dot
                              top: ((10 - _energyValue) / 10) * size - 15,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: AppColors.ink,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // 3. CONTEXT CHIPS
              Text("WHAT AFFECTED YOU?", style: GoogleFonts.lato(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold, color: AppColors.stone)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _allTags.map((tag) {
                    final isSelected = _selectedTags.contains(tag);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                        backgroundColor: AppColors.cardColor,
                        selectedColor: AppColors.sage,
                        labelStyle: GoogleFonts.lato(
                          color: isSelected ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.bold
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: isSelected ? Colors.transparent : AppColors.stone.withOpacity(0.2)),
                        ),
                        showCheckmark: false,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}