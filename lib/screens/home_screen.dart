import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Database
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart'; // Date Formatting
import '../theme/colors.dart';
import 'login_screen.dart';
import 'write_screen.dart';
import '../widgets/mood_chart.dart'; // The Graph Widget
import 'entry_detail_screen.dart'; // The New Detail Screen

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      
      // --- APP BAR ---
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Reflect", style: GoogleFonts.domine(color: Theme.of(context).textTheme.bodyLarge!.color, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Theme.of(context).textTheme.bodyLarge!.color),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),

      // --- WRITE BUTTON (FAB) ---
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WriteScreen())),
        backgroundColor: isDarkMode ? AppColors.darkAccent : AppColors.primaryButton,
        icon: Icon(FontAwesomeIcons.penNib, color: isDarkMode ? AppColors.primaryButton : Colors.white),
        label: Text("Unload", style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: isDarkMode ? AppColors.primaryButton : Colors.white)),
      ),

      // --- BODY (DATABASE STREAM) ---
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('entries')
            .orderBy('timestamp', descending: true) // Newest first
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Welcome, ${user?.displayName?.split(' ')[0] ?? 'Traveler'}", style: GoogleFonts.lato(fontSize: 20, color: Colors.grey)),
                  const SizedBox(height: 20),
                  Text("Your mind is empty.", style: GoogleFonts.domine(fontSize: 18)),
                ],
              ),
            );
          }

          // --- THE LIST ---
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100), // Extra bottom padding for FAB
            itemCount: snapshot.data!.docs.length + 1, // +1 because Index 0 is the Graph
            itemBuilder: (context, index) {
              
              // ITEM 0: THE VIBE GRAPH
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Your Vibe Trend", style: GoogleFonts.domine(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    MoodChart(docs: snapshot.data!.docs), // Pass data to the graph
                    const SizedBox(height: 20),
                    Text("Recent Entries", style: GoogleFonts.domine(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                  ],
                );
              }

              // ITEM 1+: THE JOURNAL CARDS
              var data = snapshot.data!.docs[index - 1]; // Shift index back
              return _JournalCard(data: data);
            },
          );
        },
      ),
    );
  }
}

// --- INDIVIDUAL CARD WIDGET ---
class _JournalCard extends StatelessWidget {
  final QueryDocumentSnapshot data;
  const _JournalCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    
    // Safely get the score (defaults to null if old data)
    final score = data.data().toString().contains('mood_score') ? data['mood_score'] : null;

    return GestureDetector(
      // 1. NAVIGATE TO DETAIL SCREEN
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EntryDetailScreen(data: data.data() as Map<String, dynamic>),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          // Soft Shadow
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            // 2. ALBUM ART (With Hero Animation)
            Hero(
              tag: data['image_url'] ?? 'img_${data.id}', // Unique Tag
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  data['image_url'] ?? '',
                  height: 60, width: 60, fit: BoxFit.cover,
                  errorBuilder: (c, o, s) => Container(height: 60, width: 60, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // 3. TEXT INFO
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('MMM d, h:mm a').format(date), style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(data['mood'] ?? 'Mood', style: GoogleFonts.domine(fontSize: 18, fontWeight: FontWeight.bold)),
                      // Green Score Badge
                      if (score != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: Text("$score/10", style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                        )
                      ]
                    ],
                  ),
                  Text("${data['track_name']} • ${data['artist']}", style: GoogleFonts.lato(fontSize: 14, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            
            // Arrow Icon
            Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}