import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login_screen.dart';
import '../spotify_auth_screen.dart'; // Import the new screen
import '../../theme/colors.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isSpotifyConnected = false;

  @override
  void initState() {
    super.initState();
    _checkSpotifyStatus();
  }

  Future<void> _checkSpotifyStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSpotifyConnected = prefs.containsKey('spotify_token');
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.paperBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Profile", style: GoogleFonts.domine(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.ink)),
              const SizedBox(height: 40),
              
              // USER CARD
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.stone.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.sage,
                      radius: 35,
                      backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                      child: user?.photoURL == null ? const Icon(Icons.person, color: Colors.white, size: 30) : null,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.displayName ?? "Traveler", style: GoogleFonts.domine(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.ink)),
                          const SizedBox(height: 4),
                          Text(user?.email ?? "", style: GoogleFonts.lato(fontSize: 14, color: AppColors.stone)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // SPOTIFY CONNECT BUTTON
              InkWell(
                onTap: () async {
                  if (_isSpotifyConnected) return; // Already connected
                  final result = await Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const SpotifyAuthScreen())
                  );
                  if (result == true) _checkSpotifyStatus();
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    // Change color based on status
                    color: _isSpotifyConnected ? const Color(0xFF1DB954).withOpacity(0.1) : Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: _isSpotifyConnected ? Border.all(color: const Color(0xFF1DB954)) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(FontAwesomeIcons.spotify, color: _isSpotifyConnected ? const Color(0xFF1DB954) : Colors.white),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSpotifyConnected ? "Spotify Connected" : "Connect Spotify",
                            style: GoogleFonts.domine(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold, 
                              color: _isSpotifyConnected ? const Color(0xFF1DB954) : Colors.white
                            ),
                          ),
                          Text(
                            _isSpotifyConnected ? "We can see your music taste." : "For personalized playlists.",
                            style: GoogleFonts.lato(
                              fontSize: 12, 
                              color: _isSpotifyConnected ? AppColors.stone : Colors.white70
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (_isSpotifyConnected) 
                        const Icon(Icons.check_circle, color: Color(0xFF1DB954))
                      else
                        const Icon(Icons.arrow_forward, color: Colors.white),
                    ],
                  ),
                ),
              ),

              const Spacer(),
              
              // LOGOUT
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear(); // Clear local data on logout
                    if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                  icon: const Icon(Icons.logout, size: 20),
                  label: Text("LOG OUT", style: GoogleFonts.lato(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.clay, 
                    side: BorderSide(color: AppColors.clay.withOpacity(0.5), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}