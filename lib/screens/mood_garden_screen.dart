import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class MoodGardenScreen extends StatefulWidget {
  const MoodGardenScreen({super.key});

  @override
  State<MoodGardenScreen> createState() => _MoodGardenScreenState();
}

class _MoodGardenScreenState extends State<MoodGardenScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swayController;

  @override
  void initState() {
    super.initState();
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _swayController.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  static _FlowerType _typeFor(double score) {
    if (score >= 8.5) return _FlowerType.sunflower;
    if (score >= 6.5) return _FlowerType.daisy;
    if (score >= 4.5) return _FlowerType.rose;
    if (score >= 2.5) return _FlowerType.tulip;
    return _FlowerType.drooping;
  }

  static Color _petalColor(double score) {
    if (score >= 8.5) return const Color(0xFFCEDA7A);
    if (score >= 6.5) return const Color(0xFF81B29A);
    if (score >= 4.5) return const Color(0xFFF0A878);
    if (score >= 2.5) return const Color(0xFFE07A5F);
    return const Color(0xFFB06040);
  }

  static Color _skyTop(double avg) {
    if (avg >= 7) return const Color(0xFF5BAF8E);
    if (avg >= 4) return const Color(0xFFC8874A);
    return const Color(0xFF8877AA);
  }

  static Color _skyBottom(double avg) {
    if (avg >= 7) return const Color(0xFFB4DEC8);
    if (avg >= 4) return const Color(0xFFEDD5AA);
    return const Color(0xFFCEC4DA);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user   = FirebaseAuth.instance.currentUser;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('entries')
            .orderBy('timestamp', descending: false)
            .limit(60)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          double avgMood = 5.0;
          if (docs.isNotEmpty) {
            double sum = 0;
            for (final d in docs) {
              final raw = d.data() as Map<String, dynamic>;
              sum += (raw['mood_score'] ?? 5.0).toDouble();
            }
            avgMood = sum / docs.length;
          }

          return Stack(
            children: [
              // ── 1. Sky background (fixed) ──────────────────────────────
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: const Alignment(0, 0.5),
                      colors: [_skyTop(avgMood), _skyBottom(avgMood)],
                    ),
                  ),
                ),
              ),

              // ── 2. Garden zone (scrollable) ────────────────────────────
              Positioned(
                top: topPad + 80,
                left: 0,
                right: 0,
                bottom: 0,
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    const double spacing     = 84.0;
                    const double leftPad     = 44.0;
                    const double groundFromB = 60.0;

                    final double totalW = max(
                      constraints.maxWidth,
                      leftPad * 2 + docs.length * spacing + 80,
                    );

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: SizedBox(
                        width: totalW,
                        height: constraints.maxHeight,
                        child: AnimatedBuilder(
                          animation: _swayController,
                          builder: (ctx2, _) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Ground + hills
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _GardenGroundPainter(
                                        avgMood: avgMood),
                                  ),
                                ),

                                // Flowers
                                ...List.generate(docs.length, (i) {
                                  final data = docs[i].data()
                                      as Map<String, dynamic>;
                                  final score  = (data['mood_score'] ?? 5.0)
                                      .toDouble();
                                  final content =
                                      (data['content'] ?? '') as String;
                                  final wc = content
                                      .split(' ')
                                      .length
                                      .clamp(5, 300);
                                  final ts = data['timestamp'] != null
                                      ? (data['timestamp'] as Timestamp)
                                          .toDate()
                                      : DateTime.now();

                                  final rng =
                                      Random(i * 37 + ts.day * 13);
                                  final xJitter =
                                      (rng.nextDouble() - 0.5) * 18.0;
                                  final flowerX =
                                      leftPad + i * spacing + xJitter;

                                  final stemH =
                                      55.0 + (wc / 300.0) * 85.0;
                                  final flowerR =
                                      18.0 + (score / 10.0) * 16.0;
                                  final widgetW = flowerR * 3.0;
                                  final widgetH =
                                      stemH + flowerR * 3.2;

                                  final phase = i * 0.61803;
                                  final amp   = 0.028 *
                                      (0.7 + rng.nextDouble() * 0.6);
                                  final swayAngle = sin(
                                    _swayController.value *
                                            2 *
                                            pi +
                                        phase,
                                  ) * amp;

                                  return Positioned(
                                    key: ValueKey('f_$i'),
                                    bottom: groundFromB,
                                    left: flowerX - widgetW / 2,
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(
                                          begin: 0.0, end: 1.0),
                                      duration: Duration(
                                          milliseconds:
                                              500 + i * 38),
                                      curve: Curves.elasticOut,
                                      builder: (ctx3, bloom, _) {
                                        return Transform.scale(
                                          scale: bloom,
                                          alignment:
                                              Alignment.bottomCenter,
                                          child: Opacity(
                                            opacity:
                                                bloom.clamp(0.0, 1.0),
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _showEntry(
                                                      context,
                                                      data,
                                                      score),
                                              child: Transform.rotate(
                                                angle: swayAngle,
                                                alignment: Alignment
                                                    .bottomCenter,
                                                child: CustomPaint(
                                                  size: Size(
                                                      widgetW,
                                                      widgetH),
                                                  painter:
                                                      _FlowerPainter(
                                                    type: _typeFor(
                                                        score),
                                                    petalColor:
                                                        _petalColor(
                                                            score),
                                                    stemHeight: stemH,
                                                    flowerRadius:
                                                        flowerR,
                                                    seed: i,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── 3. Header ──────────────────────────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Mood Garden",
                              style: GoogleFonts.domine(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text(
                            docs.isEmpty
                                ? "Plant your first memory"
                                : "${docs.length} bloom${docs.length == 1 ? '' : 's'} in your garden",
                            style: GoogleFonts.lato(
                                fontSize: 12,
                                color: Colors.white70),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (docs.length > 4)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.swipe_rounded,
                                  color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Text("Scroll",
                                  style: GoogleFonts.lato(
                                      fontSize: 11,
                                      color: Colors.white70)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── 4. Empty state ─────────────────────────────────────────
              if (docs.isEmpty && snapshot.hasData)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 60),
                      const FaIcon(FontAwesomeIcons.seedling,
                          color: Colors.white54, size: 52),
                      const SizedBox(height: 18),
                      Text("Your garden awaits",
                          style: GoogleFonts.domine(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text("Each journal entry grows a flower",
                          style: GoogleFonts.lato(
                              color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),

              // ── 5. Legend ──────────────────────────────────────────────
              if (docs.isNotEmpty)
                Positioned(
                  bottom: 20,
                  right: 16,
                  child: _buildLegend(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    const items = [
      (label: 'Radiant (8.5–10)', color: Color(0xFFCEDA7A)),
      (label: 'Lifted  (6.5–8.4)', color: Color(0xFF81B29A)),
      (label: 'Steady  (4.5–6.4)', color: Color(0xFFF0A878)),
      (label: 'Heavy   (2.5–4.4)', color: Color(0xFFE07A5F)),
      (label: 'Weary   (0–2.4)',   color: Color(0xFFB06040)),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("GARDEN KEY",
              style: GoogleFonts.lato(
                  fontSize: 9,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white60)),
          const SizedBox(height: 7),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(item.label,
                      style: GoogleFonts.lato(
                          fontSize: 10, color: Colors.white70)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEntry(BuildContext context, Map<String, dynamic> data,
      double score) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GardenEntrySheet(data: data, score: score),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry detail sheet
// ─────────────────────────────────────────────────────────────────────────────

class _GardenEntrySheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final double score;

  const _GardenEntrySheet({required this.data, required this.score});

  static Color _petalColor(double s) {
    if (s >= 8.5) return const Color(0xFFCEDA7A);
    if (s >= 6.5) return const Color(0xFF81B29A);
    if (s >= 4.5) return const Color(0xFFF0A878);
    if (s >= 2.5) return const Color(0xFFE07A5F);
    return const Color(0xFFB06040);
  }

  @override
  Widget build(BuildContext context) {
    final color   = _petalColor(score);
    final ts      = data['timestamp'] != null
        ? (data['timestamp'] as Timestamp).toDate()
        : DateTime.now();
    final mood    = data['mood_label']  as String? ?? 'Reflective';
    final content = data['content']     as String? ?? '';
    final track   = data['track_name']  as String?;
    final artist  = data['artist']      as String?;
    final imgUrl  = data['image_url']   as String?;
    final prompt  = data['prompt_used'] as String?;

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // colour strip
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: color,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.colors.stone.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // date + mood pill
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, MMMM d').format(ts),
                              style: GoogleFonts.domine(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: context.colors.ink),
                            ),
                            Text(
                              DateFormat('h:mm a  ·  yyyy').format(ts),
                              style: GoogleFonts.lato(
                                  fontSize: 12,
                                  color: context.colors.stone),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: color.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          "$mood · ${score.toStringAsFixed(1)}",
                          style: GoogleFonts.lato(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: color),
                        ),
                      ),
                    ],
                  ),

                  if (prompt != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: color.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          FaIcon(FontAwesomeIcons.quoteLeft,
                              size: 10, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(prompt,
                                style: GoogleFonts.lato(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: context.colors.stone)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Divider(
                      color:
                          context.colors.stone.withValues(alpha: 0.12)),
                  const SizedBox(height: 14),

                  // journal content
                  Text(content,
                      style: GoogleFonts.lato(
                          fontSize: 15,
                          height: 1.78,
                          color: context.colors.ink)),

                  // soundtrack
                  if (track != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: context.colors.stone
                                .withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: imgUrl != null
                                ? Image.network(imgUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _musicFallback(context))
                                : _musicFallback(context),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text("SOUNDTRACK",
                                    style: GoogleFonts.lato(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        color: AppColors.sage)),
                                Text(track,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.domine(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: context.colors.ink)),
                                if (artist != null)
                                  Text(artist,
                                      maxLines: 1,
                                      style: GoogleFonts.lato(
                                          fontSize: 12,
                                          color: context.colors.stone)),
                              ],
                            ),
                          ),
                          const FaIcon(FontAwesomeIcons.spotify,
                              color: Color(0xFF1DB954), size: 20),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _musicFallback(BuildContext context) => Container(
        width: 48,
        height: 48,
        color: context.colors.stone,
        child: const Icon(Icons.music_note, color: Colors.white, size: 22),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Garden background — hills, ground, grass
// ─────────────────────────────────────────────────────────────────────────────

class _GardenGroundPainter extends CustomPainter {
  final double avgMood;
  const _GardenGroundPainter({required this.avgMood});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // far hills
    _hills(canvas, w, h,
        yFrac: 0.34, amp: 0.13, count: 4,
        color: avgMood >= 7
            ? const Color(0xFF4A9A7A)
            : avgMood >= 4
                ? const Color(0xFF8A7040)
                : const Color(0xFF6A5A88),
        opacity: 0.32);

    // near hills
    _hills(canvas, w, h,
        yFrac: 0.50, amp: 0.11, count: 3,
        color: avgMood >= 7
            ? const Color(0xFF3A8A6A)
            : avgMood >= 4
                ? const Color(0xFF7A6030)
                : const Color(0xFF5A4A78),
        opacity: 0.58);

    // ground fill
    final groundY = h * 0.64;
    final gPath = Path()
      ..moveTo(0, groundY)
      ..cubicTo(w * 0.3, groundY - 7, w * 0.7, groundY + 7, w, groundY)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(gPath, Paint()..color = const Color(0xFF4A2E0E));

    // lighter dirt band
    final dirtPath = Path()
      ..moveTo(0, groundY)
      ..cubicTo(w * 0.3, groundY - 7, w * 0.7, groundY + 7, w, groundY)
      ..lineTo(w, groundY + 22)
      ..cubicTo(w * 0.7, groundY + 29, w * 0.3, groundY + 15, 0, groundY + 22)
      ..close();
    canvas.drawPath(
        dirtPath, Paint()..color = const Color(0xFF5C3D1A).withValues(alpha: 0.55));

    // grass blades
    _grass(canvas, w, groundY);
  }

  void _hills(Canvas canvas, double w, double h,
      {required double yFrac,
      required double amp,
      required int count,
      required Color color,
      required double opacity}) {
    final paint = Paint()..color = color.withValues(alpha: opacity);
    final segW  = w / count;
    final baseY = h * yFrac;
    final a     = h * amp;
    final path  = Path()..moveTo(0, baseY);
    for (int i = 0; i < count; i++) {
      path.quadraticBezierTo(
          i * segW + segW * 0.5, baseY - a, (i + 1) * segW, baseY);
    }
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _grass(Canvas canvas, double w, double groundY) {
    final paint = Paint()
      ..color = const Color(0xFF4E9A5E)
      ..style = PaintingStyle.fill;
    final rng = Random(999);
    for (double x = 0; x < w; x += 5) {
      final bh   = 9.0 + rng.nextDouble() * 13.0;
      final lean = (rng.nextDouble() - 0.5) * 8.0;
      final path = Path()
        ..moveTo(x, groundY)
        ..quadraticBezierTo(
            x + lean * 0.6, groundY - bh * 0.55, x + lean, groundY - bh)
        ..quadraticBezierTo(
            x + lean * 0.4, groundY - bh * 0.55, x + 3, groundY);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_GardenGroundPainter old) => old.avgMood != avgMood;
}

// ─────────────────────────────────────────────────────────────────────────────
// Flower types enum
// ─────────────────────────────────────────────────────────────────────────────

enum _FlowerType { sunflower, daisy, rose, tulip, drooping }

// ─────────────────────────────────────────────────────────────────────────────
// Flower painter
// ─────────────────────────────────────────────────────────────────────────────

class _FlowerPainter extends CustomPainter {
  final _FlowerType type;
  final Color petalColor;
  final double stemHeight;
  final double flowerRadius;
  final int seed;

  const _FlowerPainter({
    required this.type,
    required this.petalColor,
    required this.stemHeight,
    required this.flowerRadius,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng    = Random(seed);
    final cx     = size.width / 2;
    final bottom = size.height;
    final lean   = (rng.nextDouble() - 0.5) * 14.0;
    final fy     = bottom - stemHeight - flowerRadius * 1.2;

    // stem
    final stemPaint = Paint()
      ..color     = const Color(0xFF3A7040)
      ..style     = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    final stemPath = Path()
      ..moveTo(cx, bottom)
      ..quadraticBezierTo(
          cx + lean * 0.65, bottom - stemHeight * 0.55,
          cx + lean * 0.1, fy + flowerRadius * 1.1);
    canvas.drawPath(stemPath, stemPaint);

    // leaves
    if (stemHeight > 55) {
      _leaf(canvas, cx + lean * 0.32, bottom - stemHeight * 0.38, 1, rng);
    }
    if (stemHeight > 85) {
      _leaf(canvas, cx + lean * 0.55, bottom - stemHeight * 0.62, -1, rng);
    }

    // bloom
    final bx = cx + lean * 0.1;
    switch (type) {
      case _FlowerType.sunflower:
        _sunflower(canvas, bx, fy, flowerRadius, rng);
      case _FlowerType.daisy:
        _daisy(canvas, bx, fy, flowerRadius);
      case _FlowerType.rose:
        _rose(canvas, bx, fy, flowerRadius);
      case _FlowerType.tulip:
        _tulip(canvas, bx, fy, flowerRadius);
      case _FlowerType.drooping:
        _drooping(canvas, bx, fy, flowerRadius);
    }
  }

  void _leaf(Canvas canvas, double x, double y, int dir, Random rng) {
    final c    = Color.lerp(const Color(0xFF4A8A4A),
        const Color(0xFF6AAA6A), rng.nextDouble())!;
    final len  = 14.0 + rng.nextDouble() * 8.0;
    final path = Path()
      ..moveTo(x, y)
      ..quadraticBezierTo(
          x + dir * len * 0.8, y - len * 0.35, x + dir * len, y)
      ..quadraticBezierTo(
          x + dir * len * 0.6, y + len * 0.35, x, y);
    canvas.drawPath(path, Paint()..color = c..style = PaintingStyle.fill);
    canvas.drawLine(
      Offset(x, y),
      Offset(x + dir * len * 0.72, y),
      Paint()
        ..color       = const Color(0xFF2A6A2A)
        ..strokeWidth = 0.8
        ..style       = PaintingStyle.stroke,
    );
  }

  void _sunflower(Canvas canvas, double cx, double cy, double r, Random rng) {
    const n = 13;
    final pp = Paint()..color = petalColor..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      final a    = (i / n) * 2 * pi - pi / 2;
      final path = Path()
        ..moveTo(cx + cos(a - 0.18) * r * 0.38,
                 cy + sin(a - 0.18) * r * 0.38)
        ..cubicTo(
            cx + cos(a - 0.28) * r * 1.5, cy + sin(a - 0.28) * r * 1.5,
            cx + cos(a)        * r * 1.72, cy + sin(a)        * r * 1.72,
            cx + cos(a)        * r * 1.72, cy + sin(a)        * r * 1.72)
        ..cubicTo(
            cx + cos(a + 0.28) * r * 1.5, cy + sin(a + 0.28) * r * 1.5,
            cx + cos(a + 0.18) * r * 0.38, cy + sin(a + 0.18) * r * 0.38,
            cx + cos(a - 0.18) * r * 0.38, cy + sin(a - 0.18) * r * 0.38);
      canvas.drawPath(path, pp);
    }
    canvas.drawCircle(
        Offset(cx, cy), r * 0.42, Paint()..color = const Color(0xFF3C2208));
    final dp = Paint()..color = const Color(0xFF6A3A0A)..style = PaintingStyle.fill;
    for (int i = 0; i < 12; i++) {
      final a = i / 12 * 2 * pi;
      canvas.drawCircle(
          Offset(cx + cos(a) * r * 0.2, cy + sin(a) * r * 0.2), 1.5, dp);
    }
    canvas.drawCircle(Offset(cx, cy), r * 0.12,
        Paint()..color = const Color(0xFF2A1505));
  }

  void _daisy(Canvas canvas, double cx, double cy, double r) {
    const n  = 14;
    final pp = Paint()
      ..color = petalColor.withValues(alpha: 0.88)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      final a   = (i / n) * 2 * pi;
      final len = r * (i.isEven ? 1.62 : 1.46);
      const hw  = 0.14;
      final path = Path()
        ..moveTo(cx + cos(a - 0.08) * r * 0.28,
                 cy + sin(a - 0.08) * r * 0.28)
        ..cubicTo(
            cx + cos(a - hw) * len * 0.7, cy + sin(a - hw) * len * 0.7,
            cx + cos(a - hw * 0.5) * len, cy + sin(a - hw * 0.5) * len,
            cx + cos(a) * len,            cy + sin(a) * len)
        ..cubicTo(
            cx + cos(a + hw * 0.5) * len, cy + sin(a + hw * 0.5) * len,
            cx + cos(a + hw) * len * 0.7, cy + sin(a + hw) * len * 0.7,
            cx + cos(a + 0.08) * r * 0.28,
            cy + sin(a + 0.08) * r * 0.28);
      canvas.drawPath(path, pp);
    }
    canvas.drawCircle(Offset(cx, cy), r * 0.32,
        Paint()..color = const Color(0xFFF5C842));
    canvas.drawCircle(Offset(cx, cy), r * 0.18,
        Paint()..color = const Color(0xFFD4900A));
  }

  void _rose(Canvas canvas, double cx, double cy, double r) {
    final layers = [
      (count: 5, rf: 0.95, alpha: 0.62, rot: 0.0),
      (count: 5, rf: 0.72, alpha: 0.80, rot: pi / 5),
      (count: 4, rf: 0.50, alpha: 1.0,  rot: pi / 8),
    ];
    for (final L in layers) {
      final pp = Paint()
        ..color = petalColor.withValues(alpha: L.alpha)
        ..style = PaintingStyle.fill;
      final pr = r * L.rf;
      for (int i = 0; i < L.count; i++) {
        final a    = (i / L.count) * 2 * pi + L.rot;
        final path = Path()
          ..moveTo(cx, cy)
          ..cubicTo(
              cx + cos(a - 0.45) * pr * 1.1,
              cy + sin(a - 0.45) * pr * 1.1,
              cx + cos(a)        * pr * 1.3,
              cy + sin(a)        * pr * 1.3,
              cx + cos(a + 0.45) * pr * 1.1,
              cy + sin(a + 0.45) * pr * 1.1)
          ..close();
        canvas.drawPath(path, pp);
      }
    }
    canvas.drawCircle(Offset(cx, cy), r * 0.18,
        Paint()..color = petalColor);
  }

  void _tulip(Canvas canvas, double cx, double cy, double r) {
    final dark  = Color.lerp(petalColor, Colors.black, 0.18)!;
    final light = Color.lerp(petalColor, Colors.white, 0.15)!;

    // cup base
    final cup = Path()
      ..moveTo(cx - r * 0.55, cy + r * 0.35)
      ..cubicTo(cx - r * 0.7, cy - r * 0.42,
                cx + r * 0.7, cy - r * 0.42,
                cx + r * 0.55, cy + r * 0.35)
      ..quadraticBezierTo(cx, cy + r * 0.62, cx - r * 0.55, cy + r * 0.35);
    canvas.drawPath(cup, Paint()..color = dark..style = PaintingStyle.fill);

    // left petal
    final lp = Path()
      ..moveTo(cx - r * 0.55, cy + r * 0.35)
      ..cubicTo(cx - r * 1.12, cy + r * 0.08,
                cx - r * 1.0,  cy - r * 0.62,
                cx - r * 0.4,  cy - r * 0.82)
      ..cubicTo(cx - r * 0.18, cy - r * 0.42,
                cx - r * 0.38, cy - r * 0.08,
                cx - r * 0.08, cy + r * 0.1);
    canvas.drawPath(lp, Paint()..color = petalColor..style = PaintingStyle.fill);

    // right petal
    final rp = Path()
      ..moveTo(cx + r * 0.55, cy + r * 0.35)
      ..cubicTo(cx + r * 1.12, cy + r * 0.08,
                cx + r * 1.0,  cy - r * 0.62,
                cx + r * 0.4,  cy - r * 0.82)
      ..cubicTo(cx + r * 0.18, cy - r * 0.42,
                cx + r * 0.38, cy - r * 0.08,
                cx + r * 0.08, cy + r * 0.1);
    canvas.drawPath(rp, Paint()..color = petalColor..style = PaintingStyle.fill);

    // front petal (lighter)
    final fp = Path()
      ..moveTo(cx - r * 0.32, cy + r * 0.22)
      ..cubicTo(cx - r * 0.52, cy - r * 0.52,
                cx + r * 0.52, cy - r * 0.52,
                cx + r * 0.32, cy + r * 0.22)
      ..quadraticBezierTo(cx, cy + r * 0.48, cx - r * 0.32, cy + r * 0.22);
    canvas.drawPath(fp, Paint()..color = light..style = PaintingStyle.fill);
  }

  void _drooping(Canvas canvas, double cx, double cy, double r) {
    const n   = 6;
    final pp  = Paint()
      ..color = petalColor.withValues(alpha: 0.80)
      ..style = PaintingStyle.fill;
    const sag = 0.42;
    for (int i = 0; i < n; i++) {
      final a    = (i / n) * 2 * pi;
      final path = Path()
        ..moveTo(cx + cos(a - 0.12) * r * 0.28,
                 cy + sin(a - 0.12) * r * 0.28)
        ..cubicTo(
            cx + cos(a - 0.22) * r * 0.9,
            cy + sin(a - 0.22) * r * 0.9 + r * sag,
            cx + cos(a)        * r * 1.16,
            cy + sin(a)        * r * 1.16 + r * sag * 1.2,
            cx + cos(a + 0.22) * r * 0.9,
            cy + sin(a + 0.22) * r * 0.9 + r * sag)
        ..cubicTo(
            cx + cos(a + 0.22) * r * 0.9,
            cy + sin(a + 0.22) * r * 0.9 + r * sag,
            cx + cos(a + 0.12) * r * 0.28,
            cy + sin(a + 0.12) * r * 0.28,
            cx + cos(a - 0.12) * r * 0.28,
            cy + sin(a - 0.12) * r * 0.28);
      canvas.drawPath(path, pp);
    }
    canvas.drawCircle(Offset(cx, cy), r * 0.22,
        Paint()..color = petalColor.withValues(alpha: 0.7));
    canvas.drawCircle(Offset(cx, cy), r * 0.12,
        Paint()..color = petalColor);
  }

  @override
  bool shouldRepaint(_FlowerPainter old) =>
      old.type != type ||
      old.flowerRadius != flowerRadius ||
      old.petalColor != petalColor;
}
