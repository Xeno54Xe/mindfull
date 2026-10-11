import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:avatar_glow/avatar_glow.dart';
import '../theme/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS & DATA CLASSES
// ─────────────────────────────────────────────────────────────────────────────

enum _Phase { input, loading, response, burning, breathing }

class _BreathStep {
  final String label;
  final String sub;
  final int seconds;
  /// true = expand circle, false = contract, null = hold steady
  final bool? expanding;
  const _BreathStep(this.label, this.sub, this.seconds, this.expanding);
}

// ─────────────────────────────────────────────────────────────────────────────
// FIXED DARK PALETTE  (vent screen is always dark, ignores system theme)
// ─────────────────────────────────────────────────────────────────────────────
const Color _bg      = Color(0xFF16120D); // deep warm espresso
const Color _surface = Color(0xFF201A12); // aged leather
const Color _border  = Color(0xFF3D3020); // warm mahogany edge
const Color _ink     = Color(0xFFEDE0C8); // warm ivory
const Color _muted   = Color(0xFF8A7560); // warm taupe
const Color _dimmed  = Color(0xFF4A3E30); // dark mahogany

// ─────────────────────────────────────────────────────────────────────────────
// VENT SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class VentScreen extends StatefulWidget {
  const VentScreen({super.key});

  @override
  State<VentScreen> createState() => _VentScreenState();
}

class _VentScreenState extends State<VentScreen> with TickerProviderStateMixin {
  // ── backend ────────────────────────────────────────────────────────────────
  String get _backendUrl {
    const String live = "https://mindfull-backend-15b6.onrender.com";
    if (kIsWeb) return live;
    return live;
  }

  // ── phase ──────────────────────────────────────────────────────────────────
  _Phase _phase = _Phase.input;

  // ── input ──────────────────────────────────────────────────────────────────
  final TextEditingController _ventController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;

  // ── AI result ──────────────────────────────────────────────────────────────
  String _aiResponse = '';
  String _releasePhrase = '';
  String _breathingTechnique = 'box';
  bool _saved = false;

  // ── breathing ──────────────────────────────────────────────────────────────
  late AnimationController _breathController;
  late AnimationController _pulseController;
  Timer? _breathTimer;
  List<_BreathStep> _breathSteps = [];
  int _stepIndex = 0;
  int _stepSeconds = 0;
  int _cycleCount = 0;
  static const int _totalCycles = 4;

  // ── fallback response ──────────────────────────────────────────────────────
  static const String _fallback =
      "What you're carrying right now is real, and your feelings make complete sense. "
      "You didn't deserve any of it — and the fact that you're letting yourself feel this "
      "is already an act of courage. You are not alone in this, not for a single moment.";

