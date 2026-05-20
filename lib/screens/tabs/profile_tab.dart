import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login_screen.dart';
import '../spotify_auth_screen.dart';
import '../mood_garden_screen.dart';
import 'package:provider/provider.dart';
import '../../services/theme_provider.dart';
import '../../theme/colors.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final TextEditingController _musicController = TextEditingController();
  bool _isSpotifyConnected = false;
  bool _isLoadingProfile = true;
  bool _isSavingMusic = false;
  bool _isLoggingOut = false;
  String _savedMusicProfile = "";

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _musicController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final futures = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        SharedPreferences.getInstance(),
      ]);

      final doc = futures[0] as DocumentSnapshot;
      final prefs = futures[1] as SharedPreferences;

      final profile = (doc.data() as Map<String, dynamic>?)?['music_profile'] as String? ?? "";

      if (mounted) {
        setState(() {
          _savedMusicProfile = profile;
          _musicController.text = profile;
          _isSpotifyConnected = prefs.containsKey('spotify_token');
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _saveMusicProfile() async {
    final value = _musicController.text.trim();
    setState(() => _isSavingMusic = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'music_profile': value},
        SetOptions(merge: true),
      );

      if (mounted) {
        setState(() => _savedMusicProfile = value);
        _showSnack("Music profile saved.", AppColors.sage);
      }
    } catch (e) {
      if (mounted) _showSnack("Failed to save. Check your connection.", AppColors.clay);
    } finally {
      if (mounted) setState(() => _isSavingMusic = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoggingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack("Sign out failed. Try again.", AppColors.clay);
        setState(() => _isLoggingOut = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Delete Account?",
            style: GoogleFonts.domine(fontWeight: FontWeight.bold, color: AppColors.clay)),
        content: Text(
            "This permanently deletes your profile, all journal entries, and music data. This cannot be undone.",
            style: GoogleFonts.lato(color: context.colors.ink, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("CANCEL",
                style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: context.colors.stone)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("DELETE FOREVER",
                style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: AppColors.clay)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      await user.delete();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack("Please log out and log back in before deleting.", AppColors.clay);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ));
  }

  // Parses comma-separated artists into display chips
  List<String> get _artistChips {
    return _savedMusicProfile
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator(color: AppColors.sage))
          : CustomScrollView(
              slivers: [
                // ── HERO HEADER ──────────────────────────────────────────
                SliverToBoxAdapter(child: _buildHeroHeader(user)),

                // ── BODY ─────────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 28),
                      _buildSectionLabel("JOURNEY"),
                      const SizedBox(height: 12),
                      _buildJourneyCard(user),
                      const SizedBox(height: 12),
                      _buildGardenCard(),
                      const SizedBox(height: 28),
                      _buildSectionLabel("MUSIC DNA"),
                      const SizedBox(height: 12),
                      _buildMusicProfileCard(),
                      const SizedBox(height: 28),
                      _buildSectionLabel("CONNECTIONS"),
                      const SizedBox(height: 12),
                      _buildSpotifyCard(),
                      const SizedBox(height: 28),
                      _buildSectionLabel("APPEARANCE"),
                      const SizedBox(height: 12),
                      _buildAppearanceCard(),
                      const SizedBox(height: 28),
                      _buildSectionLabel("ACCOUNT"),
                      const SizedBox(height: 12),
                      _buildAccountCard(user),
                      const SizedBox(height: 28),
                      _buildSignOutButton(),
                      const SizedBox(height: 16),
                      _buildDeleteLink(),
                      const SizedBox(height: 20),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  // ── JOURNEY CARD ─────────────────────────────────────────────────────────

  Widget _buildJourneyCard(User? user) {
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('entries')
          .where('timestamp',
              isGreaterThan: Timestamp.fromDate(
                DateTime.now().subtract(const Duration(days: 90)),
              ))
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // ── streak calculation (same logic as _StreakCard) ──────────────
        int streak = 0;
        int totalDocs = snapshot.data?.docs.length ?? 0;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          String fmt(DateTime d) =>
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

          final written = <String>{};
          for (final doc in snapshot.data!.docs) {
            final raw = doc.data() as Map<String, dynamic>;
            if (raw['timestamp'] != null) {
              written.add(fmt((raw['timestamp'] as Timestamp).toDate()));
            }
          }
          final today = DateTime.now();
          final todayStr = fmt(today);
          final yestStr  = fmt(today.subtract(const Duration(days: 1)));
          final start = written.contains(todayStr)
              ? 0
              : written.contains(yestStr)
                  ? 1
                  : -1;
          if (start >= 0) {
            for (int i = start; i < 90; i++) {
              if (written.contains(fmt(today.subtract(Duration(days: i))))) {
                streak++;
              } else {
                break;
              }
            }
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.stone.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: context.colors.stone.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // ── Streak stat ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.clay.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const FaIcon(FontAwesomeIcons.fire,
                              size: 18, color: AppColors.clay),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '$streak',
                          style: GoogleFonts.domine(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: streak > 0 ? AppColors.clay : context.colors.stone,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          streak == 1 ? 'day streak' : 'day streak',
                          style: GoogleFonts.lato(
                              fontSize: 13, color: context.colors.stone),
                        ),
                      ],
                    ),
                  ),
                ),

                // Divider
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: context.colors.stone.withValues(alpha: 0.1),
                  indent: 20,
                  endIndent: 20,
                ),

                // ── Total entries stat ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.sage.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const FaIcon(FontAwesomeIcons.bookOpen,
                              size: 18, color: AppColors.sage),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '$totalDocs',
                          style: GoogleFonts.domine(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: context.colors.ink,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          totalDocs == 1 ? 'entry written' : 'entries written',
                          style: GoogleFonts.lato(
                              fontSize: 13, color: context.colors.stone),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── MOOD GARDEN CARD ──────────────────────────────────────────────────────

  Widget _buildGardenCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MoodGardenScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.sage.withValues(alpha: 0.14),
              const Color(0xFFCEDA7A).withValues(alpha: 0.10),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.sage.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: AppColors.sage.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const FaIcon(FontAwesomeIcons.seedling,
                  size: 18, color: AppColors.sage),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Mood Garden",
                      style: GoogleFonts.domine(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: context.colors.ink)),
                  Text("Watch your emotions bloom over time",
                      style: GoogleFonts.lato(
                          fontSize: 12, color: context.colors.stone)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Visit",
                      style: GoogleFonts.lato(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.sage)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 11, color: AppColors.sage),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HERO HEADER ───────────────────────────────────────────────────────────

  Widget _buildHeroHeader(User? user) {
    final initials = (user?.displayName ?? user?.email ?? "?")
        .characters
        .first
        .toUpperCase();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            children: [
              // Avatar
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.sage, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.sage.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: user?.photoURL != null
                      ? Image.network(user!.photoURL!, fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => _avatarFallback(initials))
                      : _avatarFallback(initials),
                ),
              ),
              const SizedBox(height: 16),

              // Name
              Text(
                user?.displayName ?? "Traveler",
                style: GoogleFonts.domine(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),

              // Email pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Text(
                  user?.email ?? "",
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    color: Colors.white70,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback(String initials) {
    return Container(
      color: AppColors.sage.withValues(alpha: 0.3),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.domine(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── SECTION LABEL ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.lato(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 2.5,
        color: context.colors.stone,
      ),
    );
  }

  // ── MUSIC PROFILE CARD ────────────────────────────────────────────────────

  Widget _buildMusicProfileCard() {
    final hasChanged = _musicController.text.trim() != _savedMusicProfile;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.colors.stone.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: context.colors.stone.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const FaIcon(FontAwesomeIcons.headphones,
                      size: 16, color: AppColors.sage),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Your Music Taste",
                          style: GoogleFonts.domine(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: context.colors.ink)),
                      Text("The AI uses this to recommend songs",
                          style: GoogleFonts.lato(
                              fontSize: 12, color: context.colors.stone)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Divider(color: context.colors.stone.withValues(alpha: 0.1), height: 1),

          // Text input
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: TextField(
              controller: _musicController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.lato(
                  fontSize: 15, color: context.colors.ink, height: 1.5),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "e.g. Taylor Swift, Lofi Beats, Seedhe Maut",
                hintStyle: GoogleFonts.lato(
                    color: context.colors.stone.withValues(alpha: 0.5), fontSize: 14),
                filled: true,
                fillColor: context.colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.sage, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                suffixIcon: _musicController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            size: 18, color: context.colors.stone),
                        onPressed: () => setState(() {
                          _musicController.clear();
                        }),
                      )
                    : null,
              ),
            ),
          ),

          // Chips preview
          if (_artistChips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _artistChips.map((artist) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.sage.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.sage.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(FontAwesomeIcons.music,
                            size: 10, color: AppColors.sage),
                        const SizedBox(width: 6),
                        Text(artist,
                            style: GoogleFonts.lato(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.sage)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // Save button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (_isSavingMusic || !hasChanged)
                    ? null
                    : _saveMusicProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sage,
                  disabledBackgroundColor:
                      context.colors.stone.withValues(alpha: 0.15),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSavingMusic
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        hasChanged ? "SAVE CHANGES" : "UP TO DATE",
                        style: GoogleFonts.lato(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── APPEARANCE CARD ───────────────────────────────────────────────────────

  Widget _buildAppearanceCard() {
    final themeProvider = context.watch<ThemeProvider>();
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.stone.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: context.colors.stone.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.colors.stone.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                themeProvider.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                size: 18,
                color: context.colors.stone,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Dark Mode",
                      style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.ink)),
                  Text(themeProvider.isDark ? "Candlelit journal" : "Parchment light",
                      style: GoogleFonts.lato(fontSize: 11, color: context.colors.stone)),
                ],
              ),
            ),
            Switch(
              value: themeProvider.isDark,
              onChanged: (_) => themeProvider.toggleTheme(),
            ),
          ],
        ),
      ),
    );
  }

  // ── SPOTIFY CARD ──────────────────────────────────────────────────────────

  Widget _buildSpotifyCard() {
    return GestureDetector(
      onTap: () async {
        if (_isSpotifyConnected) return;
        if (kIsWeb) {
          _showSnack(
            "Spotify login is available on the Android app.",
            context.colors.stone,
          );
          return;
        }
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SpotifyAuthScreen()),
        );
        if (result == true) _loadProfile();
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _isSpotifyConnected
              ? const Color(0xFF1DB954).withValues(alpha: 0.08)
              : context.colors.ink,
          borderRadius: BorderRadius.circular(20),
          border: _isSpotifyConnected
              ? Border.all(color: const Color(0xFF1DB954).withValues(alpha: 0.4))
              : null,
          boxShadow: [
            BoxShadow(
              color: (_isSpotifyConnected
                      ? const Color(0xFF1DB954)
                      : context.colors.ink)
                  .withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isSpotifyConnected
                    ? const Color(0xFF1DB954).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FaIcon(
                FontAwesomeIcons.spotify,
                color: _isSpotifyConnected
                    ? const Color(0xFF1DB954)
                    : Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSpotifyConnected
                        ? "Spotify Connected"
                        : "Connect Spotify",
                    style: GoogleFonts.domine(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isSpotifyConnected
                          ? const Color(0xFF1DB954)
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isSpotifyConnected
                        ? "Your music taste is synced."
                        : (kIsWeb
                            ? "Available on the Android app."
                            : "For even more personalized playlists."),
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: _isSpotifyConnected
                          ? context.colors.stone
                          : Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _isSpotifyConnected
                  ? Icons.check_circle_rounded
                  : Icons.arrow_forward_ios_rounded,
              color: _isSpotifyConnected
                  ? const Color(0xFF1DB954)
                  : Colors.white38,
              size: _isSpotifyConnected ? 22 : 16,
            ),
          ],
        ),
      ),
    );
  }

  // ── ACCOUNT CARD ──────────────────────────────────────────────────────────

  Widget _buildAccountCard(User? user) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.stone.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: context.colors.stone.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAccountRow(
            icon: Icons.email_outlined,
            label: "Email",
            value: user?.email ?? "—",
          ),
          Divider(
              height: 1,
              color: context.colors.stone.withValues(alpha: 0.1),
              indent: 56,
              endIndent: 20),
          _buildAccountRow(
            icon: Icons.shield_outlined,
            label: "Auth Provider",
            value: user?.providerData.isNotEmpty == true
                ? (user!.providerData.first.providerId == 'google.com'
                    ? "Google"
                    : "Email & Password")
                : "—",
          ),
        ],
      ),
    );
  }

  Widget _buildAccountRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.colors.stone.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: context.colors.stone),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.lato(
                        fontSize: 11,
                        color: context.colors.stone,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.colors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SIGN OUT BUTTON ───────────────────────────────────────────────────────

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _isLoggingOut ? null : _signOut,
        icon: _isLoggingOut
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.clay))
            : const Icon(Icons.logout_rounded, size: 18),
        label: Text(
          _isLoggingOut ? "SIGNING OUT..." : "SIGN OUT",
          style: GoogleFonts.lato(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.clay,
          side: BorderSide(color: AppColors.clay.withValues(alpha: 0.5), width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // ── DELETE LINK ───────────────────────────────────────────────────────────

  Widget _buildDeleteLink() {
    return Center(
      child: TextButton(
        onPressed: _deleteAccount,
        child: Text(
          "Delete Account",
          style: GoogleFonts.lato(
            color: context.colors.stone.withValues(alpha: 0.6),
            fontSize: 12,
            decoration: TextDecoration.underline,
            decorationColor: context.colors.stone.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
