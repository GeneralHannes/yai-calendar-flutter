import 'package:flutter/material.dart';

/// Colours in the style of Apple Calendar. Everything else in the UI reads
/// from here, so changing the look means changing these values. `gold` is the
/// tint (today, buttons, links), `act` the default calendar colour (events).
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

  // Apple Calendar: pure black / white pages, system grey text, red tint
  // (today, buttons) and calendar blue for events.
  static const dark = YaiPalette(
    brightness: Brightness.dark,
    bg1: Color(0xFF000000),
    bg2: Color(0xFF1C1C1E),
    ink: Color(0xFFFFFFFF),
    muted: Color(0xFF8E8E93),
    act: Color(0xFF0A84FF),
    bad: Color(0xFFFF453A),
    warn: Color(0xFFFF453A),
    gold: Color(0xFFFF453A),
  );

  static const light = YaiPalette(
    brightness: Brightness.light,
    bg1: Color(0xFFFFFFFF),
    bg2: Color(0xFFF2F2F7),
    ink: Color(0xFF000000),
    muted: Color(0xFF8E8E93),
    act: Color(0xFF007AFF),
    bad: Color(0xFFFF3B30),
    warn: Color(0xFFFF3B30),
    gold: Color(0xFFFF3B30),
  );

  /// App-wide typeface: the platform's own (San Francisco on Apple devices).
  static const String? fontFamily = null;

  static YaiPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  ThemeData toTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: brightness,
    ).copyWith(
      primary: gold,
      onPrimary: Colors.white,
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
