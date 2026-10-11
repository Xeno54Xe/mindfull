import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../theme/colors.dart';
import '../writing_page.dart';
import '../vent_screen.dart';
import 'sanctuary_tab.dart';

/// Immutable data class for a prompt category.
class _PromptCategory {
  final FaIconData icon;
  final Color color;
  final List<String> prompts;
  const _PromptCategory({
    required this.icon,
    required this.color,
    required this.prompts,
  });
}

class ReflectTab extends StatefulWidget {
  final VoidCallback? onHistoryTap;
  const ReflectTab({super.key, this.onHistoryTap});

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
  FaIconData _weatherIcon = FontAwesomeIcons.cloud;
  Color _weatherColor = AppColors.stone;
  String _city = "Locating...";
  bool _isLoadingWeather = true;

  // --- PROMPT CATEGORIES ---
  static const Map<String, _PromptCategory> _categories = {
    'Today': _PromptCategory(
      icon: FontAwesomeIcons.sun,
      color: AppColors.sage,
      prompts: [
        "How are you truly feeling right now?",
        "What is one thing you can control today?",
        "Describe the weather inside your head.",
        "What's one moment today you want to hold onto?",
        "What is draining your energy right now?",
        "What would make today feel complete?",
        "Who or what do you keep thinking about today?",
        "If today had a color, what would it be and why?",
        "What is one small thing you've been avoiding?",
        "How do you want to feel by tonight?",
      ],
    ),
    'Gratitude': _PromptCategory(
      icon: FontAwesomeIcons.heart,
      color: AppColors.clay,
      prompts: [
        "Who made you smile recently?",
        "What is a small win you had today?",
        "Name three things your body did for you today.",
        "What do you have now that you once only wished for?",
        "Who is someone you haven't thanked enough?",
        "What's a simple pleasure you often overlook?",
        "What's something beautiful you noticed this week?",
        "What music, smell, or place makes you feel safe?",
        "What part of your routine are you secretly grateful for?",
        "What problem do you have today that you wouldn't have wanted 5 years ago?",
      ],
    ),
    'Growth': _PromptCategory(
      icon: FontAwesomeIcons.seedling,
      color: Color(0xFFD4A853),
      prompts: [
        "What are you looking forward to?",
        "What is a belief you've changed your mind on recently?",
        "What's one habit you want to build — and why?",
        "What would you do if you knew you couldn't fail?",
        "What skill do you wish you had started learning earlier?",
        "What's a mistake that actually taught you something valuable?",
        "Who do you want to become in the next year?",
        "What's holding you back from a goal you care about?",
        "What would the best version of yourself do differently today?",
        "What are you proud of that you never talk about?",
      ],
    ),
    'Deep': _PromptCategory(
      icon: FontAwesomeIcons.brain,
      color: AppColors.ink,
      prompts: [
        "What does your ideal life actually look like?",
        "What is something you pretend not to care about, but actually do?",
        "If you could change one thing about how people see you, what would it be?",
        "What's a question you keep asking yourself that has no answer yet?",
        "When do you feel most like yourself?",
        "What are you really afraid of, underneath the surface?",
        "What would you regret not doing or saying?",
        "What story do you keep telling yourself that might not be true?",
        "If you wrote a letter to yourself 10 years from now, what would you say?",
        "What does 'a good life' mean to you right now?",
      ],
    ),
  };

  String? _selectedCategory; // null = draw from all
  late String _currentPrompt;

  @override
  void initState() {
    super.initState();
    _currentPrompt = _promptPool()[Random().nextInt(_promptPool().length)];
    _fetchLiveWeather();
  }

  /// Returns the active prompt pool — selected category or all prompts combined.
  List<String> _promptPool() {
    if (_selectedCategory != null) {
      return _categories[_selectedCategory]!.prompts;
    }
    return _categories.values.expand((c) => c.prompts).toList();
  }

  void _selectCategory(String category) {
    setState(() {
      // Tapping the active chip deselects it
      if (_selectedCategory == category) {
        _selectedCategory = null;
      } else {
        _selectedCategory = category;
      }
      final pool = _promptPool();
      _currentPrompt = pool[Random().nextInt(pool.length)];
    });
  }

