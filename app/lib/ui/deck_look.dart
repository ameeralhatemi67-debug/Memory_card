import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../features/layout/layout_face.dart' show cardImage;
import 'textures.dart';
import 'theme.dart';

// A deck's own look: the picture behind its bar (a skin) and its square or wide wax seals.

/// A skin picture filling its box: covers it, keeps the skin's focal point in view, zoomed in by its zoom.
class SkinPicture extends StatelessWidget {
  const SkinPicture({super.key, required this.skin});
  final DeckSkin skin;

  @override
  Widget build(BuildContext context) {
    final a = Alignment(skin.x * 2 - 1, skin.y * 2 - 1);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      return ClipRect(
        child: Transform.scale(
          scale: skin.zoom,
          alignment: a,
          child: cardImage(skin.src, width: w, height: h, alignment: a, cacheWidth: (w * dpr * skin.zoom).round().clamp(64, 2400)),
        ),
      );
    });
  }
}

/// The shade under a skin's text: strong on the left where the name sits, light on the right under the fan.
class SkinShade extends StatelessWidget {
  const SkinShade({super.key, required this.skin, this.even = false});
  final DeckSkin skin;

  /// One even shade over the whole picture (small tiles with a centred monogram).
  final bool even;

  @override
  Widget build(BuildContext context) {
    final base = skin.light ? Colors.black : Colors.white;
    final s = skin.shade;
    if (even) return ColoredBox(color: base.withValues(alpha: 0.6 * s));
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            base.withValues(alpha: 0.9 * s),
            base.withValues(alpha: 0.9 * s),
            base.withValues(alpha: 0.25 * s),
            base.withValues(alpha: 0.25 * s),
          ],
          stops: const [0, 0.3, 0.75, 1],
        ),
      ),
    );
  }
}

/// Text colours on a skin: (title, meta).
(Color, Color) skinInk(DeckSkin skin) =>
    skin.light ? (const Color(0xFFF7F7F7), const Color(0xD9F1F1F1)) : (const Color(0xFF1E1E1E), const Color(0xCC1E1E1E));

// ---------------------------------------------------------------- deck seals

/// The wax of a deck seal, by its colour name.
Color sealWax(String color, Mc mc) => switch (color) {
      'wine' => const Color(0xFF8E3B4A),
      'peach' => Mc.peach,
      'gold' => const Color(0xFFE9C46A),
      'green' => Mc.green,
      'teal' => const Color(0xFF6FD0C8),
      'blue' => Mc.blue,
      'violet' => const Color(0xFFB59CFF),
      'ink' => mc.ink,
      _ => Mc.red,
    };

/// What is stamped into that wax: light on the dark waxes, graphite on the light ones.
Color sealStamp(String color, Mc mc) => switch (color) {
      'red' || 'wine' => Mc.paper,
      'ink' => mc.canvas,
      _ => Mc.graphite,
    };

String sealColorName(String color) => switch (color) {
      'wine' => 'Wine',
      'peach' => 'Peach',
      'gold' => 'Gold',
      'green' => 'Green',
      'teal' => 'Teal',
      'blue' => 'Blue',
      'violet' => 'Violet',
      'ink' => 'Ink',
      _ => 'Red',
    };

/// The rim of a square or wide seal: the round seal's zigzag (a point every ~5.7 % of the height, 2.5 %
/// in and out) run around a rounded rectangle.
Path sealRimPath(Size size) {
  final s = size.height;
  final amp = 0.025 * s;
  final inset = 0.065 * s;
  final w = size.width - 2 * inset, h = size.height - 2 * inset;
  final r = 0.17 * s;
  final straightW = w - 2 * r, straightH = h - 2 * r;
  final arc = math.pi / 2 * r;
  final perimeter = 2 * straightW + 2 * straightH + 4 * arc;
  // An even number of points, so the zigzag closes cleanly.
  final n = ((perimeter / (0.057 * s)) / 2).round() * 2;
  final path = Path();

  // Point and outward normal at distance d along the rim, starting at the top-left end of the top edge.
  (Offset, Offset) at(double d) {
    final segs = <double>[straightW, arc, straightH, arc, straightW, arc, straightH, arc];
    var i = 0;
    while (i < segs.length - 1 && d > segs[i]) {
      d -= segs[i];
      i++;
    }
    final l = inset, t = inset;
    switch (i) {
      case 0:
        return (Offset(l + r + d, t), const Offset(0, -1));
      case 2:
        return (Offset(l + w, t + r + d), const Offset(1, 0));
      case 4:
        return (Offset(l + w - r - d, t + h), const Offset(0, 1));
      case 6:
        return (Offset(l, t + h - r - d), const Offset(-1, 0));
    }
    final centers = {1: Offset(l + w - r, t + r), 3: Offset(l + w - r, t + h - r), 5: Offset(l + r, t + h - r), 7: Offset(l + r, t + r)};
    final start = {1: -math.pi / 2, 3: 0.0, 5: math.pi / 2, 7: math.pi}[i]!;
    final a = start + d / r;
    final nrm = Offset(math.cos(a), math.sin(a));
    return (centers[i]! + nrm * r, nrm);
  }

  for (var k = 0; k < n; k++) {
    final (p, nrm) = at(perimeter * k / n);
    final q = p + nrm * (k.isEven ? amp : -amp);
    k == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
  }
  return path..close();
}

