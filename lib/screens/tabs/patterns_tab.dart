import 'dart:convert';
import 'package:flutter/foundation.dart'; // REQUIRED FOR kIsWeb
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart'; 
import 'package:intl/intl.dart';
import '../../theme/colors.dart';

class PatternsTab extends StatefulWidget {
  const PatternsTab({super.key});

  @override
  State<PatternsTab> createState() => _PatternsTabState();
}

class _PatternsTabState extends State<PatternsTab> {
  bool _isAnalyzing = false;
  
  // --- SMART URL DETECTION ---
  String get _backendUrl {
    if (kIsWeb) return "http://localhost:8000/analyze-mood-music";
    return "http://192.168.1.15:8000/analyze-mood-music"; // Update with your IP
  }

  // --- HELPER: GET MOOD COLOR ---
  Color _getMoodColor(double score) {
    if (score >= 8) return AppColors.sage; // Radiant
    if (score >= 5) return const Color(0xFFA8A593); // Neutral
    return AppColors.clay; // Heavy
  }

  // --- 1. LOCAL ANALYTICS (Passive) ---
  Map<String, dynamic> _calculateStats(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return {};

    double totalScore = 0;
    List<FlSpot> graphPoints = [];
    
    // Chronotype Data
    List<double> morningScores = [];
    List<double> eveningScores = [];

    // Weather Data
    List<double> sunnyScores = [];
    List<double> rainyScores = [];
    
    // Topic Data
    Map<String, int> wordCounts = {};
    final stopWords = {'the', 'and', 'i', 'to', 'a', 'of', 'in', 'is', 'it', 'my', 'was', 'for', 'with', 'on'};

    // HEATMAP DATA
    Map<DateTime, double> dailyScores = {};

    for (int i = 0; i < docs.length; i++) {
      final data = docs[i].data() as Map<String, dynamic>;
      
      // Safe Data Access
      double score = (data['mood_score'] ?? 5.0).toDouble();
      DateTime timestamp = data['timestamp'] != null 
          ? (data['timestamp'] as Timestamp).toDate() 
          : DateTime.now();
          
      // Heatmap Logic: Store score for date (normalization)
      DateTime dayKey = DateTime(timestamp.year, timestamp.month, timestamp.day);
      if (!dailyScores.containsKey(dayKey)) {
        dailyScores[dayKey] = score; // Keep latest entry for that day
      }

      String content = (data['content'] ?? "").toString().toLowerCase();
      String weather = (data['weather_context'] ?? "").toString().toLowerCase();

      totalScore += score;
      
      // Graph Data (X axis = index, Y axis = score)
      graphPoints.add(FlSpot((docs.length - 1 - i).toDouble(), score));

      // Chronotype
      if (timestamp.hour < 12) morningScores.add(score);
      else if (timestamp.hour > 17) eveningScores.add(score);

      // Weather
      if (weather.contains('clear') || weather.contains('sun')) sunnyScores.add(score);
      if (weather.contains('rain') || weather.contains('drizzle')) rainyScores.add(score);

      // Topics
      content.split(RegExp(r'\W+')).forEach((word) {
        if (word.length > 3 && !stopWords.contains(word)) {
          wordCounts[word] = (wordCounts[word] ?? 0) + 1;
        }
      });
    }

    // Sort graph points by X to ensure line draws correctly
    graphPoints.sort((a, b) => a.x.compareTo(b.x));

    double _avg(List<double> l) => l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length;

    var sortedTopics = wordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return {
      "avg_score": totalScore / docs.length,
      "graph_data": graphPoints,
      "morning_avg": _avg(morningScores),
      "evening_avg": _avg(eveningScores),
      "sunny_avg": _avg(sunnyScores),
      "rainy_avg": _avg(rainyScores),
      "top_topics": sortedTopics.take(5).map((e) => e.key).toList(),
      "heatmap_data": dailyScores, // Added for Grid
      "count": docs.length
    };
  }