  // --- WEATHER FETCHER ---
  Future<void> _fetchLiveWeather() async {
    try {
      // FIX: use HTTPS — plain HTTP is blocked on Android 9+ by default
      final locResponse = await http
          .get(Uri.parse('https://ip-api.com/json'))
          .timeout(const Duration(seconds: 10));
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
      FaIconData icon = FontAwesomeIcons.sun;
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
    int idx = options.indexWhere((o) => _weatherLabel.startsWith(o['l'] as String));
    int next = (idx + 1) % options.length;
    setState(() {
      _weatherLabel = options[next]['l'] as String;
      _weatherIcon = options[next]['i'] as FaIconData;
      _weatherColor = options[next]['c'] as Color;
    });
  }

  void _shufflePrompt() {
    final pool = _promptPool();
    // Avoid showing the same prompt twice in a row if pool allows
    String next = _currentPrompt;
    if (pool.length > 1) {
      while (next == _currentPrompt) {
        next = pool[Random().nextInt(pool.length)];
      }
    }
    setState(() => _currentPrompt = next);
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
      backgroundColor: context.colors.background,
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
                  Text("Reflect", style: GoogleFonts.domine(fontSize: 32, fontWeight: FontWeight.bold, color: context.colors.ink)),
                  IconButton(
                    icon: Icon(Icons.history, color: context.colors.stone),
                    onPressed: widget.onHistoryTap,
                    tooltip: "View past entries",
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
                        style: GoogleFonts.domine(fontSize: 22, fontWeight: FontWeight.bold, color: context.colors.ink)),
                    ],
                  ),
                  GestureDetector(
                    onTap: _toggleWeatherManual,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: context.colors.stone.withValues(alpha: 0.2)),
                        boxShadow: [BoxShadow(color: context.colors.stone.withValues(alpha: 0.05), blurRadius: 10)],
                      ),
                      child: _isLoadingWeather 
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sage))
                        : Row(
                            children: [
                              FaIcon(_weatherIcon, size: 16, color: _weatherColor),
                              const SizedBox(width: 8),
                              Text(_weatherLabel, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.ink)),
                            ],
                          ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // STREAK CARD
              const _StreakCard(),

              const SizedBox(height: 24),

              // 1. PROMPT CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedCategory != null
                        ? _categories[_selectedCategory]!.color.withValues(alpha: 0.35)
                        : AppColors.sage.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_selectedCategory != null
                              ? _categories[_selectedCategory]!.color
                              : AppColors.sage)
                          .withValues(alpha: 0.07),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "THOUGHT STARTER",
                          style: GoogleFonts.lato(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                            color: _selectedCategory != null
                                ? _categories[_selectedCategory]!.color
                                : AppColors.sage,
                          ),
                        ),
                        InkWell(
                          onTap: _shufflePrompt,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: FaIcon(
                              FontAwesomeIcons.shuffle,
                              size: 14,
                              color: _selectedCategory != null
                                  ? _categories[_selectedCategory]!.color
                                  : AppColors.sage,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Category chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _categories.entries.map((entry) {
                          final isActive = _selectedCategory == entry.key;
                          final cat = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => _selectCategory(entry.key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? cat.color
                                      : cat.color.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: isActive
                                        ? cat.color
                                        : cat.color.withValues(alpha: 0.25),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FaIcon(
                                      cat.icon,
                                      size: 11,
                                      color: isActive
                                          ? Colors.white
                                          : cat.color,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      entry.key,
                                      style: GoogleFonts.lato(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isActive
                                            ? Colors.white
                                            : cat.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Divider(
                        color: context.colors.stone.withValues(alpha: 0.12),
                        height: 1),
                    const SizedBox(height: 16),

                    // Prompt text — fades when it changes
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: SizedBox(
                        key: ValueKey(_currentPrompt),
                        width: double.infinity,
                        child: Text(
                          _currentPrompt,
                          style: GoogleFonts.domine(
                              fontSize: 18,
                              color: context.colors.ink,
                              height: 1.45),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Write button — accent color follows active category
                    SizedBox(
                      width: double.infinity,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: ElevatedButton(
                          onPressed: _goToWritingPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedCategory != null
                                ? _categories[_selectedCategory]!.color
                                : AppColors.sage,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            "WRITE ABOUT THIS",
                            style: GoogleFonts.lato(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // VENT entry point
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VentScreen(),
                          ),
                        ),
                        icon: const FaIcon(
                          FontAwesomeIcons.fire,
                          size: 13,
                        ),
                        label: Text(
                          "NEED TO VENT?",
                          style: GoogleFonts.lato(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.clay,
                          side: BorderSide(
                            color: AppColors.clay.withValues(alpha: 0.45),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 30),

              // 2. THE VIBE MAP (Double Axis Slider)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("VIBE MAP", style: GoogleFonts.lato(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold, color: context.colors.stone)),
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
                          border: Border.all(color: context.colors.stone.withValues(alpha:0.2)),
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
                          boxShadow: [BoxShadow(color: context.colors.stone.withValues(alpha:0.05), blurRadius: 10)],
                        ),
                        child: Stack(
                          children: [
                            // GRID LINES
                            Center(child: Container(width: 1, height: size, color: context.colors.stone.withValues(alpha:0.1))),
                            Center(child: Container(width: size, height: 1, color: context.colors.stone.withValues(alpha:0.1))),
                            
                            // LABELS
                            Positioned(top: 10, left: 0, right: 0, child: Center(child: Text("High Energy", style: GoogleFonts.lato(fontSize: 10, color: context.colors.stone.withValues(alpha:0.5))))),
                            Positioned(bottom: 10, left: 0, right: 0, child: Center(child: Text("Low Energy", style: GoogleFonts.lato(fontSize: 10, color: context.colors.stone.withValues(alpha:0.5))))),
                            Positioned(left: 10, top: 0, bottom: 0, child: Center(child: RotatedBox(quarterTurns: -1, child: Text("Unpleasant", style: GoogleFonts.lato(fontSize: 10, color: context.colors.stone.withValues(alpha:0.5)))))),
                            Positioned(right: 10, top: 0, bottom: 0, child: Center(child: RotatedBox(quarterTurns: -1, child: Text("Pleasant", style: GoogleFonts.lato(fontSize: 10, color: context.colors.stone.withValues(alpha:0.5)))))),

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
                                  color: context.colors.ink,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.2), blurRadius: 10, offset: const Offset(0, 5))],
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
              Text("WHAT AFFECTED YOU?", style: GoogleFonts.lato(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold, color: context.colors.stone)),
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
                        backgroundColor: context.colors.card,
                        selectedColor: AppColors.sage,
                        labelStyle: GoogleFonts.lato(
                          color: isSelected ? Colors.white : context.colors.ink,
                          fontWeight: FontWeight.bold
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: isSelected ? Colors.transparent : context.colors.stone.withValues(alpha:0.2)),
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

// ═════════════════════════════════════════════════════════════════════════════
// STREAK FEATURE
// ═════════════════════════════════════════════════════════════════════════════

/// Pure data holder — computed once per stream event.
class _StreakData {
  final int streak;
  final List<bool> last7; // index 0 = 6 days ago, index 6 = today
  final bool wroteToday;

  const _StreakData({
    required this.streak,
    required this.last7,
    required this.wroteToday,
  });

  factory _StreakData.empty() =>
      const _StreakData(streak: 0, last7: [false, false, false, false, false, false, false], wroteToday: false);
}

/// Stateless streak card — owns its own StreamBuilder so it doesn't
/// force the entire ReflectTab to rebuild when Firestore ticks.
class _StreakCard extends StatelessWidget {
  const _StreakCard();

  // ── helpers ────────────────────────────────────────────────────────────────

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static _StreakData _compute(List<QueryDocumentSnapshot> docs) {
    final writtenDates = <String>{};
    for (final doc in docs) {
      final raw = doc.data() as Map<String, dynamic>;
      if (raw['timestamp'] != null) {
        final dt = (raw['timestamp'] as Timestamp).toDate();
        writtenDates.add(_fmt(dt));
      }
    }

    final today = DateTime.now();
    final todayStr = _fmt(today);
    final yestStr  = _fmt(today.subtract(const Duration(days: 1)));

    // Grace window: streak is alive if the user wrote today or yesterday.
    final int startOffset = writtenDates.contains(todayStr)
        ? 0
        : writtenDates.contains(yestStr)
            ? 1
            : -1; // broken

    int streak = 0;
    if (startOffset >= 0) {
      for (int i = startOffset; i < 90; i++) {
        if (writtenDates.contains(_fmt(today.subtract(Duration(days: i))))) {
          streak++;
        } else {
          break;
        }
      }
    }

    final last7 = List<bool>.generate(
      7,
      (i) => writtenDates.contains(_fmt(today.subtract(Duration(days: 6 - i)))),
    );

    return _StreakData(
      streak: streak,
      last7: last7,
      wroteToday: writtenDates.contains(todayStr),
    );
  }

  static String _motivation(int streak) {
    if (streak == 0) return "Write today — start your streak.";
    if (streak == 1) return "Day one. The hardest step is done.";
    if (streak == 2) return "Two in a row — you're doing it.";
    if (streak < 7)  return "Building momentum. Keep going.";
    if (streak == 7) return "One full week. That's real.";
    if (streak < 14) return "A habit is forming. Don't stop.";
    if (streak < 21) return "Two weeks strong. This is becoming you.";
    if (streak < 30) return "You're consistent. That's rare.";
    if (streak < 60) return "A month of clarity. You've changed.";
    return "Unstoppable. This is who you are.";
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('entries')
          .where('timestamp',
              isGreaterThan: Timestamp.fromDate(
                DateTime.now().subtract(const Duration(days: 90)),
              ))
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.hasData
            ? _compute(snapshot.data!.docs)
            : _StreakData.empty();
        return _buildCard(context, data);
      },
    );
  }

  Widget _buildCard(BuildContext context, _StreakData data) {
    final today = DateTime.now();
    // Single-letter day labels: M T W T F S S
    final dayLabels = List.generate(
      7,
      (i) => DateFormat('E').format(today.subtract(Duration(days: 6 - i)))[0],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.clay.withValues(alpha: 0.07),
            context.colors.card,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: data.streak > 0
              ? AppColors.clay.withValues(alpha: 0.22)
              : context.colors.stone.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.clay.withValues(alpha: data.streak > 0 ? 0.07 : 0.02),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── TOP: flame icon + streak number + today badge ───────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Flame / feather icon in a warm circle
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: data.streak > 0
                      ? AppColors.clay.withValues(alpha: 0.12)
                      : context.colors.stone.withValues(alpha: 0.07),
                ),
                child: Center(
                  child: FaIcon(
                    data.streak > 0
                        ? FontAwesomeIcons.fire
                        : FontAwesomeIcons.feather,
                    size: 21,
                    color: data.streak > 0
                        ? AppColors.clay
                        : context.colors.stone.withValues(alpha: 0.45),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Number + "day streak" label + motivational line
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${data.streak}',
                          style: GoogleFonts.domine(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: data.streak > 0
                                ? AppColors.clay
                                : context.colors.stone,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'day streak',
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.colors.stone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _motivation(data.streak),
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: context.colors.stone.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // "Today ✓" badge — visible only when the user already wrote
              if (data.wroteToday)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.sage.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FaIcon(FontAwesomeIcons.check,
                          size: 10, color: AppColors.sage),
                      const SizedBox(width: 4),
                      Text(
                        'Today',
                        style: GoogleFonts.lato(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.sage,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 18),

          // ── BOTTOM: 7-day dot row ───────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final filled  = data.last7[i];
              final isToday = i == 6;

              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // Today uses clay (flame colour); past days use sage
                      color: filled
                          ? (isToday ? AppColors.clay : AppColors.sage)
                          : context.colors.stone.withValues(alpha: 0.08),
                      // Today's empty circle gets a dashed-ish border as a
                      // gentle nudge to write
                      border: Border.all(
                        color: isToday && !filled
                            ? AppColors.clay.withValues(alpha: 0.4)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: filled
                          ? [
                              BoxShadow(
                                color: (isToday ? AppColors.clay : AppColors.sage)
                                    .withValues(alpha: 0.28),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: filled
                        ? const Center(
                            child: FaIcon(FontAwesomeIcons.check,
                                size: 11, color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    dayLabels[i],
                    style: GoogleFonts.lato(
                      fontSize: 10,
                      color: filled
                          ? context.colors.ink
                          : context.colors.stone.withValues(alpha: 0.4),
                      fontWeight:
                          filled ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.1, end: 0);
  }
}