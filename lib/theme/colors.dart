import 'package:flutter/material.dart';

// ===========================================================================
// STATIC CONSTANTS — colors that never change between light/dark
// ===========================================================================
class AppColors {
  /// Sage green — primary accent (buttons, icons, highlights)
  static const Color sage = Color(0xFF81B29A);

  /// Clay / terracotta — warnings, errors, destructive actions
  static const Color clay = Color(0xFFE07A5F);

  // Legacy constants kept for backward-compat; prefer context.colors.xxx
  static const Color paperBackground = Color(0xFFF5F0E6);
  static const Color cardColor       = Color(0xFFFFFDF7);
  static const Color ink             = Color(0xFF3E2723);
  static const Color stone           = Color(0xFF8D7F71);
}

// ===========================================================================
// THEME EXTENSION — the 4 colors that flip between light and dark
// ===========================================================================
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color background;
  final Color card;
  final Color ink;
  final Color stone;

  const AppThemeColors({
    required this.background,
    required this.card,
    required this.ink,
    required this.stone,
  });

  // ── LIGHT ("Matcha & Parchment") ─────────────────────────────────────────
  static const light = AppThemeColors(
    background: Color(0xFFF5F0E6), // warm parchment beige
    card:       Color(0xFFFFFDF7), // warm cream
    ink:        Color(0xFF3E2723), // deep espresso brown
    stone:      Color(0xFF8D7F71), // muted taupe
  );

  // ── DARK ("Candlelit Journal") ────────────────────────────────────────────
  static const dark = AppThemeColors(
    background: Color(0xFF1A1410), // deepest warm espresso
    card:       Color(0xFF252018), // aged leather
    ink:        Color(0xFFF0EAD6), // warm ivory
    stone:      Color(0xFFA89880), // warm tan
  );

  @override
  AppThemeColors copyWith({Color? background, Color? card, Color? ink, Color? stone}) =>
      AppThemeColors(
        background: background ?? this.background,
        card:       card       ?? this.card,
        ink:        ink        ?? this.ink,
        stone:      stone      ?? this.stone,
      );

  @override
  AppThemeColors lerp(AppThemeColors? other, double t) {
    if (other == null) return this;
    return AppThemeColors(
      background: Color.lerp(background, other.background, t)!,
      card:       Color.lerp(card,       other.card,       t)!,
      ink:        Color.lerp(ink,        other.ink,        t)!,
      stone:      Color.lerp(stone,      other.stone,      t)!,
    );
  }
}

// ===========================================================================
// SHORTHAND — context.colors.ink  instead of
//             Theme.of(context).extension<AppThemeColors>()!.ink
// ===========================================================================
extension AppThemeColorsX on BuildContext {
  AppThemeColors get colors => Theme.of(this).extension<AppThemeColors>()!;
}
