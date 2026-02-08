import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../theme/colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  // DATA STATE
  final _nameController = TextEditingController();
  final _diaryController = TextEditingController();
  final List<Map<String, String>> _selectedArtists = [];
  
  // SEARCH STATE
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoadingArtists = false;
  Timer? _debounce;

  // --- BACKEND URL ---
  String get _backendUrl {
    // REPLACE THIS STRING with your actual Render URL
    const String liveUrl = "https://mindfull-backend-15b6.onrender.com"; 
    
    if (kIsWeb) return liveUrl; 
    return liveUrl; // Always use live URL for the APK
  }

  @override
  void initState() {
    super.initState();
    _fetchArtists(""); // Load initial trending artists
  }

  // --- API CALL ---
  Future<void> _fetchArtists(String query) async {
    setState(() => _isLoadingArtists = true);
    try {
      final url = Uri.parse("$_backendUrl/search-artists?q=$query");
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(data['artists']);
        });
      }
    } catch (e) {
      print("Artist Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingArtists = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchArtists(query);
    });
  }

  void _toggleArtist(Map<String, dynamic> artist) {
    setState(() {
      final isSelected = _selectedArtists.any((a) => a['name'] == artist['name']);
      if (isSelected) {
        _selectedArtists.removeWhere((a) => a['name'] == artist['name']);
      } else {
        if (_selectedArtists.length < 5) {
          _selectedArtists.add({
            'name': artist['name'],
            'image': artist['image'] ?? ""
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You can only pick 5 favorites!")),
          );
        }
      }
    });
  }

  // --- FINAL SAVE ---
  Future<void> _completeOnboarding() async {
    if (_diaryController.text.trim().isEmpty) return;
    
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      // Create the simple music profile string
      String musicProfile = _selectedArtists.map((a) => a['name']).join(", ");
      if (musicProfile.isEmpty) musicProfile = "General Pop";

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'nickname': _nameController.text.trim(),
        'diary_name': _diaryController.text.trim(),
        'music_profile': musicProfile, // Saved for the AI to use!
        'email': user.email,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Save specific artists list for UI display later
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('profile').doc('music').set({
        'top_artists': _selectedArtists
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paperBackground,
      body: SafeArea(
        child: Column(
          children: [
            // PROGRESS BAR
            LinearProgressIndicator(
              value: (_currentPage + 1) / 3,
              backgroundColor: AppColors.stone.withOpacity(0.2),
              color: AppColors.sage,
              minHeight: 4,
            ),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  // PAGE 1: NAME
                  _buildSimplePage(
                    "First things first.",
                    "What should I call you?",
                    "Your Nickname",
                    _nameController,
                    Icons.person_outline,
                  ),
                  
                  // PAGE 2: MUSIC (New!)
                  _buildMusicPage(),
                  
                  // PAGE 3: DIARY NAME
                  _buildSimplePage(
                    "One last thing.",
                    "Name your sanctuary.",
                    "e.g., CoCo the Diary",
                    _diaryController,
                    Icons.book_outlined,
                  ),
                ],
              ),
            ),

            // NAVIGATION BUTTONS
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () {
                    if (_currentPage == 0 && _nameController.text.isNotEmpty) {
                      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    } else if (_currentPage == 1) {
                      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    } else if (_currentPage == 2) {
                      _completeOnboarding();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _currentPage == 2 ? "ENTER YOUR SANCTUARY" : "NEXT", 
                        style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimplePage(String subtitle, String title, String hint, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle.toUpperCase(), style: GoogleFonts.lato(color: AppColors.sage, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(title, style: GoogleFonts.domine(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.ink)),
          const SizedBox(height: 30),
          TextField(
            controller: controller,
            style: GoogleFonts.lato(fontSize: 20, color: AppColors.ink),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.stone),
              hintText: hint,
              hintStyle: GoogleFonts.lato(color: AppColors.stone.withOpacity(0.5)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.stone.withOpacity(0.3))),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.sage, width: 2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text("SECONDLY SET THE VIBE", style: GoogleFonts.lato(color: AppColors.sage, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("Pick up to 5 artists. (we'll recommend you based on these)", style: GoogleFonts.domine(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.ink)),
          
          const SizedBox(height: 20),
          
          if (_selectedArtists.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedArtists.map((artist) {
                return Chip(
                  avatar: CircleAvatar(backgroundImage: artist['image'] != "" ? NetworkImage(artist['image']!) : null),
                  label: Text(artist['name']!),
                  backgroundColor: AppColors.sage.withOpacity(0.2),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() => _selectedArtists.remove(artist)),
                );
              }).toList(),
            ),

          const SizedBox(height: 20),
          
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: "Search artists...",
              prefixIcon: const Icon(Icons.search, color: AppColors.stone),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          
          const SizedBox(height: 10),
          
          Expanded(
            child: _isLoadingArtists 
              ? const Center(child: CircularProgressIndicator(color: AppColors.sage))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final artist = _searchResults[index];
                    final isSelected = _selectedArtists.any((a) => a['name'] == artist['name']);
                    
                    return GestureDetector(
                      onTap: () => _toggleArtist(artist),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.sage.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.sage : Colors.transparent, 
                            width: 2
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: AppColors.stone.withOpacity(0.2),
                              backgroundImage: (artist['image'] != null) ? NetworkImage(artist['image']) : null,
                              child: (artist['image'] == null) ? const Icon(Icons.music_note, color: AppColors.stone) : null,
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text(
                                artist['name'],
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}