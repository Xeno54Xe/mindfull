import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';

class EntryDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const EntryDetailScreen({super.key, required this.data});

  Future<void> _launchSpotify(BuildContext context, String track) async {
    final query = Uri.encodeComponent(track);
    final url   = Uri.parse("https://open.spotify.com/search/$query");
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch Spotify');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Couldn't open Spotify: $e"),
            backgroundColor: AppColors.clay,
          ),
        );
      }
    }
  }

  // ── field-name normalisation (handles old 'text' and new 'content' keys) ──
  String _content()  => (data['content'] ?? data['text']      ?? '') as String;
  String _mood()     => (data['mood']    ?? data['mood_label'] ?? 'Reflective') as String;
  String _artist()   => (data['artist']                        ?? '') as String;
  String _track()    => (data['track_name']                    ?? '') as String;
  String _imageUrl() => (data['image_url']                     ?? '') as String;
  String _weather()  => (data['weather_context']               ?? '') as String;
  bool   _isVent()   => data['is_vent'] == true;

  int _score() {
    final raw = data['mood_score'] ?? data['score'] ?? 5;
    return (raw as num).round();
  }

  DateTime _date() {
    final ts = data['timestamp'];
    if (ts == null) return DateTime.now();
    try { return (ts as dynamic).toDate() as DateTime; }
    catch (_) { return DateTime.now(); }
  }

  Color _scoreColor(int score) {
    if (score >= 7) return AppColors.sage;
    if (score >= 4) return const Color(0xFFA8A593);
    return AppColors.clay;
  }

  @override
  Widget build(BuildContext context) {
    final content  = _content();
    final mood     = _mood();
    final artist   = _artist();
    final track    = _track();
    final imageUrl = _imageUrl();
    final weather  = _weather();
    final score    = _score();
    final date     = _date();
    final isVent   = _isVent();
    final scoreCol = isVent ? AppColors.clay : _scoreColor(score);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── Hero image header ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: imageUrl.isNotEmpty ? 380.0 : 180.0,
            floating: false,
            pinned: true,
            backgroundColor: context.colors.card,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrl.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _fallbackHeader(context, scoreCol, mood),
                        ),
                        // Gradient overlay
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.15),
                                Colors.black.withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : _fallbackHeader(context, scoreCol, mood),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 16),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
              decoration: BoxDecoration(
                color: context.colors.background,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              transform: Matrix4.translationValues(0, -24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Date + score pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMMM d, yyyy').format(date),
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          color: context.colors.stone,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: scoreCol.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: scoreCol.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          isVent ? '🔥 Vent' : 'Mood $score/10',
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: scoreCol,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Mood title
                  Text(
                    isVent ? 'Venting' : mood,
                    style: GoogleFonts.domine(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: context.colors.ink,
                    ),
                  ),

                  // Song info
                  if (!isVent && track.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.spotify,
                            size: 14, color: Color(0xFF1DB954)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            artist.isNotEmpty ? '$track · $artist' : track,
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: context.colors.stone,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 28),
                  Divider(
                      color: context.colors.stone.withValues(alpha: 0.15),
                      height: 1),
                  const SizedBox(height: 28),

                  // Entry text
                  Text(
                    content,
                    style: GoogleFonts.domine(
                      fontSize: 17,
                      height: 1.8,
                      color: context.colors.ink,
                    ),
                  ),

                  // Weather context
                  if (weather.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Icon(Icons.cloud_queue_rounded,
                            size: 14, color: context.colors.stone),
                        const SizedBox(width: 8),
                        Text(
                          weather,
                          style: GoogleFonts.lato(
                              fontSize: 12, color: context.colors.stone),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 36),

                  // Play on Spotify button
                  if (!isVent && track.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => _launchSpotify(context, track),
                        icon: const FaIcon(FontAwesomeIcons.spotify,
                            size: 16, color: Color(0xFF1DB954)),
                        label: Text(
                          "Play on Spotify",
                          style: GoogleFonts.lato(
                            fontWeight: FontWeight.bold,
                            color: context.colors.ink,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: context.colors.stone
                                  .withValues(alpha: 0.25)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackHeader(
      BuildContext context, Color accentColor, String mood) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.25),
            context.colors.card,
          ],
        ),
      ),
      child: Center(
        child: Text(
          mood,
          style: GoogleFonts.domine(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: accentColor.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