class _DeckSealPainter extends CustomPainter {
  _DeckSealPainter(this.wax);
  final Color wax;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height;
    final rim = sealRimPath(size);
    canvas.drawPath(rim.shift(Offset(0, 0.04 * s)), Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.05 * s));
    canvas.drawPath(rim, Paint()..color = wax);
    // Two embossed rings, like the round seal's.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFF1F1F1).withValues(alpha: 0.5)
      ..strokeWidth = 0.016 * s;
    for (final (inset, alpha, width) in [(0.17, 0.5, 0.016), (0.22, 0.35, 0.01)]) {
      final rr = RRect.fromRectAndRadius(
        Rect.fromLTRB(inset * s, inset * s, size.width - inset * s, size.height - inset * s),
        Radius.circular((0.2 - inset * 0.55) * s),
      );
      canvas.drawRRect(rr, ring
        ..color = const Color(0xFFF1F1F1).withValues(alpha: alpha)
        ..strokeWidth = width * s);
    }
  }

  @override
  bool shouldRepaint(_DeckSealPainter old) => old.wax != wax;
}

/// A deck seal: square ([size] × [size]) or wide (1.5 × [size] across), with its text and picture.
/// Seals not pressed yet ([earned] false) are blank wax.
class DeckSealBadge extends StatelessWidget {
  const DeckSealBadge({super.key, required this.seal, required this.size, this.earned = true});
  final DeckSeal seal;
  final double size;
  final bool earned;

  static double widthOf(DeckSeal seal, double size) => seal.wide ? size * 1.5 : size;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final wax = earned ? sealWax(seal.color, mc) : mc.soft;
    final ink = earned ? sealStamp(seal.color, mc) : mc.muted;
    final w = widthOf(seal, size);
    final text = seal.text.trim();
    final pad = size * 0.25;

    Widget? picture;
    if (seal.hasImage) {
      final img = cardImage(seal.image!, fit: BoxFit.contain, cacheWidth: (size * 3).round());
      picture = seal.art == 'color' && earned
          ? img
          : Stack(fit: StackFit.passthrough, children: [
              // Pressed in: a soft dark copy just below, then the picture in the stamp's colour.
              Transform.translate(
                offset: Offset(0, size * 0.012),
                child: ColorFiltered(colorFilter: const ColorFilter.mode(Color(0x47000000), BlendMode.srcIn), child: img),
              ),
              ColorFiltered(colorFilter: ColorFilter.mode(ink.withValues(alpha: 0.94), BlendMode.srcIn), child: img),
            ]);
    }
    final label = text.isEmpty
        ? null
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text, maxLines: 1, style: T.d(size * 0.3, color: ink, spacing: 0.5)),
          );

    Widget content;
    if (picture != null && label != null) {
      content = seal.wide
          ? Row(children: [
              Expanded(flex: 5, child: picture),
              SizedBox(width: size * 0.06),
              Expanded(flex: 6, child: Center(child: label)),
            ])
          : Column(children: [
              Expanded(flex: 7, child: picture),
              SizedBox(height: size * 0.02),
              Expanded(flex: 4, child: Center(child: label)),
            ]);
    } else {
      content = Center(child: picture ?? label ?? const SizedBox.shrink());
    }

    return SizedBox(
      width: w,
      height: size,
      child: Stack(fit: StackFit.expand, children: [
        // Mottled wax inside the rim, under what is stamped.
        CustomPaint(painter: _DeckSealPainter(wax), foregroundPainter: texPainter(context, 'seals', sealRimPath)),
        Padding(padding: EdgeInsets.all(pad), child: content),
      ]),
    );
  }
}
