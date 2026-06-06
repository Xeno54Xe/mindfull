import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/colors.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'playlist_screen.dart';

class WritingPage extends StatefulWidget {
  final String prompt;
  final double moodValue;
  final List<String> selectedTags;
  final String weatherContext;
  final String city;

  const WritingPage({
    super.key,
    required this.prompt,
    required this.moodValue,
    required this.selectedTags,
    required this.weatherContext,
    required this.city,
  });

  @override
  State<WritingPage> createState() => _WritingPageState();
}

class _WritingPageState extends State<WritingPage> {
  final TextEditingController _journalController = TextEditingController();
  bool _isSaving = false;

  String get _backendUrl {
    const String liveUrl = "https://mindfull-backend-15b6.onrender.com";
    if (kIsWeb) return liveUrl;
    return liveUrl;
  }

  @override
  void initState() {
    super.initState();
    // Fire-and-forget ping so Render wakes up while the user is writing.
    // By the time they hit Analyze the server is already warm.
    _pingBackend();
  }

  void _pingBackend() {
    http.get(Uri.parse('$_backendUrl/')).timeout(
      const Duration(seconds: 10),
    ).catchError((_) {}); // silently ignore — this is best-effort only
  }

  Future<String> _fetchMusicProfile(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        return (doc.data()?['music_profile'] as String?) ?? "General Pop";
      }
    } catch (_) {}
    return "General Pop";
  }

  Future<void> _saveEntry() async {
    if (_journalController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      String timeString =
          "${now.hour}:${now.minute.toString().padLeft(2, '0')}";
      final musicProfile = await _fetchMusicProfile(user.uid);

      Map<String, dynamic> aiAnalysis = {};
      try {
        final response = await http.post(
          Uri.parse("$_backendUrl/analyze"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "text": _journalController.text,
            "local_time": timeString,
            "music_profile": musicProfile,
          }),
        ).timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          aiAnalysis = jsonDecode(response.body);
        }
      } on TimeoutException {
        debugPrint("⚠️ AI request timed out — saving with fallback data");
      } catch (e) {
        debugPrint("⚠️ AI Offline: $e");
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('entries')
          .add({
        'content': _journalController.text,
        'mood_score': aiAnalysis['score'] ?? widget.moodValue,
        'mood_label': aiAnalysis['mood'] ?? "Reflective",
        'tags': widget.selectedTags,
        'track_name': aiAnalysis['track_name'],
        'artist': aiAnalysis['artist'],
        'image_url': aiAnalysis['image_url'],
        'timestamp': FieldValue.serverTimestamp(),
        'weather_context': widget.weatherContext,
        'location_city': widget.city,
        'prompt_used': widget.prompt,
      });

      aiAnalysis['music_profile_used'] = musicProfile;
      if (mounted) _showAnalysisResult(aiAnalysis);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: $e"),
          backgroundColor: AppColors.clay,
        ));
      }
      setState(() => _isSaving = false);
    }
  }

  void _showAnalysisResult(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AnalysisBottomSheetContent(
        data: data,
        backendUrl: _backendUrl,
        onPlaylistReady: (playlistData, mood, arcType) {
          // Navigate: pop writing page, then open PlaylistScreen
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlaylistScreen(
                playlistData: playlistData,
                mood: mood,
                arcType: arcType,
              ),
            ),
          );
        },
      ),
    );
  }

  // ── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton(
              onPressed: _isSaving ? null : _saveEntry,
              style: TextButton.styleFrom(
                backgroundColor: _isSaving
                    ? Colors.transparent
                    : AppColors.sage.withValues(alpha: 0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.sage))
                  : Text("DONE",
                      style: GoogleFonts.lato(
                          fontWeight: FontWeight.bold,
                          color: AppColors.sage)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("THINKING ABOUT:",
                  style: GoogleFonts.lato(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                      color: context.colors.stone)),
              const SizedBox(height: 10),
              Text(widget.prompt,
                  style: GoogleFonts.domine(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.colors.ink)),
              const SizedBox(height: 30),
              Divider(
                  color: context.colors.stone.withValues(alpha: 0.15)),
              const SizedBox(height: 20),
              Expanded(
                child: TextField(
                  controller: _journalController,
                  maxLines: null,
                  expands: true,
                  style: GoogleFonts.lato(
                      fontSize: 18,
                      height: 1.8,
                      color: context.colors.ink),
                  decoration: InputDecoration(
                    hintText: "Let it flow...",
                    hintStyle: GoogleFonts.lato(
                        color: context.colors.stone
                            .withValues(alpha: 0.5),
                        fontSize: 18),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Analysis Bottom Sheet — StatefulWidget so arc selector has state
// ─────────────────────────────────────────────────────────────────────────────

class _AnalysisBottomSheetContent extends StatefulWidget {
  final Map<String, dynamic> data;
  final String backendUrl;
  final void Function(Map<String, dynamic> playlistData, String mood, String arcType) onPlaylistReady;

  const _AnalysisBottomSheetContent({
    required this.data,
    required this.backendUrl,
    required this.onPlaylistReady,
  });

  @override
  State<_AnalysisBottomSheetContent> createState() =>
      _AnalysisBottomSheetContentState();
}

class _AnalysisBottomSheetContentState
    extends State<_AnalysisBottomSheetContent> {
  late String _selectedArc;
  bool _isGenerating = false;

  static const _arcOptions = [
    {'key': 'lift',  'label': 'Lift Me',   'icon': FontAwesomeIcons.sun,  'desc': 'Shift to lighter'},
    {'key': 'calm',  'label': 'Calm Me',   'icon': FontAwesomeIcons.wind, 'desc': 'Wind down'},
    {'key': 'stay',  'label': 'Stay Here', 'icon': FontAwesomeIcons.leaf, 'desc': 'Sit with it'},
  ];

  @override
  void initState() {
    super.initState();
    final score = widget.data['score'] != null
        ? (widget.data['score'] as num).round()
        : 5;
    _selectedArc = score <= 4 ? 'lift' : score <= 7 ? 'stay' : 'calm';
  }

  Future<void> _generatePlaylist() async {
    setState(() => _isGenerating = true);
    try {
      final mood         = widget.data['mood']               as String? ?? 'Reflective';
      final score        = widget.data['score'] != null
          ? (widget.data['score'] as num).round()
          : 5;
      final musicProfile = widget.data['music_profile_used'] as String? ?? 'General Pop';

      final response = await http.post(
        Uri.parse('${widget.backendUrl}/generate-playlist'),
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
        // Accept partial playlists (4+ tracks) — backend may verify fewer than 10
        if (tracks == null || tracks.length < 4) {
          _showSnack('Couldn\'t generate playlist. Try again.', AppColors.clay);
          return;
        }
        // Pop the bottom sheet, then let the parent navigate
        final arc  = _selectedArc;
        final mood2 = mood;
        Navigator.pop(context);
        widget.onPlaylistReady(playlistData, mood2, arc);
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
    final data = widget.data;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── drag handle ──────────────────────────────────────────────
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: context.colors.stone.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── check icon ───────────────────────────────────────────────
            const FaIcon(FontAwesomeIcons.circleCheck,
                color: AppColors.sage, size: 46),
            const SizedBox(height: 16),
            Text("Memory Captured",
                style: GoogleFonts.domine(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.colors.ink)),
            Text("Here is your vibe report.",
                style: GoogleFonts.lato(color: context.colors.stone)),
            const SizedBox(height: 24),

            // ── mood pill ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${data['mood'] ?? 'Reflective'} • ${data['score'] ?? 5}/10",
                style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.sage),
              ),
            ),
            const SizedBox(height: 20),

            // ── song card ─────────────────────────────────────────────────
            if (data['track_name'] != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: context.colors.stone.withValues(alpha: 0.1),
                        blurRadius: 20)
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: data['image_url'] != null
                          ? Image.network(data['image_url'],
                              width: 60, height: 60, fit: BoxFit.cover)
                          : Container(
                              width: 60,
                              height: 60,
                              color: context.colors.ink,
                              child: const Icon(Icons.music_note,
                                  color: Colors.white)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['track_name'],
                              style: GoogleFonts.domine(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: context.colors.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(data['artist'] ?? '',
                              style: GoogleFonts.lato(
                                  color: context.colors.stone),
                              maxLines: 1),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill,
                          color: Color(0xFF1DB954), size: 40),
                      onPressed: () async {
                        final query = Uri.encodeComponent(
                            "${data['track_name']} ${data['artist']}");
                        final url = Uri.parse(
                            "https://open.spotify.com/search/$query");
                        await launchUrl(url,
                            mode: LaunchMode.externalApplication);
                      },
                    ),
                  ],
                ),
              ),

            if (data['reason'] != null) ...[
              const SizedBox(height: 16),
              Text(
                '"${data['reason']}"',
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: context.colors.stone),
              ),
            ],

            // ── playlist arc section ──────────────────────────────────────
            const SizedBox(height: 28),
            _buildPlaylistSection(context),

            // ── back to home ──────────────────────────────────────────────
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context); // close sheet
                  Navigator.pop(context); // close writing page
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: context.colors.stone.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text("BACK TO HOME",
                    style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.colors.stone)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
          // ── label ─────────────────────────────────────────────────────
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
                          fontSize: 12,
                          color: context.colors.stone
                              .withValues(alpha: 0.7))),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── arc chips ─────────────────────────────────────────────────
          Row(
            children: _arcOptions.map((opt) {
              final key      = opt['key']   as String;
              final label    = opt['label'] as String;
              final icon     = opt['icon']  as FaIconData;
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
                              : context.colors.stone
                                  .withValues(alpha: 0.15),
                          width: isActive ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          FaIcon(icon,
                              size: 14,
                              color: isActive
                                  ? chipColor
                                  : context.colors.stone
                                      .withValues(alpha: 0.5)),
                          const SizedBox(height: 4),
                          Text(label,
                              style: GoogleFonts.lato(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? chipColor
                                      : context.colors.stone
                                          .withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // ── generate button ───────────────────────────────────────────
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
