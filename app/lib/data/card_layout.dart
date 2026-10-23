// How one side of a card is laid out: text and pictures placed on the face. Plain data (no Flutter
// imports) so it round-trips through JSON, lives in Hive with the card and is easy to test.
//
// Positions are fractions of the card face (0…1), so a layout looks the same on every phone and in the
// editor's preview. Text sizes are in pixels on a 276-wide face and scale with the face.

import 'dart:math' as math;

double _d(Object? v, double d) => (v as num?)?.toDouble() ?? d;
String _s(Object? v, String d) => (v as String?) ?? d;
double _r4(double v) => double.parse(v.toStringAsFixed(4));

int _seq = 0;
String _newId() => 'e${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_seq++).toRadixString(36)}';

/// The guided layouts of "structured" mode. In free-canvas mode they are only a starting point.
enum Tpl {
  /// Just the text.
  text,

  /// Picture across the top, text under it.
  above,

  /// Text on top, picture under it.
  below,

  /// The picture fills the card, the text sits over it.
  full,

  /// The picture alone, whole and centred (flags, logos).
  only;

  static Tpl parse(Object? v) => Tpl.values.firstWhere((t) => t.name == v, orElse: () => Tpl.text);

  String get label => switch (this) {
        Tpl.text => 'Text',
        Tpl.above => 'Picture on top',
        Tpl.below => 'Picture below',
        Tpl.full => 'Full picture',
        Tpl.only => 'Picture only',
      };
}

enum LayoutMode { structured, canvas }

/// One thing placed on the face.
sealed class LayoutEl {
  LayoutEl({String? id, required this.x, required this.y, required this.w, required this.h}) : id = id ?? _newId();

  final String id;

  /// Frame, as fractions of the face.
  double x, y, w, h;

  Map<String, Object?> toJson();
  LayoutEl copy();

  static LayoutEl? fromJson(Object? j) {
    if (j is! Map) return null;
    return switch (j['k']) {
      'i' => ImageEl.fromJson(j),
      't' => TextEl.fromJson(j),
      _ => null,
    };
  }

  Map<String, Object?> _frame() => {'id': id, 'x': _r4(x), 'y': _r4(y), 'w': _r4(w), 'h': _r4(h)};
}

/// A picture in a frame. It always fills the frame ([contain] false) or sits whole inside it; [zoom] and
/// the pan point then crop it further, like object-fit with a zoom.
class ImageEl extends LayoutEl {
  ImageEl({
    super.id,
    required super.x,
    required super.y,
    required super.w,
    required super.h,
    required this.src,
    this.aspect = 0,
    this.contain = false,
    this.zoom = 1,
    this.panX = 0.5,
    this.panY = 0.5,
    this.radius = 12,
    this.blur = false,
    this.plate = '',
    this.outline = false,
    this.alpha = false,
  });

  /// File path (phone), data URI (web) or `asset:` path (bundled decks).
  String src;

  /// Source width ÷ height; 0 when unknown.
  double aspect;

  /// Whole picture visible (letterboxed) instead of filling the frame.
  bool contain;

  /// 1 = no zoom. The visible window moves with [panX] / [panY] (0…1, 0.5 = centred).
  double zoom;
  double panX, panY;

  /// Corner radius in pixels on a 276-wide face.
  double radius;

  /// Blurred until the card is revealed (strength from Settings).
  bool blur;

  /// A solid plate behind a transparent picture: '' none · 'paper' · 'ink'.
  String plate;

  /// A hairline outline (pale flags on a pale card).
  bool outline;

  /// The picture has transparent areas (informational).
  bool alpha;

  @override
  ImageEl copy() => ImageEl.fromJson(toJson())!;

  @override
  Map<String, Object?> toJson() => {
        'k': 'i',
        ..._frame(),
        's': src,
        if (aspect > 0) 'a': _r4(aspect),
        if (contain) 'c': 1,
        if (zoom != 1) 'z': _r4(zoom),
        if (panX != 0.5) 'px': _r4(panX),
        if (panY != 0.5) 'py': _r4(panY),
        'r': _r4(radius),
        if (blur) 'b': 1,
        if (plate.isNotEmpty) 'p': plate,
        if (outline) 'o': 1,
        if (alpha) 'al': 1,
      };

