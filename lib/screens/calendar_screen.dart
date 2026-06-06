import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/colors.dart';
import 'entry_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  // ── data ──────────────────────────────────────────────────────────────────
  /// Keyed by midnight-normalised date → list of entries for that day.
  Map<DateTime, List<Map<String, dynamic>>> _entries = {};
  bool _isLoading = true;

  // ── calendar state ─────────────────────────────────────────────────────────
  DateTime _focusedDay  = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // ── animation ──────────────────────────────────────────────────────────────
  late AnimationController _slideController;

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _loadAllEntries();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA LOADING
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadAllEntries() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Query both collections in parallel
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('entries')
            .orderBy('timestamp', descending: true)
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('journal')
            .orderBy('timestamp', descending: true)
            .get(),
      ]);

      final map = <DateTime, List<Map<String, dynamic>>>{};

      for (final snap in results) {
        for (final doc in snap.docs) {
          final raw = doc.data();
          final ts  = raw['timestamp'] as Timestamp?;
          if (ts == null) continue;

          // Normalise field names for uniform access
          final entry = <String, dynamic>{
            ...raw,
            'id':      doc.id,
            // unified content field
            'content': raw['content'] ?? raw['text'] ?? '',
            // unified mood field
            'mood':    raw['mood'] ?? raw['mood_label'] ?? 'Reflective',
            // unified score field (int)
            'score':   ((raw['mood_score'] ?? raw['score'] ?? 5) as num).round(),
          };

          final date = _norm(ts.toDate());
          map.putIfAbsent(date, () => []).add(entry);
        }
      }

      // Sort each day's entries newest-first
      for (final list in map.values) {
        list.sort((a, b) {
          final ta = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
          final tb = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
          return tb.compareTo(ta);
        });
      }

      if (mounted) {
        setState(() {
          _entries   = map;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('CalendarScreen load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Strip time component — used as Map key.
  DateTime _norm(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Events for a given calendar day.
  List<Map<String, dynamic>> _eventsFor(DateTime day) =>
      _entries[_norm(day)] ?? [];

  /// Mood-score → display colour.
  Color _moodColor(num score) {
    if (score >= 7) return AppColors.sage;
    if (score >= 4) return const Color(0xFFA8A593);
    return AppColors.clay;
  }

  /// Average score for a list of entries.
  double _avgScore(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return 0;
    final total = list.fold<double>(
        0, (sum, e) => sum + ((e['score'] as num?) ?? 5).toDouble());
    return total / list.length;
  }

  /// Compute stats for the currently focused month.
  ({int count, double avg, DateTime? bestDay}) _monthStats() {
    int count         = 0;
    double totalScore = 0;
    double bestScore  = -1;
    DateTime? bestDay;

    for (final entry in _entries.entries) {
      final d = entry.key;
      if (d.year != _focusedDay.year || d.month != _focusedDay.month) continue;
      final dayAvg = _avgScore(entry.value);
      count += entry.value.length;
      totalScore += dayAvg * entry.value.length;
      if (dayAvg > bestScore) {
        bestScore = dayAvg;
        bestDay   = d;
      }
    }

    return (
      count:   count,
      avg:     count > 0 ? totalScore / count : 0,
      bestDay: bestDay,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: _isLoading ? _buildLoader() : _buildContent(),
    );
  }

  // ── loader ─────────────────────────────────────────────────────────────────

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.sage,
            strokeWidth: 2,
          ),
          const SizedBox(height: 16),
          Text(
            "Loading your journal...",
            style: GoogleFonts.lato(fontSize: 14, color: context.colors.stone),
          ),
        ],
      ),
    );
  }

  // ── main content ───────────────────────────────────────────────────────────

  Widget _buildContent() {
    final stats        = _monthStats();
    final selectedList = _eventsFor(_selectedDay);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [

          // ── top bar ───────────────────────────────────────────────────────
          _buildTopBar(),

          // ── monthly stats strip ───────────────────────────────────────────
          _buildStatsStrip(stats),

          // ── calendar ──────────────────────────────────────────────────────
          _buildCalendar(),

          // ── divider ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              color: context.colors.stone.withValues(alpha: 0.12),
              height: 1,
            ),
          ),

          const SizedBox(height: 12),

          // ── selected day label ────────────────────────────────────────────
          _buildDayLabel(selectedList),

          const SizedBox(height: 10),

          // ── entry list or empty ───────────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: selectedList.isEmpty
                  ? _buildEmptyDay(
                      key: ValueKey('empty_${_selectedDay.toIso8601String()}'))
                  : _buildEntryList(
                      selectedList,
                      key: ValueKey('list_${_selectedDay.toIso8601String()}')),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  // ── top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    final isThisMonth = _focusedDay.year == DateTime.now().year &&
        _focusedDay.month == DateTime.now().month;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: context.colors.stone.withValues(alpha: 0.18)),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: context.colors.stone, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "JOURNAL HISTORY",
                  style: GoogleFonts.lato(
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                    color: AppColors.sage,
                  ),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedDay),
                  style: GoogleFonts.domine(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.colors.ink,
                  ),
                ),
              ],
            ),
          ),

          // "Today" jump button — only visible when away from current month
          AnimatedOpacity(
            opacity: isThisMonth ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            child: GestureDetector(
              onTap: isThisMonth
                  ? null
                  : () => setState(() {
                        _focusedDay  = DateTime.now();
                        _selectedDay = DateTime.now();
                      }),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.sage.withValues(alpha: 0.35)),
                ),
                child: Text(
                  "Today",
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.sage,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  // ── stats strip ────────────────────────────────────────────────────────────

  Widget _buildStatsStrip(
      ({int count, double avg, DateTime? bestDay}) stats) {
    String avgLabel;
    Color avgColor;
    if (stats.avg >= 7) {
      avgLabel = '${stats.avg.toStringAsFixed(1)} 🌿';
      avgColor = AppColors.sage;
    } else if (stats.avg >= 4) {
      avgLabel = '${stats.avg.toStringAsFixed(1)} 🌤';
      avgColor = const Color(0xFFA8A593);
    } else if (stats.count > 0) {
      avgLabel = '${stats.avg.toStringAsFixed(1)} 🌧';
      avgColor = AppColors.clay;
    } else {
      avgLabel = '—';
      avgColor = context.colors.stone;
    }

    final bestLabel = stats.bestDay != null
        ? DateFormat('EEE d').format(stats.bestDay!)
        : '—';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          _statChip(
            icon: FontAwesomeIcons.bookOpen,
            value: stats.count > 0 ? '${stats.count}' : '—',
            label: 'Entries',
            color: context.colors.stone,
          ),
          const SizedBox(width: 10),
          _statChip(
            icon: FontAwesomeIcons.heart,
            value: avgLabel,
            label: 'Avg Mood',
            color: avgColor,
          ),
          const SizedBox(width: 10),
          _statChip(
            icon: FontAwesomeIcons.star,
            value: bestLabel,
            label: 'Best Day',
            color: AppColors.sage,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 80.ms);
  }

  Widget _statChip({
    required FaIconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: context.colors.stone.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FaIcon(icon, size: 11, color: color),
            const SizedBox(height: 5),
            Text(
              value,
              style: GoogleFonts.domine(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.colors.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: GoogleFonts.lato(
                  fontSize: 10, color: context.colors.stone),
            ),
          ],
        ),
      ),
    );
  }

  // ── calendar ───────────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: context.colors.stone.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: TableCalendar<Map<String, dynamic>>(
          firstDay: DateTime.utc(2023, 1, 1),
          lastDay:  DateTime.utc(2030, 12, 31),
          focusedDay:  _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: _eventsFor,

          // Page changed
          onPageChanged: (fd) {
            setState(() => _focusedDay = fd);
          },

          // Day selected
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = selected;
              _focusedDay  = focused;
              _slideController
                ..reset()
                ..forward();
            });
          },

          // Calendar format (locked to month)
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},

          // ── Header ──────────────────────────────────────────────────────
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: GoogleFonts.domine(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: context.colors.ink,
            ),
            leftChevronIcon: Icon(
              Icons.chevron_left_rounded,
              color: context.colors.stone,
              size: 22,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right_rounded,
              color: context.colors.stone,
              size: 22,
            ),
            headerPadding: const EdgeInsets.symmetric(vertical: 10),
            leftChevronPadding: const EdgeInsets.all(8),
            rightChevronPadding: const EdgeInsets.all(8),
          ),

          // ── Day-of-week labels ───────────────────────────────────────────
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: context.colors.stone,
            ),
            weekendStyle: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.clay.withValues(alpha: 0.7),
            ),
          ),

          // ── Calendar cell styles ─────────────────────────────────────────
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            cellMargin: const EdgeInsets.all(3),

            // Default
            defaultTextStyle: GoogleFonts.lato(
              fontSize: 14,
              color: context.colors.ink,
            ),
            weekendTextStyle: GoogleFonts.lato(
              fontSize: 14,
              color: context.colors.ink,
            ),

            // Today
            todayDecoration: BoxDecoration(
              border: Border.all(color: AppColors.sage, width: 1.8),
              shape: BoxShape.circle,
            ),
            todayTextStyle: GoogleFonts.lato(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.sage,
            ),

            // Selected
            selectedDecoration: const BoxDecoration(
              color: AppColors.sage,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: GoogleFonts.lato(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),

            // Markers
            markersMaxCount: 3,
            markerSize: 5,
            markerMargin: const EdgeInsets.symmetric(horizontal: 1),
          ),

          // ── Custom builders ──────────────────────────────────────────────
          calendarBuilders: CalendarBuilders(

            // Custom mood-coloured marker dots
            markerBuilder: (ctx, day, events) {
              if (events.isEmpty) return const SizedBox.shrink();

              final dots = events.take(3).map((e) {
                final score =
                    ((e['score'] as num?) ?? 5).toDouble();
                return Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: _moodColor(score),
                    shape: BoxShape.circle,
                  ),
                );
              }).toList();

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: dots,
                ),
              );
            },

            // Highlight days that have entries (even when not selected)
            defaultBuilder: (ctx, day, _) {
              final hasEntries = _eventsFor(day).isNotEmpty;
              if (!hasEntries) return null; // use default
              return Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${day.day}',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.ink,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 120.ms);
  }

  // ── day label ──────────────────────────────────────────────────────────────

  Widget _buildDayLabel(List<Map<String, dynamic>> entries) {
    final isToday    = isSameDay(_selectedDay, DateTime.now());
    final dayLabel   = isToday
        ? 'Today'
        : DateFormat('EEEE, MMMM d').format(_selectedDay);
    final countLabel = entries.isEmpty
        ? 'No entries'
        : entries.length == 1
            ? '1 entry'
            : '${entries.length} entries';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dayLabel,
            style: GoogleFonts.domine(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: context.colors.ink,
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: entries.isEmpty
                  ? context.colors.stone.withValues(alpha: 0.08)
                  : AppColors.sage.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              countLabel,
              style: GoogleFonts.lato(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: entries.isEmpty
                    ? context.colors.stone
                    : AppColors.sage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── entry list ─────────────────────────────────────────────────────────────

  Widget _buildEntryList(List<Map<String, dynamic>> entries, {Key? key}) {
    return ListView.builder(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      itemCount: entries.length,
      itemBuilder: (ctx, i) => _buildEntryCard(entries[i], i),
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry, int index) {
    final bool isVent    = entry['is_vent'] == true;
    final String mood    = entry['mood'] as String? ?? 'Reflective';
    final int score      = (entry['score'] as num?)?.toInt() ?? 5;
    final String content = entry['content'] as String? ?? '';
    final String track   = entry['track_name'] as String? ?? '';
    final String artist  = entry['artist'] as String? ?? '';
    final String imgUrl  = entry['image_url'] as String? ?? '';
    final ts             = entry['timestamp'] as Timestamp?;
    final DateTime time  = ts?.toDate() ?? DateTime.now();
    final moodCol        = _moodColor(score);

    final excerpt = content.length > 120
        ? '${content.substring(0, 120).trimRight()}…'
        : content;
    final timeStr = DateFormat('h:mm a').format(time);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EntryDetailScreen(data: entry),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: context.colors.stone.withValues(alpha: 0.10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── left mood accent bar ─────────────────────────────────────
            Container(
              width: 4,
              height: double.infinity,
              constraints: const BoxConstraints(minHeight: 80),
              decoration: BoxDecoration(
                color: isVent
                    ? AppColors.clay
                    : moodCol,
                borderRadius: const BorderRadius.only(
                  topLeft:    Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
            ),

            // ── content ─────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Mood label + score + time
                    Row(
                      children: [
                        if (isVent) ...[
                          const Text("🔥",
                              style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            isVent ? 'Venting' : mood,
                            style: GoogleFonts.domine(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isVent ? AppColors.clay : moodCol,
                            ),
                          ),
                        ),
                        // score pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isVent ? AppColors.clay : moodCol)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isVent ? 'Vent' : '$score/10',
                            style: GoogleFonts.lato(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isVent ? AppColors.clay : moodCol,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: GoogleFonts.lato(
                            fontSize: 11,
                            color: context.colors.stone,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 7),

                    // Entry excerpt
                    if (excerpt.isNotEmpty)
                      Text(
                        excerpt,
                        style: GoogleFonts.domine(
                          fontSize: 13,
                          color: context.colors.ink
                              .withValues(alpha: 0.72),
                          height: 1.55,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                    // Song info row (non-vent only)
                    if (!isVent && track.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Thumbnail
                          if (imgUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                imgUrl,
                                width: 28,
                                height: 28,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            )
                          else
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF1DB954).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(FontAwesomeIcons.spotify,
                                  size: 14,
                                  color: Color(0xFF1DB954)),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              artist.isNotEmpty
                                  ? '$track · $artist'
                                  : track,
                              style: GoogleFonts.lato(
                                fontSize: 11,
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
                  ],
                ),
              ),
            ),

            // ── right arrow ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: context.colors.stone.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      )
          .animate(delay: (index * 40).ms)
          .fadeIn(duration: 350.ms)
          .slideY(begin: 0.1, end: 0),
    );
  }

  // ── empty day ──────────────────────────────────────────────────────────────

  Widget _buildEmptyDay({Key? key}) {
    final isToday    = isSameDay(_selectedDay, DateTime.now());
    final isFuture   = _selectedDay.isAfter(DateTime.now());

    String emoji, headline, sub;
    if (isFuture) {
      emoji    = '🌱';
      headline = 'A blank page waiting.';
      sub      = 'Come back when the day arrives.';
    } else if (isToday) {
      emoji    = '✍️';
      headline = 'Nothing written yet.';
      sub      = 'How are you feeling today?';
    } else {
      emoji    = '🌙';
      headline = 'A quiet day.';
      sub      = 'No entries were written here.';
    }

    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 52))
                .animate()
                .scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1, 1),
                    duration: 500.ms,
                    curve: Curves.elasticOut),
            const SizedBox(height: 16),
            Text(
              headline,
              style: GoogleFonts.domine(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.colors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              sub,
              style: GoogleFonts.lato(
                  fontSize: 14, color: context.colors.stone),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
