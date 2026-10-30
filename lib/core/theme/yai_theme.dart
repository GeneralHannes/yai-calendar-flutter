import 'package:flutter/material.dart';

/// Colours from the Odin Journal design (Tokyo-Night moon for dark, its light
/// counterpart for light, gold as the signature accent). Everything else in
/// the UI reads from here, so changing the look means changing these values.
@immutable
class YaiPalette {
  const YaiPalette({
    required this.brightness,
    required this.bg1,
    required this.bg2,
    required this.ink,
    required this.muted,
    required this.act,
    required this.bad,
    required this.warn,
    required this.gold,
  });

  final Brightness brightness;

  /// Page background and the raised surface on top of it.
  final Color bg1, bg2;

  /// Primary and secondary text.
  final Color ink, muted;

  /// Accent (selection, chips), destructive, orange, and the journal's gold
  /// (today, titles, section labels).
  final Color act, bad, warn, gold;

  static const dark = YaiPalette(
    brightness: Brightness.dark,
    bg1: Color(0xFF1E2030),
    bg2: Color(0xFF222436),
    ink: Color(0xFFC8D3F5),
    muted: Color(0xFF828BB8),
    act: Color(0xFF82AAFF),
    bad: Color(0xFFFF757F),
    warn: Color(0xFFFF966C),
    gold: Color(0xFFD4AF37),
  );

  static const light = YaiPalette(
    brightness: Brightness.light,
    bg1: Color(0xFFE1E2E7),
    bg2: Color(0xFFF1F2F7),
    ink: Color(0xFF343B58),
    muted: Color(0xFF5F6A9C),
    act: Color(0xFF2E7DE9),
    bad: Color(0xFFD1243F),
    warn: Color(0xFFB45309),
    gold: Color(0xFF9A7608),
  );

  /// The journal's `--bifrost` hairline: gold to violet.
  static const bifrost = [
    Color(0xFFD4AF37),
    Color(0xFFD98A3C),
    Color(0xFF8FA6BF),
    Color(0xFF8B7BC4),
    Color(0xFF5A6FC0),
  ];

  /// App-wide typeface: Libron, bundled in assets/fonts.
  static const fontFamily = 'Libron';

  static YaiPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  ThemeData toTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: act,
      brightness: brightness,
    ).copyWith(
      primary: act,
      onPrimary: brightness == Brightness.dark
          ? const Color(0xFF10121F)
          : Colors.white,
      surface: bg2,
      onSurface: ink,
      error: bad,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg1,
      appBarTheme: AppBarTheme(
        backgroundColor: bg1,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
      ),
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
            bodyColor: ink,
            displayColor: ink,
          ),
    );
  }
}
