import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';
import 'spotify_auth_screen.dart';

class PlaylistScreen extends StatefulWidget {
  final Map<String, dynamic> playlistData;
  final String mood;
  final String arcType;

  const PlaylistScreen({
    super.key,
    required this.playlistData,
    required this.mood,
    required this.arcType,
  });

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  bool _isSaving = false;
  String? _savedUrl;
  String? _firestoreDocId;
  bool _isSpotifyConnected = false;

  String get _backendUrl {
    const String liveUrl = "https://mindfull-backend-15b6.onrender.com";
    if (kIsWeb) return liveUrl;
    return liveUrl;
  }

  // ── colours keyed to arc type ─────────────────────────────────────────────
  Color get _arcColor {
    switch (widget.arcType) {
      case 'lift':  return AppColors.clay;
      case 'calm':  return AppColors.sage;
      default:      return const Color(0xFFA8A593);
    }
  }

  String get _arcLabel {
    switch (widget.arcType) {
      case 'lift':  return 'Lift Arc';
      case 'calm':  return 'Calm Arc';
      default:      return 'Stay Arc';
    }
  }

  FaIconData get _arcIcon {
    switch (widget.arcType) {
      case 'lift':  return FontAwesomeIcons.sun;
      case 'calm':  return FontAwesomeIcons.wind;
      default:      return FontAwesomeIcons.leaf;
    }
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkSpotify();
    _saveToFirestore();
  }