  static ImageEl? fromJson(Map j) {
    final src = j['s'] as String?;
    if (src == null || src.isEmpty) return null;
    return ImageEl(
      id: j['id'] as String?,
      x: _d(j['x'], 0),
      y: _d(j['y'], 0),
      w: _d(j['w'], 1),
      h: _d(j['h'], 1),
      src: src,
      aspect: _d(j['a'], 0),
      contain: j['c'] == 1,
      zoom: _d(j['z'], 1).clamp(1, 8),
      panX: _d(j['px'], 0.5).clamp(0, 1),
      panY: _d(j['py'], 0.5).clamp(0, 1),
      radius: _d(j['r'], 12),
      blur: j['b'] == 1,
      plate: _s(j['p'], ''),
      outline: j['o'] == 1,
      alpha: j['al'] == 1,
    );
  }
}

/// Text on the face. [source] says where the words come from: the card's own fields stay the single
/// copy (the engine, search and typing use them), or [text] for words that only live in the layout.
class TextEl extends LayoutEl {
  TextEl({
    super.id,
    required super.x,
    required super.y,
    required super.w,
    required super.h,
    this.source = 'main',
    this.text = '',
    this.size = 0,
    this.align = 0,
    this.color = 'auto',
    this.bg = 'none',
    this.font = 'display',
    this.visible = true,
  });

  /// main (this side's text) · example · hook · custom.
  String source;
  String text;

  /// Pixels on a 276-wide face; 0 picks a size from the length of the text.
  double size;

  /// 0 left · 1 centre · 2 right.
  int align;

  /// auto · light · dark · peach · red.
  String color;

  /// A backdrop for reading over pictures: none · dark · light · peach.
  String bg;

  /// display (Bernard) · plain (Barlow).
  String font;
  bool visible;

  bool get isCustom => source == 'custom';

  @override
  TextEl copy() => TextEl.fromJson(toJson())!;

  @override
  Map<String, Object?> toJson() => {
        'k': 't',
        ..._frame(),
        's': source,
        if (text.isNotEmpty) 't': text,
        if (size != 0) 'z': _r4(size),
        if (align != 0) 'al': align,
        if (color != 'auto') 'co': color,
        if (bg != 'none') 'bg': bg,
        if (font != 'display') 'f': font,
        if (!visible) 'v': 0,
      };

  static TextEl? fromJson(Map j) => TextEl(
        id: j['id'] as String?,
        x: _d(j['x'], 0),
        y: _d(j['y'], 0),
        w: _d(j['w'], 1),
        h: _d(j['h'], 0.2),
        source: _s(j['s'], 'main'),
        text: _s(j['t'], ''),
        size: _d(j['z'], 0),
        align: (j['al'] as num?)?.toInt() ?? 0,
        color: _s(j['co'], 'auto'),
        bg: _s(j['bg'], 'none'),
        font: _s(j['f'], 'display'),
        visible: j['v'] != 0,
      );
}

/// One side of a card (front or back).
class SideLayout {
  SideLayout({this.mode = LayoutMode.structured, this.tpl = Tpl.text, List<LayoutEl>? els}) : els = els ?? <LayoutEl>[];

  LayoutMode mode;

  /// The template structured mode keeps applying; in canvas mode, the one "Reset" returns to.
  Tpl tpl;
  final List<LayoutEl> els;

  // The face's geometry the templates are drawn on (design 276 × 384).
  static const padX = 20 / 276;
  static const innerW = 1 - 2 * padX;

  Iterable<ImageEl> get images => els.whereType<ImageEl>();
  Iterable<TextEl> get texts => els.whereType<TextEl>();
  bool get hasImage => images.isNotEmpty;
  ImageEl? get firstImage => images.isEmpty ? null : images.first;

