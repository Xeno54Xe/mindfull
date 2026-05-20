import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/colors.dart';

class MoodChart extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  const MoodChart({super.key, required this.docs});

  @override
  Widget build(BuildContext context) {
    final recentDocs = docs.take(7).toList().reversed.toList();
    if (recentDocs.isEmpty) return const SizedBox.shrink();

    List<FlSpot> spots = [];
    for (int i = 0; i < recentDocs.length; i++) {
      final data = recentDocs[i].data() as Map<String, dynamic>;
      spots.add(FlSpot(i.toDouble(), (data['mood_score'] ?? 5).toDouble()));
    }

    return Container(
      height: 180,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.stone.withValues(alpha: 0.1)),
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
              color: AppColors.sage,
              barWidth: 4,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.sage.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
