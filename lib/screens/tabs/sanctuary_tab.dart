import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SanctuaryTab extends StatelessWidget {
  const SanctuaryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text("Sanctuary", style: GoogleFonts.domine(fontSize: 32, fontWeight: FontWeight.bold)),
            ),
            
            Expanded(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('entries').orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var data = snapshot.data!.docs[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.only(bottom: 16),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(data['image_url'] ?? '', width: 50, height: 50, fit: BoxFit.cover),
                        ),
                        title: Text(data['track_name'] ?? 'Unknown', style: GoogleFonts.domine(fontWeight: FontWeight.bold)),
                        subtitle: Text(data['artist'] ?? 'Unknown', style: GoogleFonts.lato(color: Colors.grey)),
                        trailing: IconButton(
                          icon: const Icon(FontAwesomeIcons.play, size: 16),
                          color: isDarkMode ? Colors.white : Colors.black,
                          onPressed: () async {
                             final Uri url = Uri.parse("https://open.spotify.com/search/${data['track_name']}");
                             await launchUrl(url, mode: LaunchMode.externalApplication);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}