  // --- 2. AI DEEP ANALYSIS (Active) ---
  Future<void> _generateWeeklyReport() async {
    setState(() => _isAnalyzing = true);
    final user = FirebaseAuth.instance.currentUser;
    print("🚀 Starting Analysis...");

    try {
      // A. Get Data from Firebase
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      final query = await FirebaseFirestore.instance
          .collection('users').doc(user?.uid).collection('entries')
          .where('timestamp', isGreaterThan: sevenDaysAgo)
          .get();

      if (query.docs.isEmpty) throw Exception("Write at least one entry this week to analyze.");

      // B. Format for Python
      List<Map<String, dynamic>> logs = query.docs.map((doc) {
        final data = doc.data();
        return {
          "date": (data['timestamp'] as Timestamp).toDate().toString(),
          "mood_score": (data['mood_score'] ?? 5.0).toDouble(),
          "intention": data['content'] ?? "No text",
          "weather": data['weather_context'] ?? "Unknown",
          "journal_content": data['content'] ?? ""
        };
      }).toList();

      // C. Get Saved Music Profile
      final prefs = await SharedPreferences.getInstance();
      final musicProfile = prefs.getString('music_profile') ?? "General Pop";

      // D. Call Groq Backend
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": user?.uid,
          "music_profile": musicProfile,
          "logs": logs
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (mounted) _showReportModal(result);
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Analysis Failed: $e"),
          backgroundColor: AppColors.clay,
          duration: const Duration(seconds: 4),
        ));
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showReportModal(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReportSheet(data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.paperBackground,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0),
        child: FloatingActionButton.extended(
          onPressed: _isAnalyzing ? null : _generateWeeklyReport,
          backgroundColor: AppColors.ink,
          elevation: 5,
          icon: _isAnalyzing 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : const Icon(FontAwesomeIcons.wandMagicSparkles, color: Colors.white, size: 18),
          label: Text(_isAnalyzing ? "THINKING..." : "ANALYZE WEEK", style: GoogleFonts.lato(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white)),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder(
          // INCREASED LIMIT TO 365 FOR YEARLY HEATMAP
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('entries')
            .orderBy('timestamp', descending: true).limit(365).snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.sage));
            
            final stats = _calculateStats(snapshot.data!.docs);
            
            // EMPTY STATE
            if (stats.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FontAwesomeIcons.feather, size: 40, color: AppColors.stone.withOpacity(0.3)),
                    const SizedBox(height: 20),
                    Text("No patterns yet.", style: GoogleFonts.domine(fontSize: 20, color: AppColors.stone)),
                    Text("Write a few entries to unlock insights.", style: GoogleFonts.lato(color: AppColors.stone)),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Patterns", style: GoogleFonts.domine(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.ink)),
                  Text("Your emotional horizon.", style: GoogleFonts.lato(fontSize: 16, color: AppColors.stone)),
                  const SizedBox(height: 30),

                  // --- 1. LIFE GRID HEATMAP (NEW) ---
                  Text("CONSISTENCY", style: GoogleFonts.lato(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppColors.stone)),
                  const SizedBox(height: 10),
                  _buildLifeGrid(stats['heatmap_data']),
                  const SizedBox(height: 30),

                  // --- 2. EMOTIONAL HORIZON GRAPH ---
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: AppColors.stone.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minY: 0, maxY: 10,
                        lineBarsData: [
                          LineChartBarData(
                            spots: stats['graph_data'],
                            isCurved: true,
                            color: AppColors.sage,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: AppColors.sage.withOpacity(0.2)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- 3. INFOGRAPHICS ROW ---
                  Row(
                    children: [
                      _InfoCard(
                        icon: FontAwesomeIcons.cloudSun,
                        label: "Best Time",
                        value: (stats['morning_avg'] > stats['evening_avg']) ? "Morning" : "Evening",
                        subValue: "${(stats['morning_avg'] > stats['evening_avg'] ? stats['morning_avg'] : stats['evening_avg']).toStringAsFixed(1)} avg",
                      ),
                      const SizedBox(width: 16),
                      _InfoCard(
                        icon: FontAwesomeIcons.umbrella,
                        label: "Rain Effect",
                        value: (stats['rainy_avg'] > 0) ? stats['rainy_avg'].toStringAsFixed(1) : "--",
                        subValue: "vs Sun ${stats['sunny_avg'].toStringAsFixed(1)}",
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- 4. TOPIC CLOUD ---
                  Text("ON YOUR MIND", style: GoogleFonts.lato(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppColors.stone)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    children: (stats['top_topics'] as List<String>).map((topic) {
                      return Chip(
                        label: Text(topic.toUpperCase(), style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ink)),
                        backgroundColor: AppColors.sage.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.sage.withOpacity(0.3))),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 120), // Space for FAB
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- WIDGET: LIFE GRID BUILDER ---
  Widget _buildLifeGrid(Map<DateTime, double> data) {
    // Show last ~5 months (140 days)
    final now = DateTime.now();
    
    return SizedBox(
      height: 140, // Height for 7 rows (7 days)
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        reverse: true, // Start from right (Today) and scroll left (Past)
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7, // 7 rows (Days of Week)
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1.0,
        ),
        itemCount: 140, // Number of days to show
        itemBuilder: (context, index) {
          // Calculate date backwards
          final date = now.subtract(Duration(days: index));
          final dayKey = DateTime(date.year, date.month, date.day);
          final score = data[dayKey];
          
          Color color = AppColors.stone.withOpacity(0.1); // Default Empty
          if (score != null) {
            color = _getMoodColor(score);
          }

          return Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        },
      ),
    );
  }
}

// --- HELPER WIDGETS ---

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subValue;

  const _InfoCard({required this.icon, required this.label, required this.value, required this.subValue});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.stone.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.sage),
            const SizedBox(height: 10),
            Text(label, style: GoogleFonts.lato(fontSize: 12, color: AppColors.stone)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.domine(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink)),
            Text(subValue, style: GoogleFonts.lato(fontSize: 12, color: AppColors.stone)),
          ],
        ),
      ),
    );
  }
}

class _ReportSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReportSheet({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.paperBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.stone.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text("AI INSIGHT", style: GoogleFonts.lato(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppColors.stone)),
                const SizedBox(height: 10),
                Text(
                  data['mood_summary']?.toString().toUpperCase() ?? "ANALYZED",
                  style: GoogleFonts.domine(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.ink),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.sage.withOpacity(0.5))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(FontAwesomeIcons.wandMagicSparkles, color: AppColors.sage, size: 20),
                      const SizedBox(height: 10),
                      Text(data['pattern_insight'] ?? "Analyzing patterns...", style: GoogleFonts.lato(fontSize: 16, height: 1.5, color: AppColors.ink)),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text("CURATED PLAYLIST", style: GoogleFonts.lato(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppColors.stone)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1DB954), Color(0xFF191414)]), 
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['playlist_title'] ?? "Mix", style: GoogleFonts.domine(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 20),
                      ...((data['suggested_tracks'] as List<dynamic>?) ?? []).take(5).map((track) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              const Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Text(track, style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                              final query = Uri.encodeComponent(data['playlist_title']);
                              final url = Uri.parse("https://open.spotify.com/search/$query");
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                          child: const Text("OPEN IN SPOTIFY"),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text("ADVICE", style: GoogleFonts.lato(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppColors.stone)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xFFFFF8F0), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.clay.withOpacity(0.3))),
                  child: Text(data['advice'] ?? "Breathe.", style: GoogleFonts.domine(fontSize: 18, color: AppColors.ink)),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}