  /// A text-only structured layout with nothing customised: stored as "no layout" so the card keeps the
  /// classic look.
  bool get isPlain => mode == LayoutMode.structured && tpl == Tpl.text && !hasImage;

  /// The picture reaches the top of the face (the label chip then needs a backing).
  bool get imageUnderLabel => images.any((i) => i.y < 0.1);

  SideLayout copy() => SideLayout(mode: mode, tpl: tpl, els: [for (final e in els) e.copy()]);

  /// A copy for the other side of a card: pictures that wait for the reveal ([blur]) or not.
  SideLayout flagged({required bool blur}) {
    final c = copy();
    for (final i in c.images) {
      i.blur = blur;
    }
    return c;
  }

  Map<String, Object?> toJson() => {
        'm': mode == LayoutMode.canvas ? 1 : 0,
        't': tpl.name,
        'e': [for (final e in els) e.toJson()],
      };

  static SideLayout? fromJson(Object? j) {
    if (j is! Map) return null;
    final els = <LayoutEl>[];
    for (final e in (j['e'] as List?) ?? const []) {
      final el = LayoutEl.fromJson(e);
      if (el != null) els.add(el);
    }
    return SideLayout(mode: j['m'] == 1 ? LayoutMode.canvas : LayoutMode.structured, tpl: Tpl.parse(j['t']), els: els);
  }

  // ---------------------------------------------------------------- templates

  /// The layout for [tpl] on the front (or the back) of a card, around [image] (a picture, if any).
  /// Text elements always exist, so empty text can be filled in later; they draw nothing while empty.
  static SideLayout template(
    Tpl tpl, {
    required bool back,
    ImageEl? image,
    List<TextEl>? keepTexts,
    bool textless = false,
  }) {
    const px = padX, w = innerW;
    final pic = image;
    ImageEl? framed(double x, double y, double fw, double fh, {double radius = 12, bool? contain, bool outline = false}) {
      if (pic == null) return null;
      return ImageEl(
        id: pic.id,
        x: x,
        y: y,
        w: fw,
        h: fh,
        src: pic.src,
        aspect: pic.aspect,
        contain: contain ?? pic.contain,
        zoom: pic.zoom,
        panX: pic.panX,
        panY: pic.panY,
        radius: radius,
        blur: pic.blur,
        plate: pic.plate,
        outline: outline || pic.outline,
        alpha: pic.alpha,
      );
    }

    TextEl main(double y, double h, {double size = 0, String color = 'auto', String bg = 'none', bool visible = true}) =>
        TextEl(x: px, y: y, w: w, h: h, source: 'main', size: size, color: color, bg: bg, visible: visible);
    TextEl example(double y, double h, {String color = 'auto', String bg = 'none'}) =>
        TextEl(x: px, y: y, w: w, h: h, source: 'example', size: 16, font: 'plain', color: color, bg: bg);
    TextEl hook(double y, {String color = 'auto', String bg = 'none'}) =>
        TextEl(x: px, y: y, w: w, h: 0.085, source: 'hook', size: 14, font: 'plain', color: color, bg: bg);

    // With no words on the side, the picture takes the room the text would have had.
    ImageEl? tall() {
      if (pic == null) return null;
      const top = 0.115, room = 0.645;
      final a = pic.aspect > 0 ? pic.aspect : 1.0;
      final fh = ((w * 276) / a / 384).clamp(0.42, room).toDouble();
      return framed(px, top + (room - fh) / 2, w, fh);
    }

    final els = <LayoutEl>[];
    switch (tpl) {
      case Tpl.text:
        els.addAll([main(0.105, 0.3), example(0.41, 0.14), if (back) hook(0.58)]);
      case Tpl.below:
        els.addAll([
          main(0.105, 0.17),
          example(0.275, 0.08),
          ?(textless ? tall() : framed(px, 0.365, w, back ? 0.385 : 0.405)),
          if (back) hook(0.765),
        ]);
      case Tpl.above:
        els.addAll([
          ?(textless ? tall() : framed(px, 0.115, w, 0.42)),
          main(0.57, 0.16),
          example(0.735, 0.07),
          if (back) hook(0.8),
        ]);
      case Tpl.full:
        els.addAll([
          ?framed(0, 0, 1, 1, radius: 0),
          main(0.6, 0.17, size: 30, color: 'light', bg: pic == null ? 'none' : 'dark'),
          if (back) hook(0.79, color: 'light', bg: pic == null ? 'none' : 'dark'),
        ]);
      case Tpl.only:
        els.addAll([
          ?framed(px, 0.125, w, 0.62, contain: true, outline: true),
          main(0.76, 0.12, visible: false),
        ]);
    }
    // Keep the look of text the user already styled when only the template changes.
    if (keepTexts != null) {
      for (final t in els.whereType<TextEl>()) {
        final old = keepTexts.where((k) => k.source == t.source && !k.isCustom).firstOrNull;
        if (old != null && tpl != Tpl.full && tpl != Tpl.only) {
          t
            ..size = old.size == 0 ? t.size : old.size
            ..align = old.align
            ..font = old.font;
        }
      }
    }
    return SideLayout(tpl: tpl, els: els);
  }

