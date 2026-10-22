import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Memory Card's design tokens (docs/design/canvas). The rule is "inverse ink": on a light canvas the
/// surfaces are dark, on a dark canvas they are light.
@immutable
class Mc extends ThemeExtension<Mc> {
  const Mc({
    required this.dark,
    required this.canvas,
    required this.ink,
    required this.onInk,
    required this.muted,
    required this.mutedOnInk,
    required this.soft,
    required this.well,
    required this.line,
    required this.field,
    required this.dash,
    required this.track,
    required this.pill,
    required this.earBack,
    required this.knobOff,
    required this.offBg,
    required this.back1,
    required this.back2,
    required this.heroBack1,
    required this.heroBack2,
    required this.sash,
    required this.cardFace,
    required this.digits,
    required this.stripe,
    required this.badge,
    required this.badgeInk,
    required this.ink2,
    required this.gloss,
    required this.backdrop,
    required this.backdropInk,
    required this.backdropBar,
    required this.folderShadow,
    required this.e1,
    required this.e2,
    required this.e3,
    required this.sheet,
    required this.cardShadow,
    required this.faceShadow,
    required this.fanOn,
    required this.fanOff,
    required this.above,
    required this.below,
    required this.heat,
  });

  final bool dark;
  final Color canvas, ink, onInk, muted, mutedOnInk, soft, well, line, field, dash, track, pill, earBack;
  final Color knobOff, offBg, back1, back2, heroBack1, heroBack2, sash, cardFace, digits, stripe, badge, badgeInk;
  final Color ink2, gloss, backdrop, backdropInk, backdropBar;
  final double folderShadow;
  final List<BoxShadow> e1, e2, e3, sheet, cardShadow, faceShadow;

  /// The deck-row fan: filled steps (progress) and empty steps.
  final List<Color> fanOn;
  final Color fanOff;

  /// Study stack layers: above the card (gradient strips) and below it (flat).
  final List<List<Color>> above;
  final List<Color> below;

  /// Heatmap, none → big day.
  final List<Color> heat;

  Color get canvasClear => canvas.withValues(alpha: 0);

  static const blue = Color(0xFF80AEFF);
  static const peach = Color(0xFFFFC680);
  static const red = Color(0xFFD35F5F);
  static const delete = Color(0xFFFF8080);
  static const green = Color(0xFF8BD3A0);
  static const tier = Color(0xFFD9A273);
  static const paper = Color(0xFFF1F1F1);
  static const graphite = Color(0xFF333333);

  static List<BoxShadow> _s(List<(double y, double blur, double a)> xs) =>
      [for (final (y, b, a) in xs) BoxShadow(color: Color.fromRGBO(0, 0, 0, a), offset: Offset(0, y), blurRadius: b)];

