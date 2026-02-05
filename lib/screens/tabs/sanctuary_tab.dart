import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/colors.dart';

class SanctuaryTab extends StatefulWidget {
  const SanctuaryTab({super.key});

  @override
  State<SanctuaryTab> createState() => _SanctuaryTabState();
}

class _SanctuaryTabState extends State<SanctuaryTab> {
  bool _isCalendarView = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // --- HELPER: GET MOOD COLOR ---
  Color _getMoodColor(double score) {
    if (score >= 8) return AppColors.sage; // Radiant
    if (score >= 5) return const Color(0xFFA8A593); // Neutral (Olive/Stone)
    return AppColors.clay; // Heavy
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.paperBackground,
      body: SafeArea(
        child: StreamBuilder(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .collection('entries')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.sage));
            
            final docs = snapshot.data!.docs;
            
            // PREPARE DATA FOR CALENDAR
            Map<DateTime, List<QueryDocumentSnapshot>> events = {};
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>; 
              
              if (data['timestamp'] == null) continue; 

              final date = (data['timestamp'] as Timestamp).toDate();
              final dayKey = DateTime(date.year, date.month, date.day); 
              if (events[dayKey] == null) events[dayKey] = [];
              events[dayKey]!.add(doc);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER & TOGGLE ---
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Sanctuary", style: GoogleFonts.domine(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.ink)),
                          Text("Your journey, recorded.", style: GoogleFonts.lato(fontSize: 14, color: AppColors.stone)),
                        ],
                      ),
                      // THE TOGGLE BUTTON
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.stone.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            _ToggleButton(
                              icon: FontAwesomeIcons.calendar, 
                              isActive: _isCalendarView, 
                              onTap: () => setState(() => _isCalendarView = true)
                            ),
                            _ToggleButton(
                              icon: FontAwesomeIcons.list, 
                              isActive: !_isCalendarView, 
                              onTap: () => setState(() => _isCalendarView = false)
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // --- CONTENT AREA ---
                Expanded(
                  child: _isCalendarView 
                    ? _buildCalendarView(events)
                    : _buildListView(docs),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- VIEW 1: MOOD CALENDAR ---
  Widget _buildCalendarView(Map<DateTime, List<QueryDocumentSnapshot>> events) {
    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            _showDayDetails(context, events[DateTime(selectedDay.year, selectedDay.month, selectedDay.day)] ?? []);
          },
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: StartingDayOfWeek.monday,
          
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false,
            titleTextStyle: GoogleFonts.domine(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
            leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.ink),
            rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.ink),
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: const BoxDecoration(color: Colors.transparent, shape: BoxShape.circle),
            todayTextStyle: GoogleFonts.lato(color: AppColors.sage, fontWeight: FontWeight.bold),
            selectedDecoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
            defaultTextStyle: GoogleFonts.lato(color: AppColors.ink),
            weekendTextStyle: GoogleFonts.lato(color: AppColors.stone),
            outsideDaysVisible: false,
          ),
          
          // --- DOT BUILDER ---
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, docList) {
              if (docList.isEmpty) return null;
              
              double total = 0;
              int count = 0;

              for (var d in docList) {
                if (d is DocumentSnapshot) {
                   final data = d.data() as Map<String, dynamic>?;
                   if (data != null) {
                      total += (data['mood_score'] ?? 5.0).toDouble();
                      count++;
                   }
                }
              }

              if (count == 0) return null;
              double avg = total / count;
              
              return Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6.0),
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: _getMoodColor(avg),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          eventLoader: (day) {
            return events[DateTime(day.year, day.month, day.day)] ?? [];
          },
        ),
        
        const Spacer(),
        Center(child: Text("Tap a date to recall.", style: GoogleFonts.lato(color: AppColors.stone.withOpacity(0.5)))),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- VIEW 2: LIST SCROLL ---
  Widget _buildListView(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return Center(child: Text("No stories yet.", style: GoogleFonts.domine(color: AppColors.stone)));
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        return _EntryCard(doc: docs[index]);
      },
    );
  }

  void _showDayDetails(BuildContext context, List<QueryDocumentSnapshot> dailyDocs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Allow full height for list
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: AppColors.paperBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.stone.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(
              _selectedDay != null ? DateFormat('MMMM d, y').format(_selectedDay!) : "Selected Day",
              style: GoogleFonts.domine(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink),
            ),
            const SizedBox(height: 20),
            if (dailyDocs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(child: Text("No entries for this day.", style: GoogleFonts.lato(color: AppColors.stone))),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: dailyDocs.length,
                  itemBuilder: (context, index) => _EntryCard(doc: dailyDocs[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleButton({required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.sage : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, size: 16, color: isActive ? Colors.white : AppColors.stone),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _EntryCard({required this.doc});

  // --- SHOW FULL MEMORY POPUP ---
  void _showFullMemory(BuildContext context, Map<String, dynamic> data) {
    DateTime date = (data['timestamp'] as Timestamp).toDate();
    double score = (data['mood_score'] ?? 5.0).toDouble();
    Color moodColor = score >= 8 ? AppColors.sage : (score >= 5 ? const Color(0xFFA8A593) : AppColors.clay);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Full screen capable
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
        decoration: const BoxDecoration(
          color: AppColors.paperBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.stone.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 30),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // DATE & LOCATION HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('EEEE').format(date).toUpperCase(), style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.stone)),
                            Text(DateFormat('MMMM d').format(date), style: GoogleFonts.domine(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.ink)),
                          ],
                        ),
                        // WEATHER BADGE
                        if (data['weather_context'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.stone.withOpacity(0.2))),
                            child: Row(
                              children: [
                                const Icon(FontAwesomeIcons.cloud, size: 12, color: AppColors.stone),
                                const SizedBox(width: 6),
                                Text(data['weather_context'] ?? "", style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    // CITY & TIME
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: AppColors.sage),
                        const SizedBox(width: 4),
                        Text(data['location_city'] ?? "Unknown Place", style: GoogleFonts.lato(color: AppColors.stone)),
                        const SizedBox(width: 10),
                        Text("•  ${DateFormat('h:mm a').format(date)}", style: GoogleFonts.lato(color: AppColors.stone)),
                      ],
                    ),

                    const SizedBox(height: 30),
                    const Divider(color: Color(0xFFEEEBE0)),
                    const SizedBox(height: 20),

                    // PROMPT (If exists)
                    if (data['prompt_used'] != null) ...[
                      Text("THINKING ABOUT", style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.sage)),
                      const SizedBox(height: 5),
                      Text(data['prompt_used'], style: GoogleFonts.domine(fontSize: 18, color: AppColors.ink)),
                      const SizedBox(height: 20),
                    ],

                    // TAGS
                    if (data['tags'] != null && (data['tags'] as List).isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        children: (data['tags'] as List).map<Widget>((tag) => Chip(
                          label: Text(tag, style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.ink)),
                          backgroundColor: AppColors.cardColor,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // MAIN CONTENT
                    Text(
                      data['content'] ?? "", 
                      style: GoogleFonts.lato(fontSize: 16, height: 1.8, color: AppColors.ink)
                    ),

                    const SizedBox(height: 30),

                    // SONG CARD (Detailed)
                    if (data['track_name'] != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.stone.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                             ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: data['image_url'] != null 
                                  ? Image.network(data['image_url'], width: 50, height: 50, fit: BoxFit.cover)
                                  : Container(width: 50, height: 50, color: AppColors.ink, child: const Icon(Icons.music_note, color: Colors.white)),
                              ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("SOUNDTRACK", style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.sage)),
                                  Text(data['track_name'], style: GoogleFonts.domine(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.ink), maxLines: 1),
                                  Text(data['artist'] ?? "", style: GoogleFonts.lato(color: AppColors.stone)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                final query = Uri.encodeComponent("${data['track_name']} ${data['artist']}");
                                final url = Uri.parse("https://open.spotify.com/search/$query"); 
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              },
                              icon: const Icon(FontAwesomeIcons.spotify, color: Color(0xFF1DB954), size: 30),
                            )
                          ],
                        ),
                      ),
                      
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEntry(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paperBackground,
        title: Text("Delete Memory?", style: GoogleFonts.domine(fontWeight: FontWeight.bold, color: AppColors.ink)),
        content: Text("This will permanently remove this journal entry.", style: GoogleFonts.lato(color: AppColors.stone)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("CANCEL", style: GoogleFonts.lato(color: AppColors.stone, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("DELETE", style: GoogleFonts.lato(color: AppColors.clay, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('entries')
          .doc(doc.id)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    var data = doc.data() as Map<String, dynamic>;
    DateTime date = (data['timestamp'] as Timestamp).toDate();
    double score = (data['mood_score'] ?? 5.0).toDouble();
    Color moodColor = score >= 8 ? AppColors.sage : (score >= 5 ? const Color(0xFFA8A593) : AppColors.clay);

    return GestureDetector(
      // --- HERE IS THE ON TAP ACTION ---
      onTap: () => _showFullMemory(context, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.stone.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: AppColors.stone.withOpacity(0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER ROW
              Row(
                children: [
                  Text(DateFormat('MMM d • h:mm a').format(date), style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.stone)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: moodColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text(data['mood_label'] ?? "Mood", style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, color: moodColor)),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => _deleteEntry(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.delete_outline, size: 22, color: AppColors.clay),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // CONTENT PREVIEW
              Text(data['content'] ?? "", maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 14, height: 1.5, color: AppColors.ink)),
              
              if (data['track_name'] != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFEEEBE0)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(FontAwesomeIcons.spotify, size: 14, color: Color(0xFF1DB954)),
                    const SizedBox(width: 8),
                    Expanded(child: Text("${data['track_name']} • ${data['artist']}", style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.stone), maxLines: 1)),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}