  /// Applies [t] in structured mode: rebuilds the elements around the current first picture.
  void applyTemplate(Tpl t, {required bool back}) {
    final keep = texts.where((e) => !e.isCustom).toList();
    final next = template(t, back: back, image: firstImage, keepTexts: keep);
    els
      ..clear()
      ..addAll(next.els);
    tpl = t;
  }

  /// Turns a picture and a template into a layout (shop decks, the quick "add picture" path).
  static SideLayout forPicture(
    Tpl tpl, {
    required bool back,
    required String src,
    double aspect = 0,
    bool contain = false,
    bool alpha = false,
    String plate = '',
    bool outline = false,
    bool blur = false,
    double panY = 0.5,
    bool textless = false,
  }) {
    final img = ImageEl(
      x: 0,
      y: 0,
      w: 1,
      h: 1,
      src: src,
      aspect: aspect,
      contain: contain,
      alpha: alpha,
      plate: plate,
      outline: outline,
      blur: blur,
      panY: panY,
    );
    return template(tpl, back: back, image: img, textless: textless);
  }

  /// Moves everything into canvas mode (the elements already hold their positions).
  void toCanvas() => mode = LayoutMode.canvas;

  /// A new picture dropped on the canvas, sized to its shape.
  ImageEl dropImage({required String src, double aspect = 0, bool alpha = false, required double faceAspect}) {
    // Fit a frame of the picture's own shape in 80 % of the face width / 55 % of its height.
    final a = aspect > 0 ? aspect : 1.0;
    var fw = 0.8;
    var fh = fw * faceAspect / a; // fractions of face height: (fw·W / a) / H
    if (fh > 0.55) {
      fh = 0.55;
      fw = math.min(0.9, fh * a / faceAspect);
    }
    final el = ImageEl(
      x: (1 - fw) / 2,
      y: math.max(0.12, (1 - fh) / 2 - 0.05),
      w: fw,
      h: fh,
      src: src,
      aspect: aspect,
      contain: false,
      alpha: alpha,
      radius: 12,
    );
    els.add(el);
    return el;
  }

  /// A new text box in the middle of the face, readable over anything.
  TextEl dropText({String text = 'Your words'}) {
    final el = TextEl(x: 0.1, y: 0.42, w: 0.8, h: 0.14, source: 'custom', text: text, size: 26, color: 'light', bg: 'dark', align: 1);
    els.add(el);
    return el;
  }

  /// Brings [e] to the front (true) or sends it to the back (false).
  void reorder(LayoutEl e, {required bool toFront}) {
    els.remove(e);
    if (toFront) {
      els.add(e);
    } else {
      els.insert(0, e);
    }
  }

  /// Steps [e] one place forward or backward in the stack.
  void step(LayoutEl e, int by) {
    final i = els.indexOf(e);
    if (i < 0) return;
    final j = (i + by).clamp(0, els.length - 1);
    if (i == j) return;
    els
      ..removeAt(i)
      ..insert(j, e);
  }
}