  static final light = Mc(
    dark: false,
    canvas: const Color(0xFFF1F1F1),
    ink: const Color(0xFF333333),
    onInk: const Color(0xFFF1F1F1),
    muted: const Color(0xFF666666),
    mutedOnInk: const Color(0xFFBDBDBD),
    soft: const Color(0xFFE3E3E3),
    well: const Color(0xFFD6D6D6),
    line: const Color(0xFFD2D2D2),
    field: const Color(0xFFFFFFFF),
    dash: const Color(0xFF9D9D9D),
    track: const Color(0xFFCFCFCF),
    pill: const Color(0xFFE3E3E3),
    earBack: const Color(0xFF5C5C5C),
    knobOff: const Color(0xFFFFFFFF),
    offBg: const Color(0xFFBDBDBD),
    back1: const Color(0xFF9D9D9D),
    back2: const Color(0xFFC4C4C4),
    heroBack1: const Color(0xFF747474),
    heroBack2: const Color(0xFF5A5A5A),
    sash: const Color(0xFFAEAEAE),
    cardFace: const Color(0xFFF8F8F8),
    digits: const Color(0xFF9A9A9A),
    stripe: const Color(0xFF1E1E1E),
    badge: const Color(0xFF333333),
    badgeInk: const Color(0xFFF1F1F1),
    ink2: const Color(0xFF555555),
    gloss: const Color.fromRGBO(255, 255, 255, 0.16),
    backdrop: const Color(0xFF9D9D9D),
    backdropInk: const Color(0xFF5E5E5E),
    backdropBar: const Color(0xFF7E7E7E),
    folderShadow: 0.32,
    e1: _s([(1, 2, 0.12), (5, 12, 0.12)]),
    e2: _s([(2, 4, 0.12), (10, 24, 0.2)]),
    e3: _s([(24, 60, 0.35)]),
    sheet: _s([(-10, 30, 0.22)]),
    cardShadow: _s([(2, 4, 0.12), (8, 18, 0.14)]),
    faceShadow: _s([(18, 40, 0.10)]),
    fanOn: const [Color(0xFF8F8F8F), Color(0xFFA8A8A8), Color(0xFFC2C2C2), Color(0xFFDADADA), Color(0xFFF1F1F1)],
    fanOff: const Color(0xFF454545),
    above: const [
      [Color(0xFFC7C7C7), Color(0xFFBCBCBC)],
      [Color(0xFFD6D6D6), Color(0xFFCDCDCD)],
      [Color(0xFFE4E4E4), Color(0xFFDEDEDE)],
      [Color(0xFFEFEFEF), Color(0xFFE9E9E9)],
    ],
    below: const [Color(0xFF666666), Color(0xFF4E4E4E), Color(0xFF3D3D3D)],
    heat: const [Color(0xFF474747), Color(0xFF666666), Color(0xFF8A8A8A), Color(0xFFBDBDBD), Color(0xFFF1F1F1)],
  );

  // Dark: a near-black canvas (#151515, hsl 0 0 % 8 %) with surfaces stepped up from it, and soft shadows:
  // wide, low-contrast, never a hard band.
  static final darkTheme = Mc(
    dark: true,
    canvas: const Color(0xFF151515),
    ink: const Color(0xFFF1F1F1),
    onInk: const Color(0xFF151515),
    muted: const Color(0xFFA8A8A8),
    mutedOnInk: const Color(0xFF6A6A6A),
    soft: const Color(0xFF262626),
    well: const Color(0xFF333333),
    line: const Color(0xFF333333),
    field: const Color(0xFF1E1E1E),
    dash: const Color(0xFF5E5E5E),
    track: const Color(0xFF383838),
    pill: const Color(0xFFD6D6D6),
    earBack: const Color(0xFFCFCFCF),
    knobOff: const Color(0xFFBDBDBD),
    offBg: const Color(0xFF444444),
    back1: const Color(0xFF7A7A7A),
    back2: const Color(0xFF4E4E4E),
    heroBack1: const Color(0xFFBDBDBD),
    heroBack2: const Color(0xFF9D9D9D),
    sash: const Color(0xFF6E6E6E),
    cardFace: const Color(0xFF262626),
    digits: const Color(0xFF8A8A8A),
    stripe: const Color(0xFFC8C8C8),
    badge: const Color(0xFFF1F1F1),
    badgeInk: const Color(0xFF151515),
    ink2: const Color(0xFFC4C4C4),
    gloss: const Color.fromRGBO(255, 255, 255, 0.7),
    backdrop: const Color(0xFF2C2C2C),
    backdropInk: const Color(0xFF6E6E6E),
    backdropBar: const Color(0xFF3C3C3C),
    folderShadow: 0.34,
    e1: _s([(1, 4, 0.20), (6, 18, 0.22)]),
    e2: _s([(2, 8, 0.24), (14, 34, 0.30)]),
    e3: _s([(18, 56, 0.40)]),
    sheet: _s([(-8, 36, 0.38)]),
    cardShadow: _s([(3, 10, 0.26), (12, 32, 0.30)]),
    faceShadow: _s([(16, 44, 0.30)]),
    fanOn: const [Color(0xFFA3A3A3), Color(0xFF888888), Color(0xFF6E6E6E), Color(0xFF525252), Color(0xFF333333)],
    fanOff: const Color(0xFFDADADA),
    above: const [
      [Color(0xFF4C4C4C), Color(0xFF5A5A5A)],
      [Color(0xFF383838), Color(0xFF434343)],
      [Color(0xFF282828), Color(0xFF303030)],
      [Color(0xFF1C1C1C), Color(0xFF222222)],
    ],
    below: const [Color(0xFFD9D9D9), Color(0xFFBDBDBD), Color(0xFFA5A5A5)],
    heat: const [Color(0xFFDADADA), Color(0xFFBDBDBD), Color(0xFF8A8A8A), Color(0xFF5E5E5E), Color(0xFF333333)],
  );

