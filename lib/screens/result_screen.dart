import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';
import '../widgets/paper_background.dart';
import '../services/auth_gate.dart';
import 'playlist_screen.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const ResultScreen({super.key, required this.data});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  // "lift" | "calm" | "stay"
  late String _selectedArc;
  bool _isGenerating = false;

  String get _backendUrl {
    const String liveUrl = "https://mindfull-backend-15b6.onrender.com";
    if (kIsWeb) return liveUrl;
    return liveUrl;
  }

  @override
  void initState() {
    super.initState();
    // Default arc based on mood score
    final score = widget.data['score'] != null
        ? (widget.data['score'] as num).round()
        : 5;
    _selectedArc = score <= 4 ? 'lift' : score <= 7 ? 'stay' : 'calm';
    // Pre-warm Render so it's ready when user taps "Generate Playlist"
    http.get(Uri.parse('$_backendUrl/')).timeout(
      const Duration(seconds: 10),
    ).catchError((_) {});
  }

  Future<void> _launchSpotify(String trackName) async {
    final query = Uri.encodeComponent(trackName);
    final url   = Uri.parse("https://open.spotify.com/search/$query");
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _generatePlaylist() async {
    setState(() => _isGenerating = true);
    try {
      final mood    = widget.data['mood']  as String? ?? 'Reflective';
      final score   = widget.data['score'] != null
          ? (widget.data['score'] as num).round()
          : 5;
      // Fetch user's music profile from Firestore via backend (re-use stored value if present)
      final musicProfile = widget.data['music_profile_used'] as String? ?? 'General Pop';

      final response = await http.post(
        Uri.parse('$_backendUrl/generate-playlist'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mood':          mood,
          'score':         score,
          'music_profile': musicProfile,
          'arc_type':      _selectedArc,
        }),
      ).timeout(const Duration(seconds: 90));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final playlistData = jsonDecode(response.body) as Map<String, dynamic>;
        final tracks = playlistData['tracks'] as List?;
        if (tracks == null || tracks.length < 4) {
          _showSnack('Couldn\'t generate playlist. Try again.', AppColors.clay);
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaylistScreen(
              playlistData: playlistData,
              mood:         mood,
              arcType:      _selectedArc,
            ),
          ),
        );
      } else {
        _showSnack('Server error (${response.statusCode}). Try again.', AppColors.clay);
      }
    } on TimeoutException {
      if (mounted) _showSnack('Taking too long. Try again.', AppColors.clay);
    } catch (e) {
      if (mounted) _showSnack('Error: $e', AppColors.clay);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final String mood     = widget.data['mood']       ?? "Neutral";
    final int    score    = widget.data['score'] != null
        ? (widget.data['score'] as num).round()
        : 5;
    final String artist   = widget.data['artist']     ?? "Unknown Artist";
    final String track    = widget.data['track_name'] ?? "Unknown Track";
    final String reason   = widget.data['reason']     ?? "Just a vibe.";
    final String imageUrl = widget.data['image_url']  ?? "";

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── header ──────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("ANALYSIS COMPLETE",
                        style: GoogleFonts.lato(
                            fontSize: 12,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                            color: context.colors.stone)),
                    IconButton(
                      icon: Icon(Icons.close, color: context.colors.ink),
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthGate()),
                        (route) => false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // ── mood ─────────────────────────────────────────────────
                Text(mood.toUpperCase(),
                    style: GoogleFonts.domine(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: context.colors.ink)),
                Text("Mood Score: $score/10",
                    style: GoogleFonts.lato(
                        fontSize: 18,
                        color: AppColors.sage,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // ── reason card ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: context.colors.stone.withValues(alpha: 0.1)),
                  ),
                  child: Text(reason,
                      style: GoogleFonts.lato(
                          fontSize: 16,
                          height: 1.5,
                          color: context.colors.ink)),
                ),
                const SizedBox(height: 40),

                // ── single song ───────────────────────────────────────────
                Text("SONG FOR YOU",
                    style: GoogleFonts.lato(
                        fontSize: 12,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                        color: context.colors.stone)),
                const SizedBox(height: 15),

                GestureDetector(
                  onTap: () => _launchSpotify("$track $artist"),
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5))
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              bottomLeft: Radius.circular(20)),
                          child: Image.network(
                            imageUrl,
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              width: 140,
                              height: 140,
                              color: context.colors.stone,
                              child: const Icon(Icons.music_note,
                                  color: Colors.white, size: 40),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(track,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.domine(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: context.colors.ink)),
                                const SizedBox(height: 4),
                                Text(artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.lato(
                                        fontSize: 14,
                                        color: context.colors.stone)),
                                const Spacer(),
                                const Row(
                                  children: [
                                    FaIcon(FontAwesomeIcons.spotify,
                                        size: 16,
                                        color: Color(0xFF1DB954)),
                                    SizedBox(width: 8),
                                    Text("Listen Now",
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1DB954))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── playlist section ───────────────────────────────────────
                const SizedBox(height: 32),
                _buildPlaylistSection(context),

                const SizedBox(height: 32),

                // ── continue button ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthGate()),
                      (route) => false,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.ink,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text("CONTINUE",
                        style: GoogleFonts.lato(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── playlist section widget ────────────────────────────────────────────────

  Widget _buildPlaylistSection(BuildContext context) {
    const arcOptions = [
      {'key': 'lift',  'label': 'Lift Me',    'icon': FontAwesomeIcons.sun,  'desc': 'Shift to lighter'},
      {'key': 'calm',  'label': 'Calm Me',    'icon': FontAwesomeIcons.wind, 'desc': 'Wind down'},
      {'key': 'stay',  'label': 'Stay Here',  'icon': FontAwesomeIcons.leaf, 'desc': 'Sit with it'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: context.colors.stone.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
              color: context.colors.stone.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(FontAwesomeIcons.music,
                    size: 14, color: AppColors.sage),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("MAKE A PLAYLIST",
                      style: GoogleFonts.lato(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                          color: context.colors.stone)),
                  Text("10 songs crafted for this moment",
                      style: GoogleFonts.lato(
                          fontSize: 12, color: context.colors.stone.withValues(alpha: 0.7))),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Arc type chips
          Row(
            children: arcOptions.map((opt) {
              final key      = opt['key'] as String;
              final label    = opt['label'] as String;
              final icon     = opt['icon'] as FaIconData;
              final isActive = _selectedArc == key;

              final chipColor = key == 'lift'
                  ? AppColors.clay
                  : key == 'calm'
                      ? AppColors.sage
                      : const Color(0xFFA8A593);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedArc = key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive
                            ? chipColor.withValues(alpha: 0.12)
                            : context.colors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? chipColor.withValues(alpha: 0.4)
                              : context.colors.stone.withValues(alpha: 0.15),
                          width: isActive ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          FaIcon(icon,
                              size: 14,
                              color: isActive
                                  ? chipColor
                                  : context.colors.stone.withValues(alpha: 0.5)),
                          const SizedBox(height: 4),
                          Text(label,
                              style: GoogleFonts.lato(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? chipColor
                                      : context.colors.stone.withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Generate button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isGenerating ? null : _generatePlaylist,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.ink,
                disabledBackgroundColor:
                    context.colors.ink.withValues(alpha: 0.4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isGenerating
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)),
                        const SizedBox(width: 10),
                        Text('Composing your arc…',
                            style: GoogleFonts.lato(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const FaIcon(FontAwesomeIcons.music, size: 14),
                        const SizedBox(width: 8),
                        Text('GENERATE PLAYLIST',
                            style: GoogleFonts.lato(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.5)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
