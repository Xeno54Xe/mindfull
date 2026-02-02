import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../entry_detail_screen.dart';
import '../../theme/colors.dart';

class ReflectTab extends StatelessWidget {
  const ReflectTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      bottom: false, 
      child: Column(
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Reflect.", style: GoogleFonts.domine(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.ink)),
                    Text("Welcome back, ${user?.displayName?.split(' ')[0] ?? "Friend"}", style: GoogleFonts.lato(fontSize: 16, color: AppColors.stone)),
                  ],
                ),
                CircleAvatar(
                  backgroundColor: AppColors.ink.withOpacity(0.05),
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  child: user?.photoURL == null ? const Icon(Icons.person, color: AppColors.ink) : null,
                ),
              ],
            ),
          ),

          // THE FEED
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('entries').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.ink));
                
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120), // Bottom padding for Nav Bar
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var data = snapshot.data!.docs[index];
                    return _PaperCard(data: data)
                        .animate(delay: (100 * index).ms)
                        .fadeIn(duration: 500.ms, curve: Curves.easeOut)
                        .slideY(begin: 0.1, end: 0, duration: 500.ms);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperCard extends StatelessWidget {
  final QueryDocumentSnapshot data;
  const _PaperCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final score = data.data().toString().contains('mood_score') ? data['mood_score'] : 5;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EntryDetailScreen(data: data.data() as Map<String, dynamic>))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        // --- THE PAPER CARD EFFECT ---
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: AppColors.ink.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          children: [
            Hero(
              tag: data['image_url'] ?? 'img_${data.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(data['image_url'] ?? '', height: 64, width: 64, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('MMM d').format(date).toUpperCase(), style: GoogleFonts.lato(fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold, color: AppColors.stone)),
                  const SizedBox(height: 6),
                  Text(data['mood'] ?? 'Mood', style: GoogleFonts.domine(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.ink)),
                ],
              ),
            ),
            // Minimalist Score Circle
            Container(
              height: 32, width: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _getScoreColor(score), width: 2),
              ),
              child: Center(
                child: Text(score.toString(), style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: _getScoreColor(score))),
              ),
            )
          ],
        ),
      ),
    );
  }
  
  Color _getScoreColor(dynamic score) {
    int s = (score is int) ? score : 5;
    if (s >= 8) return AppColors.sage; 
    if (s >= 5) return const Color(0xFFEBC35F); // Muted Mustard
    return AppColors.clay;
  }
}