  Future<void> _checkSpotify() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _isSpotifyConnected = prefs.containsKey('spotify_token'));
    }
  }

  Future<void> _saveToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final tracks = widget.playlistData['tracks'];
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('playlists')
          .add({
        'title':        widget.playlistData['title'] ?? 'My Playlist',
        'mood':         widget.mood,
        'arc_type':     widget.arcType,
        'tracks':       tracks ?? [],
        'track_count':  (tracks as List?)?.length ?? 0,
        'phase_labels': widget.playlistData['phase_labels'] ?? {},
        'created_at':   FieldValue.serverTimestamp(),
        'spotify_url':  null,
      });
      if (mounted) setState(() => _firestoreDocId = doc.id);
    } catch (e) {
      debugPrint('Firestore playlist save error: $e');
    }
  }

  // ── Spotify save ──────────────────────────────────────────────────────────

  Future<void> _saveToSpotify() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('spotify_token');

    if (token == null) {
      // Launch auth then retry
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SpotifyAuthScreen()),
      );
      if (result == true) {
        await _checkSpotify();
        await _saveToSpotify();
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final tracks = List<Map<String, dynamic>>.from(
          widget.playlistData['tracks'] as List? ?? []);
      final uris = tracks
          .map((t) => t['uri'] as String? ?? '')
          .where((u) => u.isNotEmpty)
          .toList();

      final response = await http.post(
        Uri.parse('$_backendUrl/create-spotify-playlist'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'access_token': token,
          'title':        widget.playlistData['title'] ?? 'MindFull Mix',
          'track_uris':   uris,
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data    = jsonDecode(response.body) as Map<String, dynamic>;
        final url     = data['playlist_url'] as String;
        if (mounted) setState(() => _savedUrl = url);

        // Persist Spotify URL to Firestore
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && _firestoreDocId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('playlists')
              .doc(_firestoreDocId)
              .update({'spotify_url': url});
        }
      } else if (response.statusCode == 401) {
        // Token expired — clear and ask to reconnect
        await prefs.remove('spotify_token');
        if (mounted) {
          setState(() => _isSpotifyConnected = false);
          _showSnack('Spotify session expired — please reconnect.', AppColors.clay);
        }
      } else {
        if (mounted) _showSnack('Spotify error (${response.statusCode}). Try again.', AppColors.clay);
      }
    } on TimeoutException {
      if (mounted) _showSnack('Request timed out. Try again.', AppColors.clay);
    } catch (e) {
      if (mounted) _showSnack('Error: $e', AppColors.clay);
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

  // ── helpers ───────────────────────────────────────────────────────────────

  String _formatDuration(int ms) {
    if (ms <= 0) return '';
    final s = (ms / 1000).round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _openTrack(String uri) async {
    if (uri.isEmpty) return;
    final trackId = uri.replaceFirst('spotify:track:', '');
    final url = Uri.parse('https://open.spotify.com/track/$trackId');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tracks      = List<Map<String, dynamic>>.from(
        widget.playlistData['tracks'] as List? ?? []);
    final phaseLabels = Map<String, dynamic>.from(
        widget.playlistData['phase_labels'] as Map? ?? {});
    final title       = widget.playlistData['title'] as String? ?? 'Your Playlist';

    return Scaffold(
      backgroundColor: context.colors.background,
      body: CustomScrollView(
        slivers: [
          // ── collapsing header ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: context.colors.background,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: context.colors.ink, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _buildHeader(context, title, tracks.length),
            ),
            // Pinned title (shows when fully collapsed)
            title: Text(
              title,
              style: GoogleFonts.domine(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.colors.ink),
            ),
            titleSpacing: 0,
          ),

          // ── track list ───────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _buildTrackWidgets(context, tracks, phaseLabels),
              ),
            ),
          ),

          // Space for bottom bar
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),

      // ── sticky bottom save bar ───────────────────────────────────────
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  // ── header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, String title, int count) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
          colors: [
            _arcColor.withValues(alpha: 0.18),
            _arcColor.withValues(alpha: 0.04),
            context.colors.background,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Arc + mood badges
              Row(
                children: [
                  _badge(
                    icon: _arcIcon,
                    label: _arcLabel,
                    color: _arcColor,
                  ),
                  const SizedBox(width: 8),
                  _badge(
                    icon: FontAwesomeIcons.faceMeh,
                    label: widget.mood,
                    color: context.colors.stone,
                    subtle: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Title
              Text(
                title,
                style: GoogleFonts.domine(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: context.colors.ink,
                  height: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  FaIcon(FontAwesomeIcons.music,
                      size: 11, color: context.colors.stone.withValues(alpha: 0.6)),
                  const SizedBox(width: 5),
                  Text(
                    '$count songs',
                    style: GoogleFonts.lato(
                        fontSize: 12,
                        color: context.colors.stone.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge({
    required FaIconData icon,
    required String label,
    required Color color,
    bool subtle = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: subtle
            ? color.withValues(alpha: 0.08)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: subtle
                ? color.withValues(alpha: 0.15)
                : color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 10, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.lato(
                fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // ── track list ────────────────────────────────────────────────────────────

  List<Widget> _buildTrackWidgets(
    BuildContext context,
    List<Map<String, dynamic>> tracks,
    Map<String, dynamic> phaseLabels,
  ) {
    final widgets = <Widget>[];
    int? lastPhase;

    for (int i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      final phase = (track['phase'] as num?)?.toInt() ?? 1;

      if (phase != lastPhase) {
        if (i > 0) widgets.add(const SizedBox(height: 12));
        final label = (phaseLabels['$phase'] as String?) ??
            (phase == 1 ? 'Mirror' : phase == 2 ? 'Shift' : 'Arrive');
        widgets.add(_buildPhaseDivider(context, label, phase));
        widgets.add(const SizedBox(height: 8));
        lastPhase = phase;
      }

      widgets.add(
        _buildTrackRow(context, track, i + 1)
            .animate()
            .fadeIn(delay: Duration(milliseconds: i * 45), duration: 350.ms)
            .slideX(begin: 0.04, end: 0, curve: Curves.easeOut),
      );
    }

    return widgets;
  }

  Widget _buildPhaseDivider(BuildContext context, String label, int phase) {
    // Phase 1 is most muted, phase 3 is most vivid
    final opacity = phase == 1 ? 0.5 : phase == 2 ? 0.7 : 1.0;
    final color   = _arcColor.withValues(alpha: opacity);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Divider(
                  color: context.colors.stone.withValues(alpha: 0.12),
                  height: 1,
                  endIndent: 12)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _arcColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _arcColor.withValues(alpha: 0.18)),
            ),
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.lato(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: color),
            ),
          ),
          Expanded(
              child: Divider(
                  color: context.colors.stone.withValues(alpha: 0.12),
                  height: 1,
                  indent: 12)),
        ],
      ),
    );
  }

  Widget _buildTrackRow(
      BuildContext context, Map<String, dynamic> track, int index) {
    final uri      = track['uri']         as String? ?? '';
    final trackName= track['track']       as String? ?? 'Unknown Track';
    final artist   = track['artist']      as String? ?? 'Unknown Artist';
    final imageUrl = track['image_url']   as String?;
    final durMs    = (track['duration_ms'] as num?)?.toInt() ?? 0;
    final duration = _formatDuration(durMs);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openTrack(uri),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          child: Row(
            children: [
              // Track number
              SizedBox(
                width: 26,
                child: Text(
                  '$index',
                  style: GoogleFonts.lato(
                      fontSize: 12,
                      color: context.colors.stone.withValues(alpha: 0.4),
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),

              // Album art
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _artFallback(context),
                      )
                    : _artFallback(context),
              ),
              const SizedBox(width: 12),

              // Track + artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trackName,
                      style: GoogleFonts.domine(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: context.colors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      artist,
                      style: GoogleFonts.lato(
                          fontSize: 12, color: context.colors.stone),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Duration
              if (duration.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(duration,
                    style: GoogleFonts.lato(
                        fontSize: 11,
                        color: context.colors.stone.withValues(alpha: 0.5))),
              ],

              const SizedBox(width: 8),
              // Spotify icon — tappable cue
              FaIcon(
                FontAwesomeIcons.spotify,
                size: 15,
                color: const Color(0xFF1DB954).withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _artFallback(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: _arcColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
          child: FaIcon(FontAwesomeIcons.music,
              size: 18, color: _arcColor.withValues(alpha: 0.4))),
    );
  }

  // ── bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: context.colors.background,
        border: Border(
            top: BorderSide(
                color: context.colors.stone.withValues(alpha: 0.1))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: _savedUrl != null
          ? _buildSavedState(context)
          : _buildSaveButton(context),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveToSpotify,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1DB954),
          disabledBackgroundColor: const Color(0xFF1DB954).withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSaving
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
                const SizedBox(width: 12),
                Text('Saving to Spotify…',
                    style: GoogleFonts.lato(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ])
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const FaIcon(FontAwesomeIcons.spotify, size: 18),
                const SizedBox(width: 10),
                Text(
                  _isSpotifyConnected
                      ? 'Save to Spotify'
                      : 'Connect Spotify to Save',
                  style: GoogleFonts.lato(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ]),
      ),
    );
  }

  Widget _buildSavedState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const FaIcon(FontAwesomeIcons.check,
              size: 13, color: Color(0xFF1DB954)),
          const SizedBox(width: 7),
          Text('Saved to your Spotify library!',
              style: GoogleFonts.lato(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1DB954))),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse(_savedUrl!);
              await launchUrl(url, mode: LaunchMode.externalApplication);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF191414),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const FaIcon(FontAwesomeIcons.spotify, size: 16),
              const SizedBox(width: 8),
              Text('Open in Spotify',
                  style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ],
    );
  }
}
