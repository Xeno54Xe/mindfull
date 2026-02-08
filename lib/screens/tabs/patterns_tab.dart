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
    
    // Chronotype Data Buckets
    Map<String, List<double>> timeScores = {
      "Morning": [],   // 5 - 11
      "Afternoon": [], // 12 - 16
      "Evening": [],   // 17 - 21
      "Night": [],     // 22 - 4
    };

    // Weather Data
    List<double> sunnyScores = [];
    List<double> rainyScores = [];
    
    // Topic & Tag Data
    Map<String, int> wordCounts = {};
    Map<String, List<double>> tagScores = {}; // For Impact Analysis
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
          
      // Heatmap Logic: Store score for date
      DateTime dayKey = DateTime(timestamp.year, timestamp.month, timestamp.day);
      if (!dailyScores.containsKey(dayKey)) {
        dailyScores[dayKey] = score; 
      }

      String content = (data['content'] ?? "").toString().toLowerCase();
      String weather = (data['weather_context'] ?? "").toString().toLowerCase();

      totalScore += score;
      
      // Graph Data
      graphPoints.add(FlSpot((docs.length - 1 - i).toDouble(), score));

      // Chronotype Buckets
      int h = timestamp.hour;
      if (h >= 5 && h < 12) timeScores["Morning"]!.add(score);
      else if (h >= 12 && h < 17) timeScores["Afternoon"]!.add(score);
      else if (h >= 17 && h < 22) timeScores["Evening"]!.add(score);
      else timeScores["Night"]!.add(score);

      // Weather Stats
      if (weather.contains('clear') || weather.contains('sun')) sunnyScores.add(score);
      if (weather.contains('rain') || weather.contains('drizzle')) rainyScores.add(score);

      // Tag Correlations
      if (data['tags'] != null) {
        for (String tag in List<String>.from(data['tags'])) {
          if (tagScores[tag] == null) tagScores[tag] = [];
          tagScores[tag]!.add(score);
        }
      }

      // Word Cloud
      content.split(RegExp(r'\W+')).forEach((word) {
        if (word.length > 3 && !stopWords.contains(word)) {
          wordCounts[word] = (wordCounts[word] ?? 0) + 1;
        }
      });
    }

    // Sort graph points
    graphPoints.sort((a, b) => a.x.compareTo(b.x));

    double globalAvg = totalScore / docs.length;
    double _avg(List<double> l) => l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length;

    // --- CALCULATE IMPACT (Correlation) ---
    List<Map<String, dynamic>> impactList = [];
    tagScores.forEach((tag, scores) {
      if (scores.length >= 2) { // Only count tags used at least twice
        double tagAvg = scores.reduce((a, b) => a + b) / scores.length;
        impactList.add({
          "tag": tag,
          "impact": tagAvg - globalAvg, // Positive = Booster, Negative = Drainer
          "count": scores.length
        });
      }
    });
    // Sort by magnitude of impact (positive or negative)
    impactList.sort((a, b) => b['impact'].abs().compareTo(a['impact'].abs()));

    // --- CALCULATE CHRONOTYPE ---
    Map<String, String> finalTimeStats = {};
    timeScores.forEach((key, scores) {
      finalTimeStats[key] = scores.isEmpty ? "--" : _avg(scores).toStringAsFixed(1);
    });

    var sortedTopics = wordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return {
      "avg_score": globalAvg,
      "graph_data": graphPoints,
      "time_stats": finalTimeStats,
      "sunny_avg": _avg(sunnyScores),
      "rainy_avg": _avg(rainyScores),
      "top_topics": sortedTopics.take(5).map((e) => e.key).toList(),
      "heatmap_data": dailyScores,
      "tag_impacts": impactList.take(5).toList(),
      "count": docs.length
    };
  }

  // --- 2. AI DEEP ANALYSIS (Active) ---
  Future<void> _generateWeeklyReport() async {
    setState(() => _isAnalyzing = true);
    final user = FirebaseAuth.instance.currentUser;
    
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      final query = await FirebaseFirestore.instance
          .collection('users').doc(user?.uid).collection('entries')
          .where('timestamp', isGreaterThan: sevenDaysAgo)
          .get();

      if (query.docs.isEmpty) throw Exception("Write at least one entry this week to analyze.");

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

      final prefs = await SharedPreferences.getInstance();
      final musicProfile = prefs.getString('music_profile') ?? "General Pop";

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
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('entries')
            .orderBy('timestamp', descending: true).limit(100).snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.sage));
            
            final stats = _calculateStats(snapshot.data!.docs);
            
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
                  Text("The math behind your mind.", style: GoogleFonts.lato(fontSize: 16, color: AppColors.stone)),
                  const SizedBox(height: 30),

                  // 1. LIFE GRID (Consistency Heatmap)
                  Text("CONSISTENCY", style: GoogleFonts.lato(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppColors.stone)),
                  const SizedBox(height: 10),
                  _buildLifeGrid(stats['heatmap_data']),
                  const SizedBox(height: 30),

                  // 2. EMOTIONAL HORIZON GRAPH
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

                  // 3. ACTIVITY IMPACT (Tag Correlations)
                  Text("ACTIVITY IMPACT", style: GoogleFonts.lato(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold, color: AppColors.stone)),
                  Text("What lifts you up vs. weighs you down.", style: GoogleFonts.lato(fontSize: 12, color: AppColors.stone.withOpacity(0.7))),
                  const SizedBox(height: 15),
                  _buildImpactChart(stats['tag_impacts']),
                  const SizedBox(height: 30),

                  // 4. CHRONOTYPE (Time Analysis)
                  Text("CHRONOTYPE", style: GoogleFonts.lato(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold, color: AppColors.stone)),
                  const SizedBox(height: 15),
                  _buildChronotypeRow(stats['time_stats']),
                  const SizedBox(height: 30),

                  // 5. WEATHER & TOPIC STATS
                  Row(
                    children: [
                      _InfoCard(
                        icon: FontAwesomeIcons.umbrella,
                        label: "Rain Effect",
                        value: (stats['rainy_avg'] > 0) ? stats['rainy_avg'].toStringAsFixed(1) : "--",
                        subValue: "vs Sun ${stats['sunny_avg'].toStringAsFixed(1)}",
                      ),
                      const SizedBox(width: 16),
                      // Topic Cloud Small
                      Expanded(
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
                              const Icon(FontAwesomeIcons.commentDots, size: 20, color: AppColors.sage),
                              const SizedBox(height: 10),
                              Text("Top Topic", style: GoogleFonts.lato(fontSize: 12, color: AppColors.stone)),
                              const SizedBox(height: 4),
                              Text(
                                (stats['top_topics'] as List).isNotEmpty ? (stats['top_topics'][0] as String).toUpperCase() : "--", 
                                style: GoogleFonts.domine(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink)
                              ),
                              Text("Recurring theme", style: GoogleFonts.lato(fontSize: 12, color: AppColors.stone)),
                            ],
                          ),
                        ),
                      ),
                    ],
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

  // --- WIDGET: LIFE GRID ---
  Widget _buildLifeGrid(Map<DateTime, double> data) {
    final now = DateTime.now();
    return SizedBox(
      height: 140, // 7 rows
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        reverse: true,
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7, 
          mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 1.0,
        ),
        itemCount: 140,
        itemBuilder: (context, index) {
          final date = now.subtract(Duration(days: index));
          final dayKey = DateTime(date.year, date.month, date.day);
          final score = data[dayKey];
          
          Color color = AppColors.stone.withOpacity(0.1); 
          if (score != null) color = _getMoodColor(score);

          return Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)));
        },
      ),
    );
  }

  // --- WIDGET: IMPACT CHART ---
  Widget _buildImpactChart(List<Map<String, dynamic>> impacts) {
    if (impacts.isEmpty) return const Text("Use tags to see what affects your mood.", style: TextStyle(color: AppColors.stone));

    return Column(
      children: impacts.map((item) {
        double val = item['impact'];
        bool isPositive = val >= 0;
        double widthFactor = (val.abs() / 5).clamp(0.0, 1.0); // Normalize width

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              SizedBox(width: 70, child: Text(item['tag'], style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ink), overflow: TextOverflow.ellipsis)),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(width: 1, height: 20, color: AppColors.stone.withOpacity(0.2)), // Center Line
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: !isPositive 
                              ? Container(height: 8, width: 100 * widthFactor, decoration: BoxDecoration(color: AppColors.clay, borderRadius: BorderRadius.circular(4))) 
                              : const SizedBox(),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: isPositive 
                              ? Container(height: 8, width: 100 * widthFactor, decoration: BoxDecoration(color: AppColors.sage, borderRadius: BorderRadius.circular(4))) 
                              : const SizedBox(),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              SizedBox(
                width: 40,
                child: Text("${val > 0 ? '+' : ''}${val.toStringAsFixed(1)}", textAlign: TextAlign.right, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: isPositive ? AppColors.sage : AppColors.clay)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- WIDGET: CHRONOTYPE ROW ---
  Widget _buildChronotypeRow(Map<String, String> stats) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _chronoCard("Morning", Icons.wb_sunny_outlined, stats["Morning"]!),
        _chronoCard("Afternoon", Icons.wb_sunny, stats["Afternoon"]!),
        _chronoCard("Evening", Icons.nights_stay_outlined, stats["Evening"]!),
        _chronoCard("Night", Icons.bed_outlined, stats["Night"]!),
      ],
    );
  }

  Widget _chronoCard(String label, IconData icon, String score) {
    double val = double.tryParse(score) ?? 0;
    Color color = val == 0 ? AppColors.stone : _getMoodColor(val);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.stone.withOpacity(0.1))),
          child: Icon(icon, size: 20, color: AppColors.stone),
        ),
        const SizedBox(height: 8),
        Text(score, style: GoogleFonts.domine(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: GoogleFonts.lato(fontSize: 10, color: AppColors.stone)),
      ],
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.stone.withOpacity(0.1))),
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
      decoration: const BoxDecoration(color: AppColors.paperBackground, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
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
                Text(data['mood_summary']?.toString().toUpperCase() ?? "ANALYZED", style: GoogleFonts.domine(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.ink)),
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
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1DB954), Color(0xFF191414)]), borderRadius: BorderRadius.circular(16)),
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