  static Mc of(BuildContext context) => Theme.of(context).extension<Mc>()!;

  @override
  Mc copyWith() => this;

  @override
  Mc lerp(ThemeExtension<Mc>? other, double t) => t < 0.5 ? this : (other as Mc? ?? this);

  static ThemeData theme(Mc mc) {
    final base = ThemeData(
      brightness: mc.dark ? Brightness.dark : Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: mc.canvas,
      canvasColor: mc.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: mc.ink,
        brightness: mc.dark ? Brightness.dark : Brightness.light,
        surface: mc.canvas,
        primary: mc.ink,
        onPrimary: mc.onInk,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: mc.ink,
        selectionColor: mc.ink.withValues(alpha: 0.25),
        selectionHandleColor: mc.ink,
      ),
    );
    return base.copyWith(
      extensions: [mc],
      textTheme: (T.googleFonts
              ? GoogleFonts.barlowSemiCondensedTextTheme(base.textTheme)
              : base.textTheme.apply(fontFamily: T.testFamily))
          .apply(bodyColor: mc.ink, displayColor: mc.ink),
    );
  }
}

/// Typography: Bernard MT Condensed for display, Barlow Semi Condensed for text.
class T {
  const T._();

  static const displayFamily = 'Bernard';

  /// Off in widget tests (no network there); the app always uses Google Fonts.
  static bool googleFonts = true;

  /// Widget tests only: font families to use while [googleFonts] is off (null = the test font).
  static String? testFamily;
  static String? testMono;

  /// Bernard has no middle dot (every deck name has one: "Spanish · Basics"), no euro sign and no
  /// non-Latin letters; those come from Barlow instead of whatever the phone falls back to.
  static List<String>? get _displayFallback {
    if (!googleFonts) return testFamily == null ? null : [testFamily!];
    return _barlowFallback ??= [GoogleFonts.barlowSemiCondensed(fontWeight: FontWeight.w700).fontFamily!];
  }

  static List<String>? _barlowFallback;

  static TextStyle d(double size, {Color? color, double height = 1.0, double spacing = 0}) => TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: _displayFallback,
        fontSize: size,
        height: height,
        color: color,
        letterSpacing: spacing,
        fontWeight: FontWeight.normal,
        leadingDistribution: TextLeadingDistribution.even,
      );

  static TextStyle t(double size, {FontWeight w = FontWeight.w500, Color? color, double? height, double? spacing}) =>
      !googleFonts
          ? TextStyle(fontFamily: testFamily, fontSize: size, fontWeight: w, color: color, height: height, letterSpacing: spacing)
          : GoogleFonts.barlowSemiCondensed(
        fontSize: size,
        fontWeight: w,
        color: color,
        height: height,
        letterSpacing: spacing,
      );

  /// Small uppercase labels ("NOUN · NEUTER", section headers).
  static TextStyle caps(double size, {Color? color, double spacing = 1.2}) =>
      t(size, w: FontWeight.w700, color: color, spacing: spacing);

  static TextStyle mono(double size, {Color? color, double height = 1.15, FontWeight w = FontWeight.w600}) =>
      !googleFonts
          ? TextStyle(fontSize: size, color: color, height: height, fontWeight: w, fontFamily: testMono ?? 'monospace')
          : GoogleFonts.jetBrainsMono(fontSize: size, color: color, height: height, fontWeight: w);

  /// Fonts that must be ready before the first frame (no visible swap on launch).
  static List<TextStyle> preload() => [
        for (final w in const [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700])
          GoogleFonts.barlowSemiCondensed(fontWeight: w),
        GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w600),
      ];
}
