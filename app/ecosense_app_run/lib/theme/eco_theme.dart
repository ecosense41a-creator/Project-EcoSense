import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens from the EcoSense v3.2 prototype (light + dark).
@immutable
class EcoColors extends ThemeExtension<EcoColors> {
  const EcoColors({
    required this.bg1,
    required this.bg2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.surface,
    required this.solid,
    required this.border,
    required this.line,
    required this.chip,
    required this.accent,
    required this.accentDeep,
    required this.accentSoft,
    required this.greenInk,
    required this.onAccent,
    required this.button,
    required this.buttonFg,
    required this.amber,
    required this.amberSoft,
    required this.warnInk,
    required this.red,
    required this.redSoft,
    required this.slate,
    required this.shadow,
  });

  final Color bg1, bg2;
  final Color ink, ink2, ink3;
  final Color surface, solid, border, line, chip;
  final Color accent, accentDeep, accentSoft, greenInk, onAccent;
  final Color button, buttonFg;
  final Color amber, amberSoft, warnInk;
  final Color red, redSoft;
  final Color slate;
  final Color shadow;

  static const light = EcoColors(
    bg1: Color(0xFFF4F6F3),
    bg2: Color(0xFFD9EFE2),
    ink: Color(0xFF111111),
    ink2: Color(0xFF667068),
    ink3: Color(0xFFA2AAA4),
    surface: Color(0xBDFFFFFF), // rgba(255,255,255,.74)
    solid: Color(0xFFFFFFFF),
    border: Color(0xF2FFFFFF), // rgba(255,255,255,.95)
    line: Color(0xFFD3D9D3),
    chip: Color(0xFFEDF0EC),
    accent: Color(0xFF3DAE70),
    accentDeep: Color(0xFF1F7A4D),
    accentSoft: Color(0xFFDCF0E3),
    greenInk: Color(0xFF14532F),
    onAccent: Color(0xFFFFFFFF),
    button: Color(0xFF111111),
    buttonFg: Color(0xFFFFFFFF),
    amber: Color(0xFFD9962A),
    amberSoft: Color(0xFFFBEBC8),
    warnInk: Color(0xFF7A5410),
    red: Color(0xFFD6453D),
    redSoft: Color(0xFFFBE1DE),
    slate: Color(0xFF8A949E),
    shadow: Color(0x1A1E6441), // rgba(30,100,65,.10)
  );

  static const dark = EcoColors(
    bg1: Color(0xFF0D1310),
    bg2: Color(0xFF10281C),
    ink: Color(0xFFF1F4F1),
    ink2: Color(0xFFA3ACA5),
    ink3: Color(0xFF6F7871),
    surface: Color(0xB81E2A23), // rgba(30,42,35,.72)
    solid: Color(0xFF1E2923),
    border: Color(0x14FFFFFF), // rgba(255,255,255,.08)
    line: Color(0xFF34413A),
    chip: Color(0xFF25312A),
    accent: Color(0xFF4CD08A),
    accentDeep: Color(0xFF4CD08A),
    accentSoft: Color(0x294CD08A), // .16
    greenInk: Color(0xFFA8EBC9),
    onAccent: Color(0xFF0D1310),
    button: Color(0xFFF1F4F1),
    buttonFg: Color(0xFF0D1310),
    amber: Color(0xFFE7A93A),
    amberSoft: Color(0x2EE7A93A), // .18
    warnInk: Color(0xFFF0C877),
    red: Color(0xFFF0675F),
    redSoft: Color(0x2EF0675F),
    slate: Color(0xFF9AA5AE),
    shadow: Color(0x66000000),
  );

  @override
  EcoColors copyWith() => this;

  @override
  EcoColors lerp(ThemeExtension<EcoColors>? other, double t) {
    if (other is! EcoColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return EcoColors(
      bg1: l(bg1, other.bg1),
      bg2: l(bg2, other.bg2),
      ink: l(ink, other.ink),
      ink2: l(ink2, other.ink2),
      ink3: l(ink3, other.ink3),
      surface: l(surface, other.surface),
      solid: l(solid, other.solid),
      border: l(border, other.border),
      line: l(line, other.line),
      chip: l(chip, other.chip),
      accent: l(accent, other.accent),
      accentDeep: l(accentDeep, other.accentDeep),
      accentSoft: l(accentSoft, other.accentSoft),
      greenInk: l(greenInk, other.greenInk),
      onAccent: l(onAccent, other.onAccent),
      button: l(button, other.button),
      buttonFg: l(buttonFg, other.buttonFg),
      amber: l(amber, other.amber),
      amberSoft: l(amberSoft, other.amberSoft),
      warnInk: l(warnInk, other.warnInk),
      red: l(red, other.red),
      redSoft: l(redSoft, other.redSoft),
      slate: l(slate, other.slate),
      shadow: l(shadow, other.shadow),
    );
  }
}

extension EcoContext on BuildContext {
  EcoColors get eco => Theme.of(this).extension<EcoColors>()!;
}

/// Text styles from the prototype. Outfit, tight negative tracking on headings.
class EcoText {
  EcoText._();

  static TextStyle _o(double size, FontWeight w, Color c, {double ls = 0, double? h}) =>
      GoogleFonts.outfit(
        fontSize: size,
        fontWeight: w,
        color: c,
        letterSpacing: ls * size, // CSS em -> logical px
        height: h,
      );

  static TextStyle pageTitle(EcoColors e) => _o(32, FontWeight.w500, e.ink, ls: -0.05, h: 1.08);
  static TextStyle roomTitle(EcoColors e) => _o(30, FontWeight.w500, e.ink, ls: -0.05, h: 1.1);
  static TextStyle pageSub(EcoColors e) => _o(14, FontWeight.w400, e.ink2, h: 1.55);
  static TextStyle kicker(EcoColors e) => _o(11, FontWeight.w700, e.ink2, ls: 0.13);
  static TextStyle section(EcoColors e) => _o(19, FontWeight.w600, e.ink, ls: -0.03);
  static TextStyle cardTitle(EcoColors e) => _o(14, FontWeight.w600, e.ink);
  static TextStyle body(EcoColors e) => _o(13.5, FontWeight.w400, e.ink, h: 1.5);
  static TextStyle small(EcoColors e) => _o(14, FontWeight.w400, e.ink2, h: 1.46);
  static TextStyle tiny(EcoColors e) => _o(12, FontWeight.w400, e.ink2, h: 1.4);
  static TextStyle label(EcoColors e) => _o(11.5, FontWeight.w400, e.ink2);
  static TextStyle strong(EcoColors e, {double size = 13}) =>
      _o(size, FontWeight.w600, e.ink);
  static TextStyle bigNumber(EcoColors e, {double size = 27}) =>
      _o(size, FontWeight.w500, e.ink, ls: -0.055, h: 1.05);
  static TextStyle button(Color c) => _o(13, FontWeight.w600, c);
}

ThemeData buildEcoTheme(Brightness brightness) {
  final e = brightness == Brightness.dark ? EcoColors.dark : EcoColors.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: e.accent,
      brightness: brightness,
    ).copyWith(
      primary: e.accent,
      onPrimary: e.onAccent,
      surface: e.solid,
      onSurface: e.ink,
      error: e.red,
      outline: e.line,
    ),
    scaffoldBackgroundColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
      bodyColor: e.ink,
      displayColor: e.ink,
    ),
    extensions: <ThemeExtension<dynamic>>[e],
    splashFactory: InkRipple.splashFactory,
    dividerColor: e.line,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: e.button,
      contentTextStyle: GoogleFonts.outfit(fontSize: 12.5, color: e.buttonFg, height: 1.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: e.accent,
      inactiveTrackColor: e.line,
      thumbColor: e.accent,
      overlayColor: e.accent.withValues(alpha: 0.14),
      trackHeight: 5,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: e.solid,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