  // ───────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ───────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ventController.dispose();
    _focusNode.dispose();
    _breathController.dispose();
    _pulseController.dispose();
    _breathTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SPEECH TOGGLE
  // ───────────────────────────────────────────────────────────────────────────

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      if (!_speechAvailable) return;
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _ventController.text = result.recognizedWords;
            _ventController.selection = TextSelection.fromPosition(
              TextPosition(offset: _ventController.text.length),
            );
          });
        },
        listenFor: const Duration(seconds: 120),
        pauseFor: const Duration(seconds: 6),
        localeId: 'en_US',
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SUBMIT VENT
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _submitVent() async {
    final text = _ventController.text.trim();
    if (text.isEmpty) return;
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }
    _focusNode.unfocus();
    setState(() => _phase = _Phase.loading);

    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/vent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _aiResponse       = (data['response']             as String?) ?? _fallback;
          _releasePhrase    = (data['release_phrase']        as String?) ?? 'You\'ve been heard.';
          _breathingTechnique = (data['breathing_technique'] as String?) ?? 'box';
          _phase = _Phase.response;
        });
      } else {
        _useResponseFallback();
      }
    } catch (_) {
      if (mounted) _useResponseFallback();
    }
  }

  void _useResponseFallback() {
    setState(() {
      _aiResponse         = _fallback;
      _releasePhrase      = 'You\'ve been heard.';
      _breathingTechnique = 'box';
      _phase              = _Phase.response;
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BURN
  // ───────────────────────────────────────────────────────────────────────────

  void _burnVent() {
    setState(() => _phase = _Phase.burning);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() {
        _ventController.clear();
        _aiResponse     = '';
        _releasePhrase  = '';
        _saved          = false;
        _phase          = _Phase.input;
      });
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SAVE TO JOURNAL
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _saveToJournal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journal')
          .add({
        'content':     _ventController.text.trim(),
        'mood':        'Venting',
        'score':       3,
        'timestamp':   FieldValue.serverTimestamp(),
        'is_vent':     true,
        'ai_response': _aiResponse,
        'tags':        ['Vent'],
      });
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      debugPrint('Save vent error: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BREATHING SETUP
  // ───────────────────────────────────────────────────────────────────────────

  void _startBreathing() {
    switch (_breathingTechnique) {
      case '4-7-8':
        _breathSteps = const [
          _BreathStep('Inhale',  'through your nose',   4, true),
          _BreathStep('Hold',    'gently',              7, null),
          _BreathStep('Exhale',  'through your mouth',  8, false),
          _BreathStep('Rest',    '',                    1, null),
        ];
        break;
      case 'belly':
        _breathSteps = const [
          _BreathStep('Inhale',  'into your belly',     4, true),
          _BreathStep('Hold',    'feel the fullness',   2, null),
          _BreathStep('Exhale',  'slow and easy',       6, false),
          _BreathStep('Rest',    '',                    1, null),
        ];
        break;
      default: // box
        _breathSteps = const [
          _BreathStep('Inhale',  'breathe in slowly',   4, true),
          _BreathStep('Hold',    'gentle pause',        4, null),
          _BreathStep('Exhale',  'breathe out slowly',  4, false),
          _BreathStep('Hold',    'rest',                4, null),
        ];
    }

    _stepIndex  = 0;
    _cycleCount = 0;
    _breathController.value = 0.0;
    setState(() => _phase = _Phase.breathing);
    _runBreathStep(0);
  }

  void _runBreathStep(int index) {
    if (!mounted) return;
    final step = _breathSteps[index];
    setState(() {
      _stepIndex  = index;
      _stepSeconds = step.seconds;
    });

    // Drive circle animation
    _breathController.duration = Duration(seconds: step.seconds);
    if (step.expanding == true)  _breathController.forward(from: 0.0);
    if (step.expanding == false) _breathController.reverse(from: 1.0);
    // null = hold → controller stays at current value

    // Countdown
    _breathTimer?.cancel();
    int elapsed = 0;
    _breathTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      elapsed++;
      if (!mounted) { t.cancel(); return; }
      setState(() => _stepSeconds = step.seconds - elapsed);

      if (elapsed >= step.seconds) {
        t.cancel();
        final nextIndex = (index + 1) % _breathSteps.length;
        if (nextIndex == 0) {
          _cycleCount++;
          if (_cycleCount >= _totalCycles) {
            _breathController.stop();
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              setState(() {
                _ventController.clear();
                _aiResponse    = '';
                _saved         = false;
                _phase         = _Phase.input;
              });
            });
            return;
          }
        }
        _runBreathStep(nextIndex);
      }
    });
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Color get _breathCircleColor {
    if (_stepIndex < _breathSteps.length) {
      final exp = _breathSteps[_stepIndex].expanding;
      if (exp == true)  return AppColors.sage.withValues(alpha: 0.7);
      if (exp == false) return AppColors.clay.withValues(alpha: 0.55);
    }
    return Colors.white.withValues(alpha: 0.25);
  }

  String get _techniqueName {
    switch (_breathingTechnique) {
      case '4-7-8':  return '4-7-8 Breathing';
      case 'belly':  return 'Belly Breathing';
      default:       return 'Box Breathing';
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BUILD
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        child: _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.input:     return _buildInputPhase();
      case _Phase.loading:   return _buildLoadingPhase();
      case _Phase.response:  return _buildResponsePhase();
      case _Phase.burning:   return _buildBurningPhase();
      case _Phase.breathing: return _buildBreathingPhase();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 1 — INPUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInputPhase() {
    final charCount = _ventController.text.length;
    final canSubmit  = charCount > 3;

    return SafeArea(
      key: const ValueKey('input'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                _backBtn(() => Navigator.pop(context)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "VENT MODE",
                      style: GoogleFonts.lato(
                        fontSize: 10,
                        letterSpacing: 2.2,
                        fontWeight: FontWeight.bold,
                        color: AppColors.clay.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      "This is your safe space.",
                      style: GoogleFonts.domine(
                        fontSize: 15,
                        color: _ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // ── title ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Say everything.",
              style: GoogleFonts.domine(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: _ink,
                height: 1.2,
              ),
            ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.08, end: 0),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 5, 24, 0),
            child: Text(
              "No judgement. No analysis. Just you.",
              style: GoogleFonts.lato(fontSize: 13, color: _muted),
            ).animate().fadeIn(duration: 800.ms, delay: 80.ms),
          ),

          const SizedBox(height: 18),

          // ── text field ────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _border),
                ),
                child: TextField(
                  controller: _ventController,
                  focusNode: _focusNode,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: GoogleFonts.domine(
                    fontSize: 17,
                    color: _ink,
                    height: 1.65,
                  ),
                  cursorColor: AppColors.clay,
                  decoration: InputDecoration(
                    hintText: "Let it all out...",
                    hintStyle: GoogleFonts.domine(
                      fontSize: 17,
                      color: _dimmed,
                      height: 1.65,
                    ),
                    contentPadding: const EdgeInsets.all(20),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 140.ms),
            ),
          ),

          const SizedBox(height: 14),

          // ── bottom action bar ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              children: [

                // mic
                if (_speechAvailable)
                  AvatarGlow(
                    animate: _isListening,
                    glowColor: AppColors.clay,
                    glowRadiusFactor: 0.28,
                    child: GestureDetector(
                      onTap: _toggleListening,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _isListening
                              ? AppColors.clay.withValues(alpha: 0.18)
                              : _surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isListening ? AppColors.clay : _border,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          _isListening
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: _isListening ? AppColors.clay : _muted,
                          size: 22,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 52),

                const SizedBox(width: 12),

                // char count
                Expanded(
                  child: Text(
                    charCount > 0 ? "$charCount characters" : "Start writing...",
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: charCount > 0 ? _muted : _dimmed,
                    ),
                  ),
                ),

                // submit
                GestureDetector(
                  onTap: canSubmit ? _submitVent : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: canSubmit ? AppColors.clay : _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: canSubmit
                            ? AppColors.clay
                            : _border,
                      ),
                      boxShadow: canSubmit
                          ? [BoxShadow(
                              color: AppColors.clay.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )]
                          : [],
                    ),
                    child: Text(
                      "LET IT OUT",
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.3,
                        color: canSubmit ? Colors.white : _dimmed,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 2 — LOADING
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLoadingPhase() {
    return Center(
      key: const ValueKey('loading'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ripple rings
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = 0; i < 3; i++)
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      final offset = i / 3.0;
                      final t = (_pulseController.value + offset) % 1.0;
                      final size = 60.0 + t * 120.0;
                      return Opacity(
                        opacity: (1 - t) * 0.55,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.clay.withValues(
                                  alpha: (1 - t) * 0.7),
                              width: 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                // Heart icon
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.clay.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.clay.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.clay,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          Text(
            "I'm here with you.",
            style: GoogleFonts.domine(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ).animate().fadeIn(duration: 700.ms),

          const SizedBox(height: 8),

          Text(
            "Taking this in...",
            style: GoogleFonts.lato(fontSize: 14, color: _muted),
          ).animate().fadeIn(duration: 700.ms, delay: 280.ms),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 3 — RESPONSE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildResponsePhase() {
    return SafeArea(
      key: const ValueKey('response'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── header ──────────────────────────────────────────────────────
            Row(
              children: [
                _backBtn(() => setState(() => _phase = _Phase.input)),
                const SizedBox(width: 14),
                Text(
                  "VENT MODE",
                  style: GoogleFonts.lato(
                    fontSize: 10,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.bold,
                    color: AppColors.clay.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 36),

            // ── release phrase ───────────────────────────────────────────────
            Text(
              _releasePhrase,
              style: GoogleFonts.domine(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _ink,
                height: 1.25,
              ),
            )
                .animate()
                .fadeIn(duration: 700.ms)
                .slideY(begin: 0.18, end: 0),

            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.clay.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ).animate().fadeIn(delay: 300.ms).scaleX(begin: 0, end: 1,
                alignment: Alignment.centerLeft),

            const SizedBox(height: 30),

            // ── empathy card ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.clay.withValues(alpha: 0.22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.clay.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.clay.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.clay,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "FROM MINDFULL",
                        style: GoogleFonts.lato(
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.clay.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _aiResponse,
                    style: GoogleFonts.domine(
                      fontSize: 16,
                      color: _ink,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 700.ms, delay: 180.ms)
                .slideY(begin: 0.12, end: 0),

            const SizedBox(height: 30),

            // ── action label ─────────────────────────────────────────────────
            Text(
              "WHAT WOULD YOU LIKE TO DO?",
              style: GoogleFonts.lato(
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
                color: _muted,
              ),
            ).animate().fadeIn(delay: 380.ms),

            const SizedBox(height: 14),

            // ── burn / keep ──────────────────────────────────────────────────
            Row(
              children: [
                // 🔥 Release it
                Expanded(
                  child: GestureDetector(
                    onTap: _burnVent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: AppColors.clay.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.clay.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text("🔥",
                              style: TextStyle(fontSize: 28)),
                          const SizedBox(height: 9),
                          Text(
                            "RELEASE IT",
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppColors.clay,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Burn & let go",
                            style: GoogleFonts.lato(
                                fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // 📖 Keep it
                Expanded(
                  child: GestureDetector(
                    onTap: _saved ? null : _saveToJournal,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: _saved
                            ? AppColors.sage.withValues(alpha: 0.18)
                            : AppColors.sage.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _saved
                              ? AppColors.sage.withValues(alpha: 0.6)
                              : AppColors.sage.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _saved ? "✅" : "📖",
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            _saved ? "SAVED" : "KEEP IT",
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppColors.sage,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _saved ? "In your journal" : "Save to journal",
                            style: GoogleFonts.lato(
                                fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 500.ms, delay: 450.ms),

            const SizedBox(height: 24),

            // ── breathing CTA ────────────────────────────────────────────────
            GestureDetector(
              onTap: _startBreathing,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.sage.withValues(alpha: 0.12),
                      _border.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.sage.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.sage.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const FaIcon(
                        FontAwesomeIcons.wind,
                        size: 17,
                        color: AppColors.sage,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Let's breathe together",
                            style: GoogleFonts.domine(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _ink,
                            ),
                          ),
                          Text(
                            "$_techniqueName  ·  $_totalCycles rounds",
                            style: GoogleFonts.lato(
                                fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: _muted, size: 14),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 560.ms),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 4 — BURNING
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBurningPhase() {
    return Center(
      key: const ValueKey('burning'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("🔥", style: TextStyle(fontSize: 90))
              .animate()
              .scale(
                begin: const Offset(0.3, 0.3),
                end: const Offset(1.3, 1.3),
                duration: 550.ms,
                curve: Curves.elasticOut,
              )
              .then(delay: 200.ms)
              .fadeOut(duration: 500.ms),

          const SizedBox(height: 28),

          Text(
            "Released.",
            style: GoogleFonts.domine(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          )
              .animate()
              .fadeIn(duration: 350.ms, delay: 280.ms)
              .then(delay: 600.ms)
              .fadeOut(duration: 400.ms),

          const SizedBox(height: 12),

          Text(
            "It no longer holds you.",
            style: GoogleFonts.lato(fontSize: 14, color: _muted),
          )
              .animate()
              .fadeIn(duration: 350.ms, delay: 450.ms)
              .then(delay: 500.ms)
              .fadeOut(duration: 400.ms),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 5 — BREATHING
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBreathingPhase() {
    final currentStep =
        (_stepIndex < _breathSteps.length) ? _breathSteps[_stepIndex] : null;

    return SafeArea(
      key: const ValueKey('breathing'),
      child: Column(
        children: [

          // ── header ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                _backBtn(() {
                  _breathTimer?.cancel();
                  _breathController.stop();
                  setState(() => _phase = _Phase.response);
                }, icon: Icons.close_rounded),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _techniqueName.toUpperCase(),
                      style: GoogleFonts.lato(
                        fontSize: 10,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sage.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      "Round ${_cycleCount + 1} of $_totalCycles",
                      style: GoogleFonts.domine(
                          fontSize: 14, color: _ink),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── breathing circle ───────────────────────────────────────────────
          AnimatedBuilder(
            animation: _breathController,
            builder: (context, _) {
              final scale       = 0.35 + _breathController.value * 0.65;
              const baseSize    = 230.0;
              final circleSize  = baseSize * scale;
              final glowSize    = circleSize + 44;
              final circleColor = _breathCircleColor;

              return Stack(
                alignment: Alignment.center,
                children: [
                  // outer glow
                  Container(
                    width: glowSize,
                    height: glowSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: circleColor.withValues(alpha: 0.18),
                        width: 1,
                      ),
                    ),
                  ),
                  // middle ring
                  Container(
                    width: circleSize + 20,
                    height: circleSize + 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: circleColor.withValues(alpha: 0.30),
                        width: 1,
                      ),
                    ),
                  ),
                  // main circle
                  Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          circleColor.withValues(alpha: 0.45),
                          circleColor.withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border.all(
                        color: circleColor.withValues(alpha: 0.65),
                        width: 1.5,
                      ),
                    ),
                  ),
                  // label inside
                  if (currentStep != null)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentStep.label,
                          style: GoogleFonts.domine(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _ink,
                          ),
                        ),
                        Text(
                          "$_stepSeconds",
                          style: GoogleFonts.lato(
                            fontSize: 20,
                            color: _muted,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          // ── step subtitle ──────────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: currentStep != null && currentStep.sub.isNotEmpty
                ? Text(
                    key: ValueKey(currentStep.sub),
                    currentStep.sub,
                    style: GoogleFonts.lato(
                        fontSize: 15, color: _muted),
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),

          const Spacer(),

          // ── step progress pills ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_breathSteps.length, (i) {
              final active = i == _stepIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active ? AppColors.sage : _dimmed,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          const SizedBox(height: 32),

          // ── cycle dots ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalCycles, (i) {
              final done = i < _cycleCount;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? AppColors.sage.withValues(alpha: 0.7)
                      : _dimmed,
                  border: Border.all(
                    color: done
                        ? AppColors.sage
                        : _dimmed,
                    width: 1,
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 24),

          // ── finish early ───────────────────────────────────────────────────
          GestureDetector(
            onTap: () {
              _breathTimer?.cancel();
              _breathController.stop();
              setState(() {
                _ventController.clear();
                _aiResponse = '';
                _saved      = false;
                _phase      = _Phase.input;
              });
            },
            child: Text(
              "FINISH EARLY",
              style: GoogleFonts.lato(
                fontSize: 12,
                letterSpacing: 1.5,
                color: _dimmed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 28),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED WIDGET HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _backBtn(VoidCallback onTap, {IconData icon = Icons.arrow_back_ios_new_rounded}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Icon(icon, color: _muted, size: 16),
      ),
    );
  }
}
