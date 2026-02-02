import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MoodChart extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;

  const MoodChart({super.key, required this.docs});

  @override
  Widget build(BuildContext context) {
    // 1. Prepare Data
    final recentDocs = docs.take(7).toList().reversed.toList();
    
    if (recentDocs.isEmpty) return const SizedBox.shrink();

    List<FlSpot> spots = [];
    for (int i = 0; i < recentDocs.length; i++) {
      final data = recentDocs[i].data() as Map<String, dynamic>;
      final score = (data['mood_score'] ?? 5).toDouble(); 
      spots.add(FlSpot(i.toDouble(), score));
    }

    // 2. The Chart
    return Container(
      height: 180,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          
          minX: 0, 
          maxX: (recentDocs.length - 1).toDouble(),
          minY: 1, 
          maxY: 10,
          
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF6C63FF), // Purple
              barWidth: 4,
              
              // --- THE FIX IS HERE ---
              // strokeCap: StrokeCap.round, 
              // -----------------------
              
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true, 
                color: const Color(0xFF6C63FF).withOpacity(0.2)
              ),
            ),
          ],
        ),
      ),
    );
  }
}