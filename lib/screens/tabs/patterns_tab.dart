import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/mood_chart.dart'; // Import your graph

class PatternsTab extends StatelessWidget {
  const PatternsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .collection('entries')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Center(child: Text("No data yet."));

            // --- CALCULATE STATS (CRASH PROOF) ---
            double totalScore = 0;
            int validEntries = 0;

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              
              // CRITICAL FIX: Check if key exists using containsKey
              if (data.containsKey('mood_score')) {
                totalScore += (data['mood_score'] as num).toDouble();
                validEntries++;
              } else {
                // If missing (old data), count it as Neutral (5.0)
                totalScore += 5.0;
                validEntries++;
              }
            }
            
            double avgScore = validEntries > 0 ? totalScore / validEntries : 0.0;
            // -------------------------------------

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Patterns", style: GoogleFonts.domine(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  
                  // 1. THE BIG GRAPH
                  Text("7-Day Trend", style: GoogleFonts.lato(fontSize: 12, letterSpacing: 1, color: Colors.grey)),
                  const SizedBox(height: 10),
                  MoodChart(docs: docs),
                  
                  const SizedBox(height: 40),

                  // 2. KEY METRICS (Grid)
                  Row(
                    children: [
                      _StatCard(
                        label: "AVERAGE VIBE", 
                        value: avgScore.toStringAsFixed(1), 
                        color: avgScore >= 5 ? Colors.green : Colors.orange
                      ),
                      const SizedBox(width: 16),
                      _StatCard(
                        label: "TOTAL ENTRIES", 
                        value: docs.length.toString(), 
                        color: Colors.blue
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.lato(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Text(value, style: GoogleFonts.